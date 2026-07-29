/** آزمون زنجیرهٔ سقوط ذخیره‌سازی */
import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

const mod = new URL('../test-out/storage.js', import.meta.url).href;

describe('ذخیره‌سازی', async () => {
  test('در نبود IndexedDB و localStorage به حافظه سقوط می‌کند', async () => {
    const s = await import(mod);
    const kind = await s.initStorage();
    assert.equal(kind, 'memory', 'باید حافظهٔ موقت باشد');

    await s.setItem('k', 'v');
    assert.equal(await s.getItem('k'), 'v');
    await s.removeItem('k');
    assert.equal(await s.getItem('k'), null);
  });

  test('خواندن و نوشتن همزمان کار می‌کند', async () => {
    const s = await import(mod);
    s.setItemSync('dev', 'abc');
    assert.equal(s.getItemSync('dev'), 'abc');
  });

  test('مقدار بزرگ بدون خطا ذخیره می‌شود', async () => {
    const s = await import(mod);
    const big = 'x'.repeat(2_000_000);
    await s.setItem('big', big);
    assert.equal((await s.getItem('big'))?.length, 2_000_000);
  });

  test('برآورد فضا در محیط بدون پشتیبانی بدون خطا برمی‌گردد', async () => {
    const s = await import(mod);
    // نباید پرتاب کند حتی وقتی navigator.storage نیست
    const r = await s.storageEstimate();
    assert.ok(r === null || (typeof r === 'object' && 'usage' in r));
  });
});
