import { validateBusinessName, type ID } from '@javid/core';
import * as storage from './storage';
import { createEmptyDB, migrate, type DB } from './store';

/**
 * ═══════════════════════════════════════════════════════════════
 *  چند کسب‌وکاره
 * ═══════════════════════════════════════════════════════════════
 *
 * یکی از سه ویژگی برجستهٔ رقیب که در تحلیل بازار وعده دادیم:
 * «ایجاد و مدیریت چندین کسب‌وکار به صورت کاملاً مجزا».
 *
 * طراحی: هر کسب‌وکار یک پایگاه دادهٔ **کاملاً جدا** دارد. این ساده‌ترین
 * راه برای تضمین نبود نشتی است — به‌جای فیلتر کردن در هر کوئری، اصلاً
 * دادهٔ دیگری در حافظه نیست.
 */

const INDEX_KEY = 'javid:workspaces';
const ACTIVE_KEY = 'javid:activeWorkspace';
const LEGACY_KEY = 'javid:db:v1';

const dbKey = (id: ID) => `javid:db:${id}`;

export interface WorkspaceEntry {
  id: ID;
  name: string;
  createdAt: string;
  lastOpenedAt?: string;
}

// ─────────────────── فهرست ───────────────────

export async function listWorkspaces(): Promise<WorkspaceEntry[]> {
  try {
    const raw = await storage.getItem(INDEX_KEY);
    const list = raw ? (JSON.parse(raw) as WorkspaceEntry[]) : [];
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

async function saveIndex(list: WorkspaceEntry[]): Promise<void> {
  await storage.setItem(INDEX_KEY, JSON.stringify(list));
}

export function activeWorkspaceId(): ID | null {
  return storage.getItemSync(ACTIVE_KEY);
}

export function setActiveWorkspaceId(id: ID): void {
  storage.setItemSync(ACTIVE_KEY, id);
}

// ─────────────────── مهاجرت ───────────────────

/**
 * مهاجرت از ساختار تک‌کسب‌وکاره.
 *
 * کاربری که از نسخهٔ قبلی می‌آید نباید داده‌اش را از دست بدهد یا
 * کاری انجام دهد. این همان درسی است که از شکست مهاجرت رقیب گرفتیم:
 * مهاجرت باید خودکار و بی‌صدا باشد.
 */
export async function migrateLegacyWorkspace(): Promise<WorkspaceEntry | null> {
  const existing = await listWorkspaces();
  if (existing.length > 0) return null;

  const legacy = await storage.getItem(LEGACY_KEY);
  if (!legacy) return null;

  try {
    const db = migrate(JSON.parse(legacy) as DB);
    const entry: WorkspaceEntry = {
      id: db.business.id,
      name: db.business.name,
      createdAt: db.business.createdAt,
      lastOpenedAt: new Date().toISOString(),
    };

    await storage.setItem(dbKey(entry.id), JSON.stringify(db));
    await saveIndex([entry]);
    setActiveWorkspaceId(entry.id);

    // کلید قدیمی عمداً پاک نمی‌شود: اگر مهاجرت مشکلی داشت،
    // دادهٔ اصلی هنوز سر جایش است.
    return entry;
  } catch {
    return null;
  }
}

// ─────────────────── عملیات ───────────────────

export async function loadWorkspace(id: ID): Promise<DB | null> {
  try {
    const raw = await storage.getItem(dbKey(id));
    return raw ? migrate(JSON.parse(raw) as DB) : null;
  } catch {
    return null;
  }
}

export async function saveWorkspace(db: DB): Promise<void> {
  await storage.setItem(dbKey(db.business.id), JSON.stringify(db));
}

export async function createWorkspace(name: string): Promise<{ entry: WorkspaceEntry; db: DB }> {
  const list = await listWorkspaces();
  const issues = validateBusinessName(name, list.map((w) => w.name));
  if (issues.length > 0) throw new Error(issues.join('؛ '));

  const db = createEmptyDB(name.trim());
  const entry: WorkspaceEntry = {
    id: db.business.id,
    name: db.business.name,
    createdAt: db.business.createdAt,
    lastOpenedAt: new Date().toISOString(),
  };

  await storage.setItem(dbKey(entry.id), JSON.stringify(db));
  await saveIndex([...list, entry]);
  return { entry, db };
}

export async function switchWorkspace(id: ID): Promise<DB | null> {
  const db = await loadWorkspace(id);
  if (!db) return null;

  setActiveWorkspaceId(id);
  const list = await listWorkspaces();
  await saveIndex(
    list.map((w) => (w.id === id ? { ...w, lastOpenedAt: new Date().toISOString() } : w)),
  );
  return db;
}

export async function renameWorkspace(id: ID, name: string): Promise<void> {
  const list = await listWorkspaces();
  const issues = validateBusinessName(name, list.filter((w) => w.id !== id).map((w) => w.name));
  if (issues.length > 0) throw new Error(issues.join('؛ '));

  await saveIndex(list.map((w) => (w.id === id ? { ...w, name: name.trim() } : w)));

  const db = await loadWorkspace(id);
  if (db) {
    await saveWorkspace({ ...db, business: { ...db.business, name: name.trim() } });
  }
}

/**
 * حذف کسب‌وکار.
 *
 * آخرین کسب‌وکار حذف نمی‌شود چون کاربر بدون فضای کاری می‌ماند.
 * پیش از حذف، پشتیبان برگردانده می‌شود — ادامهٔ تعهد اول:
 * دادهٔ کاربر بدون راه بازگشت از بین نمی‌رود.
 */
export async function deleteWorkspace(id: ID): Promise<{ backup: string }> {
  const list = await listWorkspaces();
  if (list.length <= 1) throw new Error('آخرین کسب‌وکار قابل حذف نیست');

  const raw = (await storage.getItem(dbKey(id))) ?? '{}';
  await storage.removeItem(dbKey(id));

  const remaining = list.filter((w) => w.id !== id);
  await saveIndex(remaining);

  if (activeWorkspaceId() === id && remaining[0]) {
    setActiveWorkspaceId(remaining[0].id);
  }
  return { backup: raw };
}

/**
 * باز کردن فضای کاری فعال هنگام شروع برنامه.
 * اگر هیچ فضایی نبود، یکی می‌سازد تا کاربر مستقیماً وارد کار شود.
 */
export async function openActiveWorkspace(): Promise<{ db: DB; entry: WorkspaceEntry }> {
  await migrateLegacyWorkspace();

  let list = await listWorkspaces();

  if (list.length === 0) {
    const created = await createWorkspace('کسب‌وکار من');
    setActiveWorkspaceId(created.entry.id);
    return { db: created.db, entry: created.entry };
  }

  const wanted = activeWorkspaceId();
  const entry = list.find((w) => w.id === wanted) ?? list[0]!;

  let db = await loadWorkspace(entry.id);

  // فهرست می‌گوید هست ولی داده نیست — فهرست را اصلاح می‌کنیم
  if (!db) {
    list = list.filter((w) => w.id !== entry.id);
    await saveIndex(list);
    return openActiveWorkspace();
  }

  setActiveWorkspaceId(entry.id);
  return { db, entry };
}

/** آمار کوتاه هر فضا برای نمایش در فهرست */
export async function workspaceStats(id: ID): Promise<{
  invoices: number;
  parties: number;
  products: number;
} | null> {
  const db = await loadWorkspace(id);
  if (!db) return null;
  return {
    invoices: db.invoices.filter((i) => !i.deletedAt).length,
    parties: db.parties.filter((p) => !p.archived).length,
    products: db.products.filter((p) => !p.archived).length,
  };
}
