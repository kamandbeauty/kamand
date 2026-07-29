import type { ID } from './types.js';

/**
 * ═══════════════════════════════════════════════════════════════
 *  تعهد شمارهٔ ۲ جاوید: برنامه بدون اینترنت کار می‌کند.
 * ═══════════════════════════════════════════════════════════════
 *
 * مغازه‌دار وسط فروش نباید با قطعی اینترنت متوقف شود.
 * همهٔ نوشتن‌ها اول روی دیتابیس محلی می‌نشیند و سپس در صف
 * همگام‌سازی قرار می‌گیرد.
 *
 * شناسه‌ها UUID سمت کلاینت هستند تا رکورد بدون تماس با سرور
 * قابل ساخت باشد و تداخل شماره‌ای پیش نیاید.
 */

export type SyncOp = 'put' | 'delete';

export interface Change<T = unknown> {
  id: ID;
  entity: string;
  entityId: ID;
  op: SyncOp;
  payload: T;
  /** ساعت منطقی برای ترتیب‌دهی مستقل از ساعت دستگاه */
  lamport: number;
  deviceId: string;
  at: string;
  synced: boolean;
}

/** ساعت لامپورت: ترتیب علّی رویدادها بدون اتکا به ساعت سیستم */
export class LamportClock {
  private value: number;

  constructor(initial = 0) {
    this.value = initial;
  }

  tick(): number {
    return ++this.value;
  }

  observe(remote: number): void {
    this.value = Math.max(this.value, remote);
  }

  get current(): number {
    return this.value;
  }
}

/** UUID v4 با ترجیح بر رمزنگاری امن */
export function uuid(): ID {
  const g = globalThis as { crypto?: { randomUUID?: () => string; getRandomValues?: (a: Uint8Array) => Uint8Array } };
  if (g.crypto?.randomUUID) return g.crypto.randomUUID();
  if (g.crypto?.getRandomValues) {
    const b = g.crypto.getRandomValues(new Uint8Array(16));
    b[6] = ((b[6] ?? 0) & 0x0f) | 0x40;
    b[8] = ((b[8] ?? 0) & 0x3f) | 0x80;
    const hex = [...b].map((x) => x.toString(16).padStart(2, '0')).join('');
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}

export interface VersionedRecord {
  id: ID;
  lamport?: number;
  deviceId?: string;
  updatedAt?: string;
  deletedAt?: string | null;
}

export type ConflictResolution = 'local' | 'remote' | 'merged';

export interface ConflictResult<T> {
  winner: T;
  resolution: ConflictResolution;
  reason: string;
}

/**
 * حل تعارض: ابتدا ساعت لامپورت، سپس زمان، و در نهایت شناسهٔ دستگاه
 * به عنوان داور قطعی تا نتیجه روی همهٔ دستگاه‌ها یکسان باشد.
 */
export function resolveConflict<T extends VersionedRecord>(local: T, remote: T): ConflictResult<T> {
  const ll = local.lamport ?? 0;
  const rl = remote.lamport ?? 0;

  if (ll !== rl) {
    return ll > rl
      ? { winner: local, resolution: 'local', reason: 'ساعت منطقی محلی جلوتر است' }
      : { winner: remote, resolution: 'remote', reason: 'ساعت منطقی سرور جلوتر است' };
  }

  const lt = local.updatedAt ?? '';
  const rt = remote.updatedAt ?? '';
  if (lt !== rt) {
    return lt > rt
      ? { winner: local, resolution: 'local', reason: 'تغییر محلی جدیدتر است' }
      : { winner: remote, resolution: 'remote', reason: 'تغییر سرور جدیدتر است' };
  }

  // داور قطعی و قطعی‌گرا
  const ld = local.deviceId ?? '';
  const rd = remote.deviceId ?? '';
  return ld >= rd
    ? { winner: local, resolution: 'local', reason: 'داوری بر اساس شناسهٔ دستگاه' }
    : { winner: remote, resolution: 'remote', reason: 'داوری بر اساس شناسهٔ دستگاه' };
}

export interface SyncQueue {
  pending(): Change[];
  enqueue(change: Omit<Change, 'id' | 'synced'>): Change;
  markSynced(ids: ID[]): void;
  size(): number;
}

/** صف همگام‌سازی در حافظه — پیاده‌سازی پایه، قابل جایگزینی با IndexedDB/SQLite */
export class MemorySyncQueue implements SyncQueue {
  private items: Change[] = [];

  pending(): Change[] {
    return this.items.filter((c) => !c.synced).sort((a, b) => a.lamport - b.lamport);
  }

  enqueue(change: Omit<Change, 'id' | 'synced'>): Change {
    const full: Change = { ...change, id: uuid(), synced: false };
    this.items.push(full);
    return full;
  }

  markSynced(ids: ID[]): void {
    const set = new Set(ids);
    for (const c of this.items) if (set.has(c.id)) c.synced = true;
  }

  size(): number {
    return this.pending().length;
  }

  /** فشرده‌سازی: چند تغییر روی یک رکورد به آخرین حالت تقلیل می‌یابد */
  compact(): void {
    const latest = new Map<string, Change>();
    for (const c of this.items) {
      if (c.synced) continue;
      const key = `${c.entity}:${c.entityId}`;
      const prev = latest.get(key);
      if (!prev || c.lamport >= prev.lamport) latest.set(key, c);
    }
    this.items = [...this.items.filter((c) => c.synced), ...latest.values()];
  }
}

export type SyncState = 'offline' | 'pending' | 'syncing' | 'synced' | 'error';

export interface SyncStatus {
  state: SyncState;
  pendingCount: number;
  lastSyncedAt?: string;
  message: string;
}

/** وضعیت همگام‌سازی برای نمایش در نوار وضعیت */
export function syncStatus(
  online: boolean,
  queue: SyncQueue,
  lastSyncedAt?: string,
  error?: string,
): SyncStatus {
  const pendingCount = queue.size();
  if (error) return { state: 'error', pendingCount, lastSyncedAt, message: `خطا در همگام‌سازی: ${error}` };
  if (!online) {
    return {
      state: 'offline',
      pendingCount,
      lastSyncedAt,
      message: pendingCount
        ? `آفلاین — ${pendingCount} تغییر در انتظار ارسال`
        : 'آفلاین — همه چیز ذخیره شده است',
    };
  }
  if (pendingCount > 0) {
    return { state: 'pending', pendingCount, lastSyncedAt, message: `${pendingCount} تغییر در انتظار همگام‌سازی` };
  }
  return { state: 'synced', pendingCount: 0, lastSyncedAt, message: 'همگام‌سازی شده' };
}
