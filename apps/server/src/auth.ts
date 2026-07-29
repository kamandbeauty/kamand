import { createHash, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { normalizePhone, type BusinessRef, type AuthUser } from '@javid/core';
import type { DB } from './db.js';

/**
 * احراز هویت با شمارهٔ موبایل و کد یک‌بارمصرف.
 *
 * ملاحظات امنیتی:
 *  - کد هرگز خام ذخیره نمی‌شود، فقط هش آن
 *  - مقایسه با timingSafeEqual تا حملهٔ زمانی ممکن نباشد
 *  - محدودیت تعداد تلاش و فاصلهٔ ارسال مجدد
 */

export const OTP_TTL_MS = 2 * 60 * 1000;
export const OTP_RESEND_MS = 60 * 1000;
export const OTP_MAX_ATTEMPTS = 5;

const now = () => Date.now();
const iso = () => new Date().toISOString();

function hashCode(phone: string, code: string): string {
  return createHash('sha256').update(`${phone}:${code}`).digest('hex');
}

export function newId(): string {
  return randomBytes(16).toString('hex').replace(
    /^(.{8})(.{4})(.{4})(.{4})(.{12})$/,
    (_, a, b, c, d, e) => `${a}-${b}-4${c.slice(1)}-8${d.slice(1)}-${e}`,
  );
}

export interface OtpOutcome {
  ok: boolean;
  retryAfter: number;
  code?: string;
  error?: string;
}

export function requestOtp(db: DB, rawPhone: string, isDev: boolean): OtpOutcome {
  const phone = normalizePhone(rawPhone);
  if (!phone) return { ok: false, retryAfter: 0, error: 'شمارهٔ موبایل نامعتبر است' };

  const existing = db
    .prepare('SELECT sent_at FROM otp_codes WHERE phone = ?')
    .get(phone) as unknown as { sent_at: number } | undefined;

  if (existing) {
    const elapsed = now() - existing.sent_at;
    if (elapsed < OTP_RESEND_MS) {
      return {
        ok: false,
        retryAfter: Math.ceil((OTP_RESEND_MS - elapsed) / 1000),
        error: 'کد قبلی هنوز معتبر است',
      };
    }
  }

  const code = String(randomInt(100000, 1000000));
  db.prepare(`
    INSERT INTO otp_codes (phone, code_hash, expires_at, attempts, sent_at)
    VALUES (?, ?, ?, 0, ?)
    ON CONFLICT(phone) DO UPDATE SET
      code_hash = excluded.code_hash,
      expires_at = excluded.expires_at,
      attempts = 0,
      sent_at = excluded.sent_at
  `).run(phone, hashCode(phone, code), now() + OTP_TTL_MS, now());

  // در محیط واقعی اینجا پیامک ارسال می‌شود
  return { ok: true, retryAfter: Math.ceil(OTP_RESEND_MS / 1000), ...(isDev ? { code } : {}) };
}

export interface VerifyOutcome {
  ok: boolean;
  token?: string;
  user?: AuthUser;
  businesses?: BusinessRef[];
  error?: string;
}

export function verifyOtp(
  db: DB,
  rawPhone: string,
  code: string,
  deviceId: string,
  deviceName?: string,
): VerifyOutcome {
  const phone = normalizePhone(rawPhone);
  if (!phone) return { ok: false, error: 'شمارهٔ موبایل نامعتبر است' };
  if (!deviceId) return { ok: false, error: 'شناسهٔ دستگاه الزامی است' };

  const row = db
    .prepare('SELECT code_hash, expires_at, attempts FROM otp_codes WHERE phone = ?')
    .get(phone) as unknown as { code_hash: string; expires_at: number; attempts: number } | undefined;

  if (!row) return { ok: false, error: 'ابتدا کد تأیید را درخواست کنید' };

  if (now() > row.expires_at) {
    db.prepare('DELETE FROM otp_codes WHERE phone = ?').run(phone);
    return { ok: false, error: 'کد منقضی شده است' };
  }

  if (row.attempts >= OTP_MAX_ATTEMPTS) {
    db.prepare('DELETE FROM otp_codes WHERE phone = ?').run(phone);
    return { ok: false, error: 'تعداد تلاش‌ها بیش از حد مجاز است' };
  }

  const expected = Buffer.from(row.code_hash, 'hex');
  const actual = Buffer.from(hashCode(phone, code.trim()), 'hex');
  const match = expected.length === actual.length && timingSafeEqual(expected, actual);

  if (!match) {
    db.prepare('UPDATE otp_codes SET attempts = attempts + 1 WHERE phone = ?').run(phone);
    return { ok: false, error: 'کد وارد‌شده صحیح نیست' };
  }

  db.prepare('DELETE FROM otp_codes WHERE phone = ?').run(phone);

  let user = db.prepare('SELECT id, phone, name FROM users WHERE phone = ?').get(phone) as
    | unknown as AuthUser | undefined;

  if (!user) {
    const id = newId();
    db.prepare('INSERT INTO users (id, phone, created_at) VALUES (?, ?, ?)').run(id, phone, iso());
    user = { id, phone };
  }

  const token = randomBytes(32).toString('hex');
  db.prepare(`
    INSERT INTO sessions (token, user_id, device_id, device_name, created_at, last_seen)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(token, user.id, deviceId, deviceName ?? null, iso(), iso());

  return { ok: true, token, user, businesses: businessesOf(db, user.id) };
}

export function businessesOf(db: DB, userId: string): BusinessRef[] {
  return db.prepare(`
    SELECT b.id, b.name, m.role
    FROM memberships m
    JOIN businesses b ON b.id = m.business_id
    WHERE m.user_id = ?
    ORDER BY b.name
  `).all(userId) as unknown as BusinessRef[];
}

export interface Session {
  userId: string;
  deviceId: string;
}

export function sessionOf(db: DB, token: string | null): Session | null {
  if (!token) return null;
  const row = db
    .prepare('SELECT user_id, device_id FROM sessions WHERE token = ? AND revoked = 0')
    .get(token) as unknown as { user_id: string; device_id: string } | undefined;
  if (!row) return null;
  db.prepare('UPDATE sessions SET last_seen = ? WHERE token = ?').run(iso(), token);
  return { userId: row.user_id, deviceId: row.device_id };
}

export function revokeSession(db: DB, token: string): void {
  db.prepare('UPDATE sessions SET revoked = 1 WHERE token = ?').run(token);
}

export type Role = 'owner' | 'accountant' | 'salesperson' | 'viewer';

export function roleOf(db: DB, userId: string, businessId: string): Role | null {
  const row = db
    .prepare('SELECT role FROM memberships WHERE user_id = ? AND business_id = ?')
    .get(userId, businessId) as unknown as { role: Role } | undefined;
  return row?.role ?? null;
}

/** فقط این نقش‌ها اجازهٔ نوشتن دارند */
const WRITE_ROLES: Role[] = ['owner', 'accountant', 'salesperson'];

export function canWrite(role: Role | null): boolean {
  return role !== null && WRITE_ROLES.includes(role);
}

export function createBusiness(db: DB, userId: string, name: string, id?: string): BusinessRef {
  const bid = id ?? newId();
  db.prepare('INSERT INTO businesses (id, name, created_at) VALUES (?, ?, ?)').run(bid, name, iso());
  db.prepare(`
    INSERT INTO memberships (user_id, business_id, role, created_at) VALUES (?, ?, 'owner', ?)
  `).run(userId, bid, iso());
  return { id: bid, name, role: 'owner' };
}

export function addMember(
  db: DB,
  businessId: string,
  phone: string,
  role: Role,
): { ok: boolean; error?: string } {
  const normalized = normalizePhone(phone);
  if (!normalized) return { ok: false, error: 'شمارهٔ موبایل نامعتبر است' };

  let user = db.prepare('SELECT id FROM users WHERE phone = ?').get(normalized) as
    | unknown as { id: string } | undefined;

  if (!user) {
    const id = newId();
    db.prepare('INSERT INTO users (id, phone, created_at) VALUES (?, ?, ?)').run(id, normalized, iso());
    user = { id };
  }

  db.prepare(`
    INSERT INTO memberships (user_id, business_id, role, created_at) VALUES (?, ?, ?, ?)
    ON CONFLICT(user_id, business_id) DO UPDATE SET role = excluded.role
  `).run(user.id, businessId, role, iso());

  return { ok: true };
}
