/**
 * لایهٔ ذخیره‌سازی محلی — پشتوانهٔ تعهد «کار بدون اینترنت».
 *
 * چرا IndexedDB؟ localStorage سقف حدوداً ۵ مگابایتی دارد و همزمان
 * (synchronous) است؛ یک مغازه با چند هزار فاکتور به‌راحتی از آن عبور
 * می‌کند و رابط کاربری هنگام ذخیره کند می‌شود.
 *
 * زنجیرهٔ پشتیبان: IndexedDB → localStorage → حافظهٔ موقت.
 * برنامه هرگز نباید به‌خاطر ذخیره‌سازی از کار بیفتد.
 */

const DB_NAME = 'javid';
const DB_VERSION = 1;
const STORE = 'kv';

export type StorageKind = 'indexeddb' | 'localstorage' | 'memory';

const memory = new Map<string, string>();
let kind: StorageKind = 'memory';
let idb: IDBDatabase | null = null;

export function storageKind(): StorageKind {
  return kind;
}

export const STORAGE_LABELS: Record<StorageKind, string> = {
  indexeddb: 'پایگاه دادهٔ مرورگر',
  localstorage: 'حافظهٔ محلی مرورگر',
  memory: 'حافظهٔ موقت (ذخیره نمی‌شود)',
};

function hasIndexedDB(): boolean {
  try {
    return typeof indexedDB !== 'undefined' && indexedDB !== null;
  } catch {
    return false;
  }
}

function hasLocalStorage(): boolean {
  try {
    if (typeof localStorage === 'undefined') return false;
    const probe = '__javid_probe__';
    localStorage.setItem(probe, '1');
    localStorage.removeItem(probe);
    return true;
  } catch {
    return false;
  }
}

function openIDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) db.createObjectStore(STORE);
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error ?? new Error('باز کردن پایگاه داده ناموفق بود'));
    req.onblocked = () => reject(new Error('پایگاه داده توسط زبانهٔ دیگری قفل شده است'));
  });
}

/** آماده‌سازی — یک بار در شروع برنامه صدا زده می‌شود */
export async function initStorage(): Promise<StorageKind> {
  if (hasIndexedDB()) {
    try {
      idb = await openIDB();
      kind = 'indexeddb';
      return kind;
    } catch {
      idb = null;
    }
  }
  kind = hasLocalStorage() ? 'localstorage' : 'memory';
  return kind;
}

function idbGet(key: string): Promise<string | null> {
  return new Promise((resolve, reject) => {
    if (!idb) return resolve(null);
    const tx = idb.transaction(STORE, 'readonly');
    const req = tx.objectStore(STORE).get(key);
    req.onsuccess = () => resolve((req.result as string | undefined) ?? null);
    req.onerror = () => reject(req.error);
  });
}

function idbSet(key: string, value: string): Promise<void> {
  return new Promise((resolve, reject) => {
    if (!idb) return resolve();
    const tx = idb.transaction(STORE, 'readwrite');
    tx.objectStore(STORE).put(value, key);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error ?? new Error('نوشتن لغو شد'));
  });
}

function idbDelete(key: string): Promise<void> {
  return new Promise((resolve, reject) => {
    if (!idb) return resolve();
    const tx = idb.transaction(STORE, 'readwrite');
    tx.objectStore(STORE).delete(key);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

export async function getItem(key: string): Promise<string | null> {
  if (kind === 'indexeddb') {
    try {
      const v = await idbGet(key);
      if (v !== null) return v;
    } catch { /* به لایهٔ بعد سقوط می‌کنیم */ }
  }
  if (kind !== 'memory' && hasLocalStorage()) {
    try {
      const v = localStorage.getItem(key);
      if (v !== null) return v;
    } catch { /* نادیده */ }
  }
  return memory.get(key) ?? null;
}

export async function setItem(key: string, value: string): Promise<void> {
  memory.set(key, value);

  if (kind === 'indexeddb') {
    try {
      await idbSet(key, value);
      return;
    } catch { /* به localStorage سقوط می‌کنیم */ }
  }
  try {
    if (hasLocalStorage()) localStorage.setItem(key, value);
  } catch {
    // سهمیه پر است — دست‌کم در حافظه نگه داشته شد
  }
}

export async function removeItem(key: string): Promise<void> {
  memory.delete(key);
  if (kind === 'indexeddb') {
    try { await idbDelete(key); } catch { /* نادیده */ }
  }
  try {
    if (hasLocalStorage()) localStorage.removeItem(key);
  } catch { /* نادیده */ }
}

/** خواندن همزمان — فقط برای مقادیر کوچک مثل شناسهٔ دستگاه */
export function getItemSync(key: string): string | null {
  const m = memory.get(key);
  if (m !== undefined) return m;
  try {
    if (typeof localStorage !== 'undefined') return localStorage.getItem(key);
  } catch { /* نادیده */ }
  return null;
}

export function setItemSync(key: string, value: string): void {
  memory.set(key, value);
  try {
    if (typeof localStorage !== 'undefined') localStorage.setItem(key, value);
  } catch { /* نادیده */ }
  if (kind === 'indexeddb') void idbSet(key, value).catch(() => {});
}

/** برآورد فضای مصرفی و در دسترس */
export async function storageEstimate(): Promise<{ usage: number; quota: number } | null> {
  try {
    const nav = navigator as Navigator & { storage?: { estimate?: () => Promise<StorageEstimate> } };
    if (!nav.storage?.estimate) return null;
    const e = await nav.storage.estimate();
    return { usage: e.usage ?? 0, quota: e.quota ?? 0 };
  } catch {
    return null;
  }
}
