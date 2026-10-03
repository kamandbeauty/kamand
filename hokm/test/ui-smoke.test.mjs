import { JSDOM } from 'jsdom';
import * as esbuild from 'esbuild';
import fs from 'fs';

const dom = new JSDOM('<!doctype html><html dir="rtl"><body><div id="root"></div></body></html>', { url: 'http://localhost/', pretendToBeVisual: true });
global.window = dom.window; global.document = dom.window.document;
Object.defineProperty(global, "navigator", { value: dom.window.navigator, configurable: true });
global.HTMLElement = dom.window.HTMLElement;
global.requestAnimationFrame = dom.window.requestAnimationFrame.bind(dom.window);
global.cancelAnimationFrame = dom.window.cancelAnimationFrame.bind(dom.window);
const store = {};
global.localStorage = dom.window.localStorage;
dom.window.AudioContext = undefined; // بدون صدا

const errs = [];
const origErr = console.error;
console.error = (...a) => { errs.push(a.join(' ')); origErr(...a); };

// ترنسپایل سورس به CJS-friendly ESM در حافظه
const out = await esbuild.build({
  entryPoints: [new URL('../src/App.jsx', import.meta.url).pathname],
  bundle: true, format: 'esm', write: false, jsx: 'automatic',
  external: ['react', 'react-dom', 'react-dom/client'],
  loader: { '.css': 'empty' },
  outfile: 'out.js',
});
fs.writeFileSync(new URL('../.smoke.bundle.mjs', import.meta.url), out.outputFiles[0].text);
const bundleUrl = new URL('../.smoke.bundle.mjs', import.meta.url);
const { default: App } = await import(bundleUrl.href);
const React = (await import('react')).default;
const { createRoot } = await import('react-dom/client');

const root = createRoot(document.getElementById('root'));
const { act } = await import('react').then(m=>({act:m.act}));
global.IS_REACT_ACT_ENVIRONMENT = true;

await act(async () => { root.render(React.createElement(App)); });
const txt = () => document.getElementById('root').textContent;
console.log('MENU:', txt().slice(0, 80));

const click = async (pred) => {
  const btn = [...document.querySelectorAll('button')].find(pred);
  if (!btn) throw new Error('button not found');
  await act(async () => { btn.dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true })); });
  return btn;
};

// بازی جدید
await click(b => b.textContent.includes('بازی جدید'));
// اجرای تایمرها تا مرحله‌ی بازی
for (let i = 0; i < 400; i++) {
  await act(async () => { await new Promise(r => setTimeout(r, 12)); });
  const hand = document.querySelectorAll('.hand--south .card');
  if (hand.length) break;
}
console.log('phase after deal, south cards:', document.querySelectorAll('.hand--south .card').length);
console.log('trump badge:', document.querySelector('.trump-badge')?.textContent);
console.log('seats:', document.querySelectorAll('.nameplate').length, 'crown:', !!document.querySelector('.crown'));

// اگر انتخاب حکم با ماست
if (document.querySelector('.trump-chooser')) {
  await click(b => b.className.includes('trump-btn'));
  console.log('chose trump manually');
}
// چند دست بازی: روی هر کارت مجاز کلیک کن
let played = 0;
for (let i = 0; i < 2500 && played < 13; i++) {
  await act(async () => { await new Promise(r => setTimeout(r, 10)); });
  if (document.querySelector('.trump-chooser')) { await click(b => b.className.includes('trump-btn')); continue; }
  const next = [...document.querySelectorAll('button')].find(b => b.textContent.trim() === 'راند بعد');
  if (next) { await act(async () => next.dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }))); continue; }
  const c = document.querySelector('.hand--south .card--playable');
  if (c) { await act(async () => c.dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }))); played++; }
}
console.log('human cards played:', played);
console.log('scores pill:', document.querySelector('.score-pill')?.textContent);
console.log('saved:', !!localStorage.getItem('hokm.save.v1'));
// باز کردن مودال‌ها
await click(b => b.className.includes('score-pill'));
console.log('scoreboard rows:', document.querySelectorAll('.score-table tbody tr').length);
await click(b => b.textContent === '✕');
await click(b => b.className.includes('pile'));
console.log('trick viewer items:', document.querySelectorAll('.trick-view-item').length);
await click(b => b.textContent === '✕');
await click(b => b.title === 'تنظیمات');
console.log('surface options:', document.querySelectorAll('.surface-opt').length, 'backs:', document.querySelectorAll('.back-opt').length);

const real = errs.filter(e => !/not wrapped in act|validateDOMNesting/.test(e));
console.log('REACT ERRORS:', real.length);
if (real.length) { console.log(real.slice(0,3)); process.exit(1); }
console.log('SMOKE TEST PASSED');
process.exit(0);
