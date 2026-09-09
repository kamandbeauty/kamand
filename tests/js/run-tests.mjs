/**
 * آزمون رفتار اسکریپت واقعی فروشگاه (assets/js/frontend.js) در محیط jsdom.
 *
 * اجرا: node tests/js/run-tests.mjs  (نیازمند `npm install` در tests/js)
 */

import { JSDOM } from 'jsdom';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..', '..');
const frontendJs = readFileSync(resolve(repoRoot, 'kamand-size-guide/assets/js/frontend.js'), 'utf8');

const fixture = `
<!doctype html>
<html lang="fa" dir="rtl">
<head><meta charset="utf-8" /><title>fixture</title></head>
<body>
<main id="page">
	<form class="variations_form cart">
		<div class="variations">
			<select name="attribute_pa_size">
				<option value="">یک گزینه انتخاب کنید…</option>
				<option value="s">S</option>
				<option value="m" selected>M</option>
				<option value="l">L</option>
			</select>
		</div>
		<button type="submit">افزودن به سبد خرید</button>
	</form>

	<div class="ksg" id="ksg-101" data-ksg='{"blockId":"ksg-101","defaultUnit":"cm","showUnits":true,"persianDigits":true,"matchVariation":true,"cmLabel":"سانتی‌متر","inchLabel":"اینچ"}'>
		<div class="ksg__inner">
			<header class="ksg__head">
				<div class="ksg__tools">
					<div class="ksg__switch" role="group">
						<button type="button" class="ksg__switch-btn is-on" data-ksg-unit="cm">سانتی‌متر</button>
						<button type="button" class="ksg__switch-btn" data-ksg-unit="inch">اینچ</button>
					</div>
					<button type="button" class="ksg__expand" data-ksg-expand><span>نمایش بزرگ‌تر</span></button>
				</div>
			</header>

			<div class="ksg__tabs" role="tablist">
				<button type="button" role="tab" id="ksg-101-tab-0" class="ksg__tab is-on" aria-selected="true" aria-controls="ksg-101-panel-0" data-ksg-tab="0">پوشاک</button>
				<button type="button" role="tab" id="ksg-101-tab-1" class="ksg__tab" aria-selected="false" aria-controls="ksg-101-panel-1" data-ksg-tab="1">کفش</button>
			</div>

			<div class="ksg__panel is-on" id="ksg-101-panel-0" role="tabpanel" data-ksg-unit="cm">
				<div class="ksg__scroller" tabindex="0">
					<table class="ksg__table">
						<thead><tr>
							<th scope="col" class="ksg__th ksg__th--size">سایز</th>
							<th scope="col" class="ksg__th ksg__th--measure">دور سینه<span class="ksg__unit-chip" data-ksg-unit-chip></span></th>
						</tr></thead>
						<tbody>
							<tr class="ksg__row" data-ksg-size="s"><th scope="row" class="ksg__cell ksg__cell--head">S</th><td class="ksg__cell ksg__cell--measure" data-ksg-kind="measure" data-ksg-raw="86">86</td></tr>
							<tr class="ksg__row" data-ksg-size="m"><th scope="row" class="ksg__cell ksg__cell--head">M</th><td class="ksg__cell ksg__cell--measure" data-ksg-kind="measure" data-ksg-raw="92">92</td></tr>
							<tr class="ksg__row" data-ksg-size="l"><th scope="row" class="ksg__cell ksg__cell--head">L</th><td class="ksg__cell ksg__cell--measure" data-ksg-kind="measure" data-ksg-raw="98">98</td></tr>
						</tbody>
					</table>
				</div>
			</div>

			<div class="ksg__panel" id="ksg-101-panel-1" role="tabpanel" hidden data-ksg-unit="cm">
				<div class="ksg__scroller" tabindex="0">
					<table class="ksg__table">
						<thead><tr>
							<th scope="col" class="ksg__th ksg__th--size">سایز</th>
							<th scope="col" class="ksg__th ksg__th--measure">طول پا<span class="ksg__unit-chip" data-ksg-unit-chip></span></th>
						</tr></thead>
						<tbody>
							<tr class="ksg__row" data-ksg-size="42"><th scope="row" class="ksg__cell ksg__cell--head">۴۲</th><td class="ksg__cell ksg__cell--measure" data-ksg-kind="measure" data-ksg-raw="26.5">26.5</td></tr>
						</tbody>
					</table>
				</div>
			</div>

			<footer class="ksg__foot">
				<span class="ksg__hint" data-ksg-hint hidden><span class="ksg__hint-text">ردیف برجسته</span></span>
			</footer>
		</div>
	</div>
</main>

<script>window.ksgFrontend = { persianDigits: true, cmLabel: 'سانتی‌متر', inchLabel: 'اینچ', closeLabel: 'بستن', expandLabel: 'نمایش بزرگ‌تر' };</script>
<script>${frontendJs}</script>
</body>
</html>
`;

let total = 0;
let passed = 0;
const failures = [];

function check(label, condition, extra = '') {
	total++;
	if (condition) {
		passed++;
		console.log('  ✓ ' + label);
	} else {
		failures.push(label + (extra ? ' — ' + extra : ''));
		console.log('  ✗ ' + label + (extra ? ' — ' + extra : ''));
	}
}

function equal(label, actual, expected) {
	check(label, actual === expected, 'انتظار «' + expected + '» — دریافت «' + actual + '»');
}

const dom = new JSDOM(fixture, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'https://example.test/product/demo/' });
const { window } = dom;
const { document } = window;

await new Promise((resolveLoad) => window.addEventListener('load', resolveLoad));

console.log('\n۱) وضعیت اولیه');

const block = document.getElementById('ksg-101');
const panel0 = document.getElementById('ksg-101-panel-0');
const panel1 = document.getElementById('ksg-101-panel-1');
const cells = () => Array.from(panel0.querySelectorAll('[data-ksg-raw]')).map((cell) => cell.textContent);

equal('اسکریپت روی بلوک اجرا شد', block.dataset.ksgReady, '1');
equal('اعداد در حالت اولیه با رقم فارسی نوشته شدند', cells().join(','), '۸۶,۹۲,۹۸');
equal('واحد فعال اولیه سانتی‌متر است', block.getAttribute('data-ksg-active-unit'), 'cm');
equal('برچسب واحد در حالت هم‌واحد خالی است', panel0.querySelector('[data-ksg-unit-chip]').textContent, '');

console.log('\n۲) برجسته‌سازی سایز انتخاب‌شده');

const activeSizes = () => Array.from(panel0.querySelectorAll('.ksg__row.is-active')).map((row) => row.getAttribute('data-ksg-size'));
equal('سایز از پیش انتخاب‌شدهٔ فرم (M) برجسته شد', activeSizes().join(','), 'm');
equal('راهنمای برجسته‌سازی نمایان شد', document.querySelector('[data-ksg-hint]').hidden, false);

const select = document.querySelector('select[name="attribute_pa_size"]');
select.value = 'l';
select.dispatchEvent(new window.Event('change', { bubbles: true }));
await new Promise((r) => setTimeout(r, 5));
equal('با تغییر سایز به L، ردیف L برجسته شد', activeSizes().join(','), 'l');

console.log('\n۳) تبدیل سانتی‌متر به اینچ');

document.querySelector('[data-ksg-unit="inch"]').click();
equal('اعداد به اینچ تبدیل شدند', cells().join(','), '۳۳.۹,۳۶.۲,۳۸.۶');
equal('برچسب واحد در سرستون نشست', panel0.querySelector('[data-ksg-unit-chip]').textContent, 'اینچ');
equal('کلید اینچ فعال شد', document.querySelector('[data-ksg-unit="inch"]').classList.contains('is-on'), true);
equal('واحد انتخابی در localStorage ماند', window.localStorage.getItem('ksgUnit'), 'inch');

document.querySelector('[data-ksg-unit="cm"]').click();
equal('بازگشت به سانتی‌متر بدون خطای گرد شدن', cells().join(','), '۸۶,۹۲,۹۸');
equal('برچسب واحد پاک شد', panel0.querySelector('[data-ksg-unit-chip]').textContent, '');

console.log('\n۴) تب‌ها');

document.getElementById('ksg-101-tab-1').click();
equal('پنل دوم نمایان شد', panel1.hidden, false);
equal('پنل اول پنهان شد', panel0.hidden, true);
equal('تب دوم aria-selected گرفت', document.getElementById('ksg-101-tab-1').getAttribute('aria-selected'), 'true');

document.getElementById('ksg-101-tab-0').click();
equal('بازگشت به پنل اول', panel0.hidden, false);

console.log('\n۵) پنجرهٔ بزرگ‌نمایی');

const originalParent = block.parentNode;
document.querySelector('[data-ksg-expand]').click();

const overlay = document.querySelector('.ksg-overlay');
check('پنجرهٔ بزرگ‌نمایی ساخته شد', Boolean(overlay));
check('بلوک به پنجره منتقل شد', Boolean(overlay && overlay.contains(block)));
equal('قفل پیمایش صفحه فعال شد', document.documentElement.classList.contains('ksg-lock'), true);

document.dispatchEvent(new window.KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
check('با Escape پنجره بسته شد', !document.querySelector('.ksg-overlay'));
equal('بلوک به جای اولش برگشت', block.parentNode, originalParent);
equal('قفل پیمایش برداشته شد', document.documentElement.classList.contains('ksg-lock'), false);

console.log('\n۶) انتخاب دستی ردیف');

const rowS = panel0.querySelector('[data-ksg-size="s"]');
rowS.click();
equal('با کلیک، ردیف S برجسته و بقیه پاک شدند', activeSizes().join(','), 's');
rowS.click();
equal('کلیک دوم، برجسته‌سازی دستی را برمی‌دارد', activeSizes().join(','), '');

console.log('\n۷) اجرای دوباره روی بلوک تازه');

const clone = block.cloneNode(true);
clone.removeAttribute('data-ksg-ready');
clone.id = 'ksg-202';
document.getElementById('page').appendChild(clone);
await new Promise((r) => setTimeout(r, 10));
equal('بلوک تازهٔ افزوده‌شده هم راه‌اندازی شد', clone.dataset.ksgReady, '1');
equal('اعداد بلوک تازه هم فارسی شد', clone.querySelector('[data-ksg-raw]').textContent, '۸۶');

console.log('\n' + '─'.repeat(46));

if (failures.length === 0) {
	console.log(`همهٔ ${passed} بررسی از ${total} مورد موفق بود ✅`);
	process.exit(0);
}

console.log(`${failures.length} مورد از ${total} بررسی ناموفق بود ❌`);
failures.forEach((label) => console.log(' - ' + label));
process.exit(1);
