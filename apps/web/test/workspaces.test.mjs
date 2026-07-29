/**
 * آزمون چند کسب‌وکاره.
 *
 * مهم‌ترین ادعا: هیچ داده‌ای بین کسب‌وکارها نشت نمی‌کند.
 * دومین ادعا: کاربر نسخهٔ قبلی داده‌اش را از دست نمی‌دهد.
 */
import { test, describe, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

const wsMod = new URL('../test-out/workspaces.js', import.meta.url).href;
const stMod = new URL('../test-out/storage.js', import.meta.url).href;

const ws = await import(wsMod);
const storage = await import(stMod);

beforeEach(async () => {
  await storage.initStorage();
  // پاک‌سازی بین آزمون‌ها
  for (const w of await ws.listWorkspaces()) {
    await storage.removeItem(`javid:db:${w.id}`);
  }
  await storage.removeItem('javid:workspaces');
  await storage.removeItem('javid:db:v1');
  storage.setItemSync('javid:activeWorkspace', '');
});

describe('ایجاد و فهرست', () => {
  test('کسب‌وکار جدید ساخته و ثبت می‌شود', async () => {
    const { entry, db } = await ws.createWorkspace('فروشگاه اول');
    assert.equal(entry.name, 'فروشگاه اول');
    assert.equal(db.business.name, 'فروشگاه اول');

    const list = await ws.listWorkspaces();
    assert.equal(list.length, 1);
    assert.equal(list[0].id, entry.id);
  });

  test('نام تکراری رد می‌شود', async () => {
    await ws.createWorkspace('یکتا');
    await assert.rejects(() => ws.createWorkspace('یکتا'), /وجود دارد/);
  });

  test('نام خالی رد می‌شود', async () => {
    await assert.rejects(() => ws.createWorkspace('   '), /الزامی/);
  });

  test('چند کسب‌وکار کنار هم زندگی می‌کنند', async () => {
    await ws.createWorkspace('اول');
    await ws.createWorkspace('دوم');
    await ws.createWorkspace('سوم');
    assert.equal((await ws.listWorkspaces()).length, 3);
  });
});

describe('جداسازی داده — مهم‌ترین ادعا', () => {
  test('دادهٔ یک کسب‌وکار در دیگری دیده نمی‌شود', async () => {
    const a = await ws.createWorkspace('فروشگاه الف');
    const b = await ws.createWorkspace('فروشگاه ب');

    // در «الف» یک شخص اضافه می‌کنیم
    const withParty = {
      ...a.db,
      parties: [{
        id: 'p-secret', businessId: a.db.business.id,
        kind: 'customer', name: 'مشتری محرمانه', openingBalance: 9_999_999,
      }],
    };
    await ws.saveWorkspace(withParty);

    const loadedA = await ws.loadWorkspace(a.entry.id);
    const loadedB = await ws.loadWorkspace(b.entry.id);

    assert.equal(loadedA.parties.length, 1);
    assert.equal(loadedB.parties.length, 0, '🔴 نشتی داده بین کسب‌وکارها');
    assert.ok(!JSON.stringify(loadedB).includes('محرمانه'), 'هیچ اثری نباید بماند');
  });

  test('شناسهٔ کسب‌وکار در هر فضا متفاوت است', async () => {
    const a = await ws.createWorkspace('الف');
    const b = await ws.createWorkspace('ب');
    assert.notEqual(a.db.business.id, b.db.business.id);
  });

  test('نوشتن در یکی، دیگری را تغییر نمی‌دهد', async () => {
    const a = await ws.createWorkspace('الف');
    const b = await ws.createWorkspace('ب');
    const before = JSON.stringify(await ws.loadWorkspace(b.entry.id));

    await ws.saveWorkspace({ ...a.db, products: [{ id: 'x', businessId: a.db.business.id, name: 'کالا' }] });

    assert.equal(JSON.stringify(await ws.loadWorkspace(b.entry.id)), before);
  });
});

describe('جابه‌جایی', () => {
  test('فضای فعال عوض می‌شود', async () => {
    const a = await ws.createWorkspace('الف');
    const b = await ws.createWorkspace('ب');

    const switched = await ws.switchWorkspace(b.entry.id);
    assert.equal(switched.business.id, b.entry.id);
    assert.equal(ws.activeWorkspaceId(), b.entry.id);

    await ws.switchWorkspace(a.entry.id);
    assert.equal(ws.activeWorkspaceId(), a.entry.id);
  });

  test('جابه‌جایی به فضای ناموجود null می‌دهد', async () => {
    assert.equal(await ws.switchWorkspace('ghost'), null);
  });

  test('زمان آخرین بازدید بروز می‌شود', async () => {
    const a = await ws.createWorkspace('الف');
    await ws.switchWorkspace(a.entry.id);
    const list = await ws.listWorkspaces();
    assert.ok(list[0].lastOpenedAt);
  });
});

describe('تغییر نام و حذف', () => {
  test('تغییر نام در فهرست و پایگاه داده اعمال می‌شود', async () => {
    const a = await ws.createWorkspace('نام قدیم');
    await ws.renameWorkspace(a.entry.id, 'نام جدید');

    assert.equal((await ws.listWorkspaces())[0].name, 'نام جدید');
    assert.equal((await ws.loadWorkspace(a.entry.id)).business.name, 'نام جدید');
  });

  test('تغییر نام به نام تکراری رد می‌شود', async () => {
    await ws.createWorkspace('الف');
    const b = await ws.createWorkspace('ب');
    await assert.rejects(() => ws.renameWorkspace(b.entry.id, 'الف'), /وجود دارد/);
  });

  test('آخرین کسب‌وکار حذف نمی‌شود', async () => {
    const a = await ws.createWorkspace('تنها');
    await assert.rejects(() => ws.deleteWorkspace(a.entry.id), /آخرین/);
  });

  test('حذف پشتیبان برمی‌گرداند', async () => {
    const a = await ws.createWorkspace('الف');
    await ws.createWorkspace('ب');

    const { backup } = await ws.deleteWorkspace(a.entry.id);
    const parsed = JSON.parse(backup);
    assert.equal(parsed.business.name, 'الف', 'پشتیبان باید دادهٔ کامل باشد');

    assert.equal((await ws.listWorkspaces()).length, 1);
    assert.equal(await ws.loadWorkspace(a.entry.id), null);
  });

  test('حذف فضای فعال، فضای دیگری را فعال می‌کند', async () => {
    const a = await ws.createWorkspace('الف');
    await ws.createWorkspace('ب');
    await ws.switchWorkspace(a.entry.id);

    await ws.deleteWorkspace(a.entry.id);
    assert.notEqual(ws.activeWorkspaceId(), a.entry.id);
  });
});

describe('مهاجرت از نسخهٔ تک‌کسب‌وکاره', () => {
  test('دادهٔ قدیمی خودکار منتقل می‌شود', async () => {
    const legacy = {
      business: { id: 'old-biz', name: 'فروشگاه قدیمی', createdAt: '2026-01-01T00:00:00Z',
        fiscalYearStartMonth: 1, costingMethod: 'fifo', defaultVatRate: 10, currencyUnit: 'toman' },
      parties: [{ id: 'p1', businessId: 'old-biz', kind: 'customer', name: 'مشتری قدیمی', openingBalance: 0 }],
      products: [], invoices: [], transactions: [], cheques: [],
      treasuries: [], entries: [], movements: [], accounts: [],
      subscription: { businessId: 'old-biz', plan: 'trial', startedAt: '', expiresAt: '', status: 'trial' },
    };
    await storage.setItem('javid:db:v1', JSON.stringify(legacy));

    const migrated = await ws.migrateLegacyWorkspace();
    assert.ok(migrated, 'مهاجرت باید انجام شود');
    assert.equal(migrated.name, 'فروشگاه قدیمی');

    const loaded = await ws.loadWorkspace('old-biz');
    assert.equal(loaded.parties[0].name, 'مشتری قدیمی', 'داده نباید گم شود');
  });

  test('مهاجرت دوباره انجام نمی‌شود', async () => {
    await storage.setItem('javid:db:v1', JSON.stringify({
      business: { id: 'x', name: 'قدیمی', createdAt: '2026-01-01T00:00:00Z' },
      parties: [], products: [], invoices: [], transactions: [], cheques: [],
      treasuries: [], entries: [], movements: [], accounts: [],
    }));
    assert.ok(await ws.migrateLegacyWorkspace());
    assert.equal(await ws.migrateLegacyWorkspace(), null, 'بار دوم نباید تکرار شود');
  });

  test('دادهٔ قدیمی پس از مهاجرت پاک نمی‌شود', async () => {
    await storage.setItem('javid:db:v1', JSON.stringify({
      business: { id: 'y', name: 'ق', createdAt: '2026-01-01T00:00:00Z' },
      parties: [], products: [], invoices: [], transactions: [], cheques: [],
      treasuries: [], entries: [], movements: [], accounts: [],
    }));
    await ws.migrateLegacyWorkspace();
    assert.ok(await storage.getItem('javid:db:v1'), 'نسخهٔ اصلی باید بماند');
  });

  test('بدون دادهٔ قدیمی، مهاجرت بی‌اثر است', async () => {
    assert.equal(await ws.migrateLegacyWorkspace(), null);
  });
});

describe('باز کردن فضای فعال', () => {
  test('نبود فضا، یکی می‌سازد', async () => {
    const { db, entry } = await ws.openActiveWorkspace();
    assert.ok(db.business.id);
    assert.equal((await ws.listWorkspaces()).length, 1);
    assert.equal(ws.activeWorkspaceId(), entry.id);
  });

  test('فضای فعال قبلی باز می‌شود', async () => {
    await ws.createWorkspace('الف');
    const b = await ws.createWorkspace('ب');
    ws.setActiveWorkspaceId(b.entry.id);

    const { db } = await ws.openActiveWorkspace();
    assert.equal(db.business.id, b.entry.id);
  });

  test('فهرست خراب خودترمیم می‌شود', async () => {
    const a = await ws.createWorkspace('الف');
    await ws.createWorkspace('ب');
    // دادهٔ «الف» را دستی پاک می‌کنیم ولی در فهرست می‌ماند
    await storage.removeItem(`javid:db:${a.entry.id}`);
    ws.setActiveWorkspaceId(a.entry.id);

    const { db } = await ws.openActiveWorkspace();
    assert.ok(db, 'باید فضای سالم دیگری باز شود');
    assert.equal((await ws.listWorkspaces()).length, 1, 'ورودی خراب حذف می‌شود');
  });
});
