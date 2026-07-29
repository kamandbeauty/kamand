import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  alerts, setupProgress, shouldShowSetup, sortAlerts, summarizeHealth,
  type Alert,
} from '../dist/health.js';

describe('اولویت‌بندی هشدارها', () => {
  test('بحرانی پیش از هشدار و اطلاع می‌آید', () => {
    const list: Alert[] = [
      alerts.lowStock(3),                    // warning
      alerts.noBackup(10),                   // info
      alerts.ledgerError(2),                 // critical
    ];
    const sorted = sortAlerts(list);
    assert.equal(sorted[0]?.severity, 'critical');
    assert.equal(sorted[1]?.severity, 'warning');
    assert.equal(sorted[2]?.severity, 'info');
  });

  test('در هم‌رتبه‌ها، مبلغ بزرگ‌تر اول می‌آید', () => {
    const list: Alert[] = [
      alerts.dueSoonCheque(1, 500_000),
      alerts.overdueInvoice(1, 9_000_000),
    ];
    assert.equal(sortAlerts(list)[0]?.amount, 9_000_000);
  });

  test('خلاصه تعداد بحرانی و هشدار را می‌شمارد', () => {
    const s = summarizeHealth([
      alerts.ledgerError(1),
      alerts.unpostedOpening(2),
      alerts.lowStock(5),
    ]);
    assert.equal(s.critical, 2);
    assert.equal(s.warnings, 1);
    assert.equal(s.ready, false);
  });

  test('بدون هشدار، کسب‌وکار آماده است', () => {
    const s = summarizeHealth([]);
    assert.equal(s.ready, true);
    assert.equal(s.critical, 0);
    assert.match(s.message, /مرتب/);
  });

  test('فقط هشدار غیربحرانی، آماده می‌ماند', () => {
    const s = summarizeHealth([alerts.lowStock(2)]);
    assert.equal(s.ready, true);
    assert.equal(s.warnings, 1);
  });

  test('پیام خلاصه فارسی با ارقام فارسی است', () => {
    const s = summarizeHealth([alerts.ledgerError(3)]);
    assert.match(s.message, /[\u0600-\u06FF]/);
    assert.match(s.message, /[۰-۹]/);
  });
});

describe('محتوای هشدارها', () => {
  test('هر هشدار عنوان، شرح و مقصد دارد', () => {
    const all: Alert[] = [
      alerts.unpostedOpening(1),
      alerts.unpostedInventory(2, 1_000_000),
      alerts.negativeInventory(-500_000),
      alerts.ledgerError(1),
      alerts.overdueCheque(1, 100_000),
      alerts.dueSoonCheque(1, 100_000),
      alerts.lowStock(1),
      alerts.overdueInvoice(1, 100_000),
      alerts.unsentTaxInvoice(1),
      alerts.subscriptionExpiring(5),
      alerts.noBackup(30),
      alerts.storagePressure(4, 5),
    ];
    for (const a of all) {
      assert.ok(a.title, `${a.kind} عنوان ندارد`);
      assert.ok(a.detail, `${a.kind} شرح ندارد`);
      assert.ok(a.page, `${a.kind} مقصد ندارد`);
      assert.ok(a.action, `${a.kind} دکمه ندارد`);
      assert.match(a.title, /[\u0600-\u06FF]/, `${a.kind} عنوان فارسی نیست`);
    }
  });

  test('ارزش منفی موجودی قدرمطلق می‌شود', () => {
    assert.equal(alerts.negativeInventory(-500_000).amount, 500_000);
  });

  test('فشار حافظه با درصد بالا بحرانی می‌شود', () => {
    assert.equal(alerts.storagePressure(4.6, 5).severity, 'critical');
    assert.equal(alerts.storagePressure(3.8, 5).severity, 'warning');
  });

  test('هشدار حافظه درصد و مقدار را نشان می‌دهد', () => {
    const a = alerts.storagePressure(4, 5);
    assert.match(a.detail, /[۰-۹]/);
    assert.match(a.detail, /مگابایت/);
    assert.match(a.detail, /پشتیبان/);
  });

  test('اشتراک نزدیک انقضا بحرانی می‌شود', () => {
    assert.equal(alerts.subscriptionExpiring(2).severity, 'critical');
    assert.equal(alerts.subscriptionExpiring(10).severity, 'warning');
  });

  test('پیام انقضا به کاربر اطمینان می‌دهد', () => {
    // ادامهٔ تعهد اول: داده گروگان گرفته نمی‌شود
    assert.match(alerts.subscriptionExpiring(3).detail, /خروجی|ببینید/);
  });
});

describe('راهنمای راه‌اندازی', () => {
  const empty = {
    hasBusinessInfo: false, hasProducts: false, hasParties: false,
    hasOpeningEntry: false, hasInvoice: false, needsOpening: false,
  };

  test('کسب‌وکار خالی هیچ گامی ندارد جز افتتاحیه', () => {
    const p = setupProgress(empty);
    assert.equal(p.total, 5);
    // افتتاحیه چون لازم نیست، انجام‌شده حساب می‌شود
    assert.equal(p.completed, 1);
    assert.equal(p.finished, false);
  });

  test('پیشرفت درصدی محاسبه می‌شود', () => {
    const p = setupProgress({ ...empty, hasProducts: true, hasParties: true });
    assert.equal(p.completed, 3);
    assert.equal(p.percent, 60);
  });

  test('همهٔ گام‌ها که تمام شود، پایان می‌یابد', () => {
    const p = setupProgress({
      hasBusinessInfo: true, hasProducts: true, hasParties: true,
      hasOpeningEntry: true, hasInvoice: true, needsOpening: true,
    });
    assert.equal(p.finished, true);
    assert.equal(p.percent, 100);
  });

  test('اگر مانده اول دوره لازم باشد، گام افتتاحیه باز می‌ماند', () => {
    const p = setupProgress({ ...empty, needsOpening: true });
    const step = p.steps.find((s) => s.id === 'opening');
    assert.equal(step?.done, false);
  });

  test('ترتیب گام‌ها از تله جلوگیری می‌کند', () => {
    const ids = setupProgress(empty).steps.map((s) => s.id);
    // افتتاحیه باید پیش از فاکتور بیاید
    assert.ok(ids.indexOf('opening') < ids.indexOf('invoice'));
    // کالا و شخص پیش از افتتاحیه
    assert.ok(ids.indexOf('products') < ids.indexOf('opening'));
  });

  test('هر گام مقصد و دکمه دارد', () => {
    for (const s of setupProgress(empty).steps) {
      assert.ok(s.page && s.action && s.title && s.detail);
    }
  });

  test('راهنما پس از بستن نمایش داده نمی‌شود', () => {
    const p = setupProgress(empty);
    assert.equal(shouldShowSetup(p, false), true);
    assert.equal(shouldShowSetup(p, true), false);
  });

  test('راهنمای تمام‌شده نمایش داده نمی‌شود', () => {
    const done = setupProgress({
      hasBusinessInfo: true, hasProducts: true, hasParties: true,
      hasOpeningEntry: true, hasInvoice: true, needsOpening: true,
    });
    assert.equal(shouldShowSetup(done, false), false);
  });
});
