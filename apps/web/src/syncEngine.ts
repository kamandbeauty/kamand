import {
  resolveConflict, type Change, type ServerChange,
} from '@javid/core';
import * as api from './api';
import { clock, deviceId, queue, type DB } from './store';

/**
 * موتور همگام‌سازی سمت کلاینت.
 *
 * چرخهٔ کار:
 *   ۱. ارسال تغییرات محلی معلق
 *   ۲. دریافت تغییرات دیگر دستگاه‌ها
 *   ۳. ادغام با حل تعارض
 *
 * اصل حاکم: **هرگز نوشتن محلی را مسدود نکن.** اگر همگام‌سازی شکست
 * خورد، کاربر متوجه می‌شود ولی کارش متوقف نمی‌شود.
 */

export interface SyncOutcome {
  ok: boolean;
  pushed: number;
  pulled: number;
  conflicts: number;
  error?: string;
}

/** موجودیت‌های همگام‌شونده و نگاشتشان به کلیدهای پایگاه دادهٔ محلی */
const ENTITY_TO_KEY: Record<string, keyof DB> = {
  party: 'parties',
  product: 'products',
  invoice: 'invoices',
  transaction: 'transactions',
  cheque: 'cheques',
  treasury: 'treasuries',
  entry: 'entries',
  movement: 'movements',
  account: 'accounts',
  tax_submission: 'taxSubmissions',
};

interface Identified {
  id: string;
  updatedAt?: string;
  lamport?: number;
  deviceId?: string;
  deletedAt?: string | null;
}

/**
 * ادغام یک تغییر سرور در پایگاه دادهٔ محلی.
 * از همان `resolveConflict` هسته استفاده می‌کند تا نتیجه با سرور یکی باشد.
 */
export function mergeChange(db: DB, change: ServerChange): { db: DB; conflicted: boolean } {
  const key = ENTITY_TO_KEY[change.entity];
  if (!key) return { db, conflicted: false };

  const list = (db[key] as unknown as Identified[]) ?? [];
  const idx = list.findIndex((x) => x.id === change.entityId);

  if (change.op === 'delete') {
    if (idx === -1) return { db, conflicted: false };
    const next = [...list];
    next[idx] = { ...next[idx]!, deletedAt: change.at };
    return { db: { ...db, [key]: next } as DB, conflicted: false };
  }

  const incoming = {
    ...(change.payload as Identified),
    id: change.entityId,
    lamport: change.lamport,
    deviceId: change.deviceId,
    updatedAt: change.at,
  };

  if (idx === -1) {
    return { db: { ...db, [key]: [...list, incoming] } as DB, conflicted: false };
  }

  const local = list[idx]!;
  const winner = resolveConflict(local, incoming);
  const conflicted = winner.resolution === 'local';

  if (conflicted) return { db, conflicted: true };

  const next = [...list];
  next[idx] = winner.winner as Identified;
  return { db: { ...db, [key]: next } as DB, conflicted: false };
}

/** یک چرخهٔ کامل همگام‌سازی */
export async function runSync(
  db: DB,
  applyDB: (next: DB) => void,
): Promise<SyncOutcome> {
  if (!api.isSignedIn()) {
    return { ok: false, pushed: 0, pulled: 0, conflicts: 0, error: 'وارد حساب کاربری نشده‌اید' };
  }

  const businessId = api.remoteBusinessId();
  if (!businessId) {
    return { ok: false, pushed: 0, pulled: 0, conflicts: 0, error: 'کسب‌وکار همگام‌سازی انتخاب نشده است' };
  }

  const dev = deviceId();
  let pushed = 0;
  let pulled = 0;
  let conflicts = 0;

  try {
    // ─── ۱. ارسال ───
    queue.compact();
    const pending = queue.pending();

    if (pending.length > 0) {
      // در دسته‌های کوچک تا درخواست‌های سنگین نسازیم
      const BATCH = 200;
      for (let i = 0; i < pending.length; i += BATCH) {
        const batch = pending.slice(i, i + BATCH);
        const res = await api.pushChanges(businessId, dev, batch as Change[]);

        // فقط تغییراتی که سرور تأیید کرد را همگام‌شده علامت می‌زنیم
        const done = res.accepted
          .filter((a) => a.outcome !== 'rejected')
          .map((a) => a.id);
        queue.markSynced(done);
        pushed += done.length;

        clock.observe(res.serverLamport);
      }
    }

    // ─── ۲. دریافت ───
    let cursor = api.syncCursor();
    let working = db;
    let more = true;

    while (more) {
      const res = await api.pullChanges(businessId, dev, cursor);
      for (const change of res.changes) {
        clock.observe(change.lamport);
        const merged = mergeChange(working, change);
        working = merged.db;
        if (merged.conflicted) conflicts++;
        else pulled++;
      }
      cursor = res.cursor;
      more = res.hasMore;
      clock.observe(res.serverLamport);
    }

    api.setSyncCursor(cursor);
    if (pulled > 0) applyDB(working);

    return { ok: true, pushed, pulled, conflicts };
  } catch (e) {
    const err = e as api.ApiError;
    return {
      ok: false,
      pushed,
      pulled,
      conflicts,
      error: err.message ?? 'همگام‌سازی ناموفق بود',
    };
  }
}

/**
 * بارگذاری اولیه از سرور برای دستگاه تازه.
 * به‌جای بازپخش کل تاریخچه، تصویر لحظه‌ای گرفته می‌شود.
 */
export async function bootstrapFromServer(db: DB): Promise<{ db: DB; count: number }> {
  const businessId = api.remoteBusinessId();
  if (!businessId) throw new Error('کسب‌وکار همگام‌سازی انتخاب نشده است');

  const snap = await api.fetchSnapshot(businessId);
  let working = { ...db };
  let count = 0;

  for (const [entity, items] of Object.entries(snap.entities)) {
    const key = ENTITY_TO_KEY[entity];
    if (!key || !Array.isArray(items)) continue;
    (working as Record<string, unknown>)[key] = items;
    count += items.length;
  }

  api.setSyncCursor(snap.cursor);
  return { db: working, count };
}

// ─────────── همگام‌سازی خودکار ───────────

let timer: ReturnType<typeof setInterval> | null = null;

export interface AutoSyncOptions {
  intervalMs?: number;
  getDB: () => DB | null;
  applyDB: (db: DB) => void;
  onResult?: (r: SyncOutcome) => void;
}

/**
 * همگام‌سازی دوره‌ای و هنگام بازگشت اینترنت.
 * عمداً محافظه‌کار است: اگر یک چرخه در جریان باشد، چرخهٔ بعدی رد می‌شود.
 */
export function startAutoSync(opts: AutoSyncOptions): () => void {
  const interval = opts.intervalMs ?? 30_000;
  let running = false;

  const cycle = async () => {
    if (running || !navigator.onLine || !api.isSignedIn()) return;
    const db = opts.getDB();
    if (!db) return;

    running = true;
    try {
      const r = await runSync(db, opts.applyDB);
      opts.onResult?.(r);
    } finally {
      running = false;
    }
  };

  timer = setInterval(() => { void cycle(); }, interval);
  const onOnline = () => { void cycle(); };
  window.addEventListener('online', onOnline);

  // یک چرخهٔ اولیه پس از بالا آمدن
  setTimeout(() => { void cycle(); }, 2000);

  return () => {
    if (timer) clearInterval(timer);
    timer = null;
    window.removeEventListener('online', onOnline);
  };
}
