import {
  DEFAULT_PULL_LIMIT, MAX_PULL_LIMIT,
  type ChangeResult, type PullResult, type PushChange,
  type PushResult, type ServerChange,
} from '@javid/core';
import { latestSeq, serverLamport, type DB } from './db.js';

/**
 * موتور همگام‌سازی سرور.
 *
 * سه تضمین:
 *  ۱. **Idempotent** — ارسال مجدد همان تغییر رکورد تکراری نمی‌سازد.
 *     قطعی وسط ارسال یعنی کلاینت دوباره می‌فرستد و باید بی‌خطر باشد.
 *  ۲. **حل تعارض قطعی‌گرا** — همان قاعدهٔ کلاینت: ساعت لامپورت، سپس
 *     زمان، سپس شناسهٔ دستگاه. نتیجه روی سرور و همهٔ دستگاه‌ها یکسان.
 *  ۳. **اتمی** — یک بستهٔ تغییرات یا کامل اعمال می‌شود یا هیچ.
 */

const iso = () => new Date().toISOString();

interface StateRow {
  lamport: number;
  device_id: string;
  at: string;
}

/**
 * آیا تغییر ورودی باید جایگزین حالت فعلی شود؟
 * دقیقاً همان منطق `resolveConflict` در هسته — عمداً تکرار شده
 * تا سرور به منطق سمت کلاینت وابسته نباشد ولی نتیجه یکسان بماند.
 */
export function shouldApply(incoming: PushChange, current: StateRow | undefined): boolean {
  if (!current) return true;
  if (incoming.lamport !== current.lamport) return incoming.lamport > current.lamport;
  if (incoming.at !== current.at) return incoming.at > current.at;
  return incoming.deviceId >= current.device_id;
}

export function push(
  db: DB,
  businessId: string,
  userId: string,
  changes: PushChange[],
): PushResult {
  const results: ChangeResult[] = [];

  const findDupe = db.prepare('SELECT seq FROM changes WHERE business_id = ? AND id = ?');
  const findState = db.prepare(
    'SELECT lamport, device_id, at FROM entity_state WHERE business_id = ? AND entity = ? AND entity_id = ?',
  );
  const insertChange = db.prepare(`
    INSERT INTO changes
      (id, business_id, entity, entity_id, op, payload, lamport, device_id, user_id, at, received_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const upsertState = db.prepare(`
    INSERT INTO entity_state (business_id, entity, entity_id, lamport, device_id, at, seq)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(business_id, entity, entity_id) DO UPDATE SET
      lamport = excluded.lamport,
      device_id = excluded.device_id,
      at = excluded.at,
      seq = excluded.seq
  `);

  /**
   * تراکنش صریح — node:sqlite کمکِ transaction() ندارد.
   * بستهٔ تغییرات باید اتمی باشد: یا همه ثبت شوند یا هیچ‌کدام،
   * وگرنه قطعی وسط کار دفتر را نیمه‌کاره می‌گذارد.
   */
  db.exec('BEGIN IMMEDIATE');
  try {
    for (const c of changes) {
      // ۱ — تکراری؟ همان پاسخ موفق را می‌دهیم تا کلاینت گیر نکند
      if (findDupe.get(businessId, c.id)) {
        results.push({ id: c.id, outcome: 'duplicate' });
        continue;
      }

      // ۲ — دفتر همیشه ثبت می‌شود، حتی اگر تغییر بازنده باشد (ردّ ممیزی)
      const info = insertChange.run(
        c.id, businessId, c.entity, c.entityId, c.op,
        c.op === 'delete' ? null : JSON.stringify(c.payload),
        c.lamport, c.deviceId, userId, c.at, iso(),
      );

      // ۳ — آیا حالت جاری را جابه‌جا می‌کند؟
      const current = findState.get(businessId, c.entity, c.entityId) as unknown as StateRow | undefined;
      if (shouldApply(c, current)) {
        upsertState.run(
          businessId, c.entity, c.entityId,
          c.lamport, c.deviceId, c.at, info.lastInsertRowid as number,
        );
        results.push({ id: c.id, outcome: 'applied' });
      } else {
        results.push({
          id: c.id,
          outcome: 'superseded',
          reason: 'نسخهٔ جدیدتری از این رکورد روی سرور موجود است',
        });
      }
    }
    db.exec('COMMIT');
  } catch (e) {
    db.exec('ROLLBACK');
    throw e;
  }

  return {
    accepted: results,
    serverLamport: serverLamport(db, businessId),
    cursor: latestSeq(db, businessId),
  };
}

export function pull(
  db: DB,
  businessId: string,
  since: number,
  deviceId: string,
  limit = DEFAULT_PULL_LIMIT,
): PullResult {
  const capped = Math.min(Math.max(1, limit), MAX_PULL_LIMIT);

  /**
   * تغییرات دستگاه خودش برگردانده نمی‌شود — او از قبل دارد.
   * این هم پهنای باند را کم می‌کند و هم از حلقهٔ بی‌پایان جلوگیری می‌کند.
   */
  const rows = db.prepare(`
    SELECT seq, id, entity, entity_id, op, payload, lamport, device_id, at
    FROM changes
    WHERE business_id = ? AND seq > ? AND device_id != ?
    ORDER BY seq
    LIMIT ?
  `).all(businessId, since, deviceId, capped + 1) as {
    seq: number; id: string; entity: string; entity_id: string;
    op: string; payload: string | null; lamport: number; device_id: string; at: string;
  }[] as unknown as {
    seq: number; id: string; entity: string; entity_id: string;
    op: string; payload: string | null; lamport: number; device_id: string; at: string;
  }[];

  const hasMore = rows.length > capped;
  const page = hasMore ? rows.slice(0, capped) : rows;

  const changes: ServerChange[] = page.map((r) => ({
    seq: r.seq,
    id: r.id,
    entity: r.entity as ServerChange['entity'],
    entityId: r.entity_id,
    op: r.op as 'put' | 'delete',
    payload: r.payload ? (JSON.parse(r.payload) as unknown) : null,
    lamport: r.lamport,
    deviceId: r.device_id,
    at: r.at,
  }));

  const cursor = page.length > 0 ? page[page.length - 1]!.seq : since;

  db.prepare(`
    INSERT INTO device_cursors (business_id, device_id, cursor, updated_at)
    VALUES (?, ?, ?, ?)
    ON CONFLICT(business_id, device_id) DO UPDATE SET
      cursor = excluded.cursor, updated_at = excluded.updated_at
  `).run(businessId, deviceId, cursor, iso());

  return { changes, cursor, hasMore, serverLamport: serverLamport(db, businessId) };
}

/**
 * وضعیت فعلی هر موجودیت — برای دستگاه تازه‌واردی که می‌خواهد
 * بدون بازپخش کل تاریخچه سریع بالا بیاید.
 */
export function snapshot(db: DB, businessId: string): {
  entities: Record<string, unknown[]>;
  cursor: number;
} {
  const rows = db.prepare(`
    SELECT c.entity, c.op, c.payload
    FROM entity_state s
    JOIN changes c ON c.seq = s.seq
    WHERE s.business_id = ?
    ORDER BY c.entity, c.seq
  `).all(businessId) as unknown as { entity: string; op: string; payload: string | null }[];

  const entities: Record<string, unknown[]> = {};
  for (const r of rows) {
    if (r.op === 'delete' || !r.payload) continue;
    (entities[r.entity] ??= []).push(JSON.parse(r.payload));
  }

  return { entities, cursor: latestSeq(db, businessId) };
}

export function deviceCursor(db: DB, businessId: string, deviceId: string): number {
  const row = db
    .prepare('SELECT cursor FROM device_cursors WHERE business_id = ? AND device_id = ?')
    .get(businessId, deviceId) as unknown as { cursor: number } | undefined;
  return row?.cursor ?? 0;
}
