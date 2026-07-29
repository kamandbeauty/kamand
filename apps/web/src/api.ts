import {
  errorMessage, toPushChange,
  type PullResult, type PushResult, type RequestOtpResult,
  type ServerChange, type VerifyOtpResult, type BusinessRef,
  type Change,
} from '@javid/core';
import { getItemSync, setItemSync, removeItem } from './storage';

/**
 * کلاینت ارتباط با سرور.
 *
 * قاعدهٔ طلایی: هیچ خطای شبکه‌ای نباید برنامه را متوقف کند.
 * اگر سرور در دسترس نیست، کاربر همچنان روی دادهٔ محلی کار می‌کند
 * و تغییرات در صف می‌مانند.
 */

const TOKEN_KEY = 'javid:token';
const SERVER_KEY = 'javid:server';
const CURSOR_KEY = 'javid:cursor';
const BUSINESS_KEY = 'javid:remoteBusiness';

export class ApiError extends Error {
  readonly code: string;
  readonly status: number;
  constructor(code: string, message: string, status: number) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    this.status = status;
  }
}

export function serverUrl(): string {
  return getItemSync(SERVER_KEY) ?? '';
}

export function setServerUrl(url: string): void {
  setItemSync(SERVER_KEY, url.replace(/\/+$/, ''));
}

export function authToken(): string | null {
  return getItemSync(TOKEN_KEY);
}

export function setAuthToken(token: string | null): void {
  if (token) setItemSync(TOKEN_KEY, token);
  else void removeItem(TOKEN_KEY);
}

export function isConfigured(): boolean {
  return !!serverUrl();
}

export function isSignedIn(): boolean {
  return !!serverUrl() && !!authToken();
}

export function remoteBusinessId(): string | null {
  return getItemSync(BUSINESS_KEY);
}

export function setRemoteBusinessId(id: string | null): void {
  if (id) setItemSync(BUSINESS_KEY, id);
  else void removeItem(BUSINESS_KEY);
}

export function syncCursor(): number {
  return Number(getItemSync(CURSOR_KEY) ?? '0') || 0;
}

export function setSyncCursor(n: number): void {
  setItemSync(CURSOR_KEY, String(n));
}

const TIMEOUT_MS = 15_000;

async function request<T>(
  path: string,
  opts: { method?: string; body?: unknown; auth?: boolean } = {},
): Promise<T> {
  const base = serverUrl();
  if (!base) throw new ApiError('invalid', 'آدرس سرور تنظیم نشده است', 0);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const res = await fetch(base + path, {
      method: opts.method ?? 'GET',
      headers: {
        'content-type': 'application/json',
        ...(opts.auth !== false && authToken() ? { authorization: `Bearer ${authToken()}` } : {}),
      },
      ...(opts.body !== undefined ? { body: JSON.stringify(opts.body) } : {}),
      signal: controller.signal,
    });

    const text = await res.text();
    const data = text ? (JSON.parse(text) as unknown) : null;

    if (!res.ok) {
      const err = data as { error?: string; message?: string } | null;
      const code = err?.error ?? 'server_error';
      // نشست منقضی شده — توکن را پاک می‌کنیم تا کاربر دوباره وارد شود
      if (res.status === 401) setAuthToken(null);
      throw new ApiError(code, err?.message ?? errorMessage(code), res.status);
    }

    return data as T;
  } catch (e) {
    if (e instanceof ApiError) throw e;
    if ((e as Error).name === 'AbortError') {
      throw new ApiError('server_error', 'پاسخی از سرور دریافت نشد', 0);
    }
    throw new ApiError('server_error', 'اتصال به سرور برقرار نشد', 0);
  } finally {
    clearTimeout(timer);
  }
}

// ─────────── احراز هویت ───────────

export function requestOtp(phone: string): Promise<RequestOtpResult> {
  return request('/auth/otp', { method: 'POST', body: { phone }, auth: false });
}

export async function verifyOtp(
  phone: string,
  code: string,
  deviceId: string,
  deviceName?: string,
): Promise<VerifyOtpResult> {
  const r = await request<VerifyOtpResult>('/auth/verify', {
    method: 'POST',
    body: { phone, code, deviceId, deviceName },
    auth: false,
  });
  setAuthToken(r.token);
  return r;
}

export async function logout(): Promise<void> {
  try {
    await request('/auth/logout', { method: 'POST' });
  } catch {
    // حتی اگر سرور در دسترس نبود، محلی خارج می‌شویم
  }
  setAuthToken(null);
  setRemoteBusinessId(null);
  setSyncCursor(0);
}

export function me(): Promise<{ user: { id: string; phone: string }; businesses: BusinessRef[] }> {
  return request('/me');
}

export function createRemoteBusiness(name: string, id?: string): Promise<BusinessRef> {
  return request('/businesses', { method: 'POST', body: { name, id } });
}

export function addMember(businessId: string, phone: string, role: string): Promise<{ ok: boolean }> {
  return request(`/businesses/${businessId}/members`, { method: 'POST', body: { phone, role } });
}

export function health(): Promise<{ ok: boolean; protocol: number }> {
  return request('/health', { auth: false });
}

// ─────────── همگام‌سازی ───────────

export function pushChanges(
  businessId: string,
  deviceId: string,
  changes: Change[],
): Promise<PushResult> {
  const payload = changes
    .map(toPushChange)
    .filter((c): c is NonNullable<ReturnType<typeof toPushChange>> => c !== null);

  return request('/sync/push', {
    method: 'POST',
    body: { businessId, deviceId, changes: payload },
  });
}

export function pullChanges(
  businessId: string,
  deviceId: string,
  since: number,
  limit = 500,
): Promise<PullResult> {
  const q = new URLSearchParams({
    businessId, deviceId, since: String(since), limit: String(limit),
  });
  return request(`/sync/pull?${q}`);
}

export function fetchSnapshot(businessId: string): Promise<{
  entities: Record<string, unknown[]>;
  cursor: number;
}> {
  return request(`/sync/snapshot?businessId=${encodeURIComponent(businessId)}`);
}

export type { ServerChange };
