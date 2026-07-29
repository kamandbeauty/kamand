import { DatabaseSync } from 'node:sqlite';

/**
 * پایگاه دادهٔ سرور.
 *
 * تصمیم کلیدی: جدول `changes` یک **دفتر فقط-افزودنی** است.
 * هیچ ردیفی حذف یا بازنویسی نمی‌شود؛ حذف هم یک تغییر از نوع delete است.
 * دلیل: همگام‌سازی افزایشی به یک ترتیب پایدار نیاز دارد و ردّ ممیزی
 * در نرم‌افزار مالی چندکاربره اجباری است.
 */

export type DB = DatabaseSync;

const SCHEMA = `
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,
  phone       TEXT NOT NULL UNIQUE,
  name        TEXT,
  created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS otp_codes (
  phone       TEXT PRIMARY KEY,
  code_hash   TEXT NOT NULL,
  expires_at  INTEGER NOT NULL,
  attempts    INTEGER NOT NULL DEFAULT 0,
  sent_at     INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  token       TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id),
  device_id   TEXT NOT NULL,
  device_name TEXT,
  created_at  TEXT NOT NULL,
  last_seen   TEXT NOT NULL,
  revoked     INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);

CREATE TABLE IF NOT EXISTS businesses (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS memberships (
  user_id     TEXT NOT NULL REFERENCES users(id),
  business_id TEXT NOT NULL REFERENCES businesses(id),
  role        TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  PRIMARY KEY (user_id, business_id)
);
CREATE INDEX IF NOT EXISTS idx_memberships_biz ON memberships(business_id);

-- دفتر فقط-افزودنی تغییرات
CREATE TABLE IF NOT EXISTS changes (
  seq         INTEGER PRIMARY KEY AUTOINCREMENT,
  id          TEXT NOT NULL,
  business_id TEXT NOT NULL REFERENCES businesses(id),
  entity      TEXT NOT NULL,
  entity_id   TEXT NOT NULL,
  op          TEXT NOT NULL,
  payload     TEXT,
  lamport     INTEGER NOT NULL,
  device_id   TEXT NOT NULL,
  user_id     TEXT NOT NULL,
  at          TEXT NOT NULL,
  received_at TEXT NOT NULL
);

-- ارسال مجدد همان تغییر نباید رکورد تکراری بسازد
CREATE UNIQUE INDEX IF NOT EXISTS idx_changes_dedupe ON changes(business_id, id);
CREATE INDEX IF NOT EXISTS idx_changes_pull ON changes(business_id, seq);
CREATE INDEX IF NOT EXISTS idx_changes_entity ON changes(business_id, entity, entity_id, lamport);

-- آخرین حالت هر موجودیت، برای حل تعارض بدون بازپخش کل دفتر
CREATE TABLE IF NOT EXISTS entity_state (
  business_id TEXT NOT NULL,
  entity      TEXT NOT NULL,
  entity_id   TEXT NOT NULL,
  lamport     INTEGER NOT NULL,
  device_id   TEXT NOT NULL,
  at          TEXT NOT NULL,
  seq         INTEGER NOT NULL,
  PRIMARY KEY (business_id, entity, entity_id)
);

CREATE TABLE IF NOT EXISTS device_cursors (
  business_id TEXT NOT NULL,
  device_id   TEXT NOT NULL,
  cursor      INTEGER NOT NULL DEFAULT 0,
  updated_at  TEXT NOT NULL,
  PRIMARY KEY (business_id, device_id)
);
`;

export function openDB(path = ':memory:'): DB {
  const db = new DatabaseSync(path);
  db.exec(SCHEMA);
  return db;
}

/** بالاترین ساعت منطقی دیده‌شده در یک کسب‌وکار */
export function serverLamport(db: DB, businessId: string): number {
  const row = db
    .prepare('SELECT COALESCE(MAX(lamport), 0) AS m FROM changes WHERE business_id = ?')
    .get(businessId) as unknown as { m: number } | undefined;
  return row?.m ?? 0;
}

export function latestSeq(db: DB, businessId: string): number {
  const row = db
    .prepare('SELECT COALESCE(MAX(seq), 0) AS m FROM changes WHERE business_id = ?')
    .get(businessId) as unknown as { m: number } | undefined;
  return row?.m ?? 0;
}
