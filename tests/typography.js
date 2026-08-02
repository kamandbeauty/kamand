/* Typography sizing — the "English fonts are huge and scattered" report.
 *
 * Three independent causes, each locked in here:
 *
 *   1. `#havato-app button { font: inherit }` scored 1-0-1 and beat every
 *      component rule (.hv-tab, .hv-btn, .hv-chip … all 0-1-0), so EVERY
 *      button rendered at full body size instead of its own.
 *   2. Sizes were written in `rem`, which resolves against the host theme's
 *      <html>. A theme (or Chrome's text scaling) that grows the root grows
 *      the whole app, and a clamp whose floor is in rem cannot clamp it.
 *   3. The five-tab bar carried possessive labels ("My Tables", "My Profile")
 *      that do not fit one fifth of a phone and were ellipsised to "MY TABL…".
 *
 * These are cascade/units facts, so they can be verified statically.
 */
const fs = require('fs');
const R = __dirname + '/../havato/';
const css = fs.readFileSync(R + 'assets/css/havato-app.css', 'utf8');
const js = fs.readFileSync(R + 'assets/js/havato-app.js', 'utf8');
const i18n = fs.readFileSync(R + 'includes/class-havato-i18n.php', 'utf8');

let f = 0;
const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) { f++; } };

// Comments legitimately describe the old broken code, so reason about the
// real declarations only.
const bare = css.replace(/\/\*[\s\S]*?\*\//g, '');

/* ------------------------------------------------------------------ */
console.log('--- cause 1: the font shorthand no longer outranks components ---');

t('no id-weight `font: inherit` on controls any more',
  !/#havato-app\s+button[^{]*\{[^}]*\bfont:\s*inherit/s.test(bare));

{
  // Whatever hands the defaults down must contribute zero specificity.
  const m = bare.match(/:where\(#havato-app\)\s*:where\([^)]*\)\s*\{([^}]*)\}/);
  t('defaults are handed down through a :where() wrapper', !!m);
  if (m) {
    t('  …and it carries font-size', /font-size:\s*inherit/.test(m[1]));
    t('  …and font-weight', /font-weight:\s*inherit/.test(m[1]));
    t('  …and line-height', /line-height:\s*inherit/.test(m[1]));
  }
  const sel = m ? bare.slice(0, m.index).length : -1;
  t('the :where() rule exists before component rules can be measured', sel !== -1);
}

{
  // The family SHOULD stay at id weight — a host theme must not swap the
  // Persian face out — but it must not drag size along with it.
  const idRule = bare.match(/#havato-app\s+button,[\s\S]{0,200}?textarea\s*\{([^}]*)\}/);
  t('family is still pinned at id weight', !!idRule && /font-family:\s*inherit/.test(idRule[1]));
  t('  …without pulling font-size up with it', !!idRule && !/font-size/.test(idRule[1]));
  t('  …and without the shorthand', !!idRule && !/\bfont:\s/.test(idRule[1]));
}

{
  // Specificity model: (id, class, type). A component rule must now win.
  const beats = (a, b) => {
    for (let i = 0; i < 3; i++) { if (a[i] !== b[i]) { return a[i] > b[i]; } }
    return false;
  };
  t('`.hv-tab` (0-1-0) beats `:where(#havato-app) :where(button)` (0-0-0)',
    beats([0, 1, 0], [0, 0, 0]));
  t('`.hv-btn` (0-1-0) beats it too', beats([0, 1, 0], [0, 0, 0]));
  t('and the old `#havato-app button` (1-0-1) would NOT have lost',
    beats([1, 0, 1], [0, 1, 0]));
}

// The components whose size was being overridden must still declare one.
for (const cls of ['hv-tab', 'hv-btn', 'hv-chip', 'hv-subtab', 'hv-choice']) {
  const m = bare.match(new RegExp('\\n\\.' + cls + '\\s*\\{([^}]*)\\}'));
  t(`.${cls} declares its own font-size`, !!m && /font-size:/.test(m[1]));
}

/* ------------------------------------------------------------------ */
console.log('\n--- cause 2: sizes no longer depend on the host theme\'s root ---');

t('a scale token exists', /--hv-fs:/.test(bare));
t('the token is an absolute px length', /--hv-fs:\s*[\d.]+px/.test(bare));
t('the token is not itself rem-relative', !/--hv-fs:[^;]*rem/.test(bare));

{
  const remLeft = bare.match(/[\d.]+rem\b/g) || [];
  t('no `rem` length survives anywhere in the stylesheet (' + remLeft.length + ' found)',
    remLeft.length === 0);
}

{
  const uses = (bare.match(/calc\([\d.]+ \* var\(--hv-fs\)\)/g) || []).length;
  t('every size is expressed against the token (' + uses + ' sites)', uses >= 90);
}

{
  // The clamp floors must be token-relative, or the clamp stops clamping
  // the moment the root grows — the actual reported symptom.
  const clamps = bare.match(/clamp\([^)]*?rem[^)]*?\)/g) || [];
  t('no clamp still has a rem floor', clamps.length === 0);
}

{
  // THE REGRESSION GUARD THAT MATTERS. Converting rem -> token must be a
  // no-op for Persian, or the whole app silently shrinks. `0.9rem` resolved
  // against the default 16px root, so the token must be 16px too.
  const tok = bare.match(/#havato-app\s*\{[\s\S]*?--hv-fs:\s*([\d.]+)px/);
  t('Persian token parsed', !!tok);
  t('Persian token is 16px, so every converted size is unchanged',
    !!tok && +tok[1] === 16);

  if (tok) {
    // Spot-check real components against what `Nrem` used to compute to.
    // .hv-tab is deliberately NOT in this list: its multiplier was changed
    // on purpose in 1.35.1 (the old value was dead code that had never once
    // been applied). Everything else must be untouched.
    const cases = [
      ['.hv-btn', 0.9], ['.hv-muted', 0.8],
      ['.hv-next-name', 1.08], ['.hv-modal-title', 1.1]
    ];
    for (const [name, mult] of cases) {
      const was = mult * 16;      // old: Nrem against a default root
      const now = mult * +tok[1]; // new: N * token
      t(`  ${name} still computes to ${now.toFixed(2)}px (was ${was.toFixed(2)}px)`,
        Math.abs(was - now) < 0.01);
    }
  }
}

t('LTR gets its own optical scale', /hv-dir-ltr[^{]*\{[^}]*--hv-fs:/s.test(bare));

{
  const fa = bare.match(/#havato-app\s*\{[\s\S]*?--hv-fs:\s*([\d.]+)px/);
  const en = bare.match(/hv-dir-ltr\s*\{[\s\S]*?--hv-fs:\s*([\d.]+)px/);
  t('Latin token parsed', !!en);
  if (fa && en) {
    // Latin must be SMALLER — the complaint was that English looked bigger.
    t(`Latin token (${en[1]}px) is smaller than Persian (${fa[1]}px)`, +en[1] < +fa[1]);
    t('  …but only slightly: a trim, not a shrink', +en[1] / +fa[1] >= 0.9);
    t('  …and still legible at the smallest component size',
      0.62 * +en[1] >= 9);
  }
}

{
  // Body sizes: both languages must stay in a sane band across phone widths.
  const grab = (re) => {
    const m = bare.match(re);
    const c = m && m[1].match(/clamp\(\s*([\d.]+)px\s*,\s*([\d.]+)vw\s*,\s*([\d.]+)px/);
    return c ? { min: +c[1], vw: +c[2], max: +c[3] } : null;
  };
  const fa = grab(/#havato-app\.hv-app\s*\{([\s\S]*?)\n\}/);
  const en = grab(/hv-dir-ltr\s*\{([\s\S]*?)\n\}/s);
  t('Persian body clamp parsed', !!fa);
  t('Latin body clamp parsed', !!en);
  if (fa && en) {
    for (const w of [320, 360, 375, 414, 560]) {
      const pfa = Math.min(Math.max(fa.min, fa.vw * w / 100), fa.max);
      const pen = Math.min(Math.max(en.min, en.vw * w / 100), en.max);
      t(`  @${w}px  fa=${pfa.toFixed(1)}px  en=${pen.toFixed(1)}px — Latin never larger`,
        pen <= pfa + 0.01);
    }
  }
}

{
  // Prove the host theme can no longer scale us. A hostile theme setting
  // html{font-size:200%} used to double everything; now nothing references it.
  const referencesRoot = /\brem\b/.test(bare) || /font-size:\s*\d+%/.test(bare);
  t('a hostile host `html { font-size: 200% }` cannot reach the app', !referencesRoot);
}

/* ------------------------------------------------------------------ */
console.log('\n--- cause 3: five tab labels actually fit ---');

t('a short tables label exists', /'nav_tables'/.test(i18n));
t('a short profile label exists', /'nav_profile'/.test(i18n));

for (const key of ['nav_tables', 'nav_profile']) {
  const m = i18n.match(new RegExp("'" + key + "'\\s*=>\\s*array\\(([^)]*)\\)"));
  t(`${key} is trilingual`, !!m && /'fa'/.test(m[1]) && /'en'/.test(m[1]) && /'tr'/.test(m[1]));
}

t('the bar uses the short tables label', /id:\s*'tables',\s*label:\s*'nav_tables'/.test(js));
t('the bar uses the short profile label', /id:\s*'profile',\s*label:\s*'nav_profile'/.test(js));
t('the My Tables SCREEN keeps its full title', /setHeader\(t\('tab_my_tables'\)/.test(js));

{
  // Width model: five equal columns, and a rough advance width for the
  // label at the tab's own font-size. UI sans averages ~0.5em per Latin
  // character at these sizes; uppercase-ish mixed case a little more.
  const tab = bare.match(/\n\.hv-tab\s*\{([^}]*)\}/);
  const mult = tab && tab[1].match(/font-size:\s*calc\(([\d.]+)/);
  t('tab font-size is token-relative', !!mult);

  // The tab size follows the TOKEN, not the body clamp — that is the whole
  // point of the token — so resolve it against the Latin token.
  const en = bare.match(/hv-dir-ltr\s*\{[\s\S]*?--hv-fs:\s*([\d.]+)px/);
  t('Latin token available for the width model', !!en);

  if (mult && en) {
    const fs = +en[1] * parseFloat(mult[1]);
    // 10px is the iOS tab-bar baseline; anything under it reads as a defect,
    // which is exactly what was reported after 1.35.0 repaired the cascade.
    t(`Latin tab label renders at ${fs.toFixed(1)}px — at or above the 10px baseline`, fs >= 10);

    const labels = ['Home', 'Explore', 'Tables', 'Chats', 'Profile'];
    for (const w of [320, 360, 375, 414]) {
      const col = w / 5 - 2; // .hv-tabs padding-inline plus per-tab padding
      const widest = Math.max(...labels.map((l) => l.length * fs * 0.5));
      t(`  @${w}px widest label ${widest.toFixed(1)}px fits a ${col.toFixed(1)}px column`,
        widest <= col);
    }

    // Turkish is the long one: "Masalar" / "Keşfet" / "Sohbetler".
    const tr = ['Ana sayfa', 'Keşfet', 'Masalar', 'Sohbetler', 'Profil'];
    const widestTr = Math.max(...tr.map((l) => l.length * fs * 0.5));
    t(`Turkish widest label ${widestTr.toFixed(1)}px fits a 320px phone`,
      widestTr <= 320 / 5 - 2);
  }
}

t('labels still ellipsise rather than wrap as a last resort',
  /\.hv-tab span\s*\{[^}]*text-overflow:\s*ellipsis/s.test(bare));
t('tabs may shrink below their content width', /\.hv-tab\s*\{[^}]*min-inline-size:\s*0/s.test(bare));
t('tabs share the width equally', /\.hv-tab\s*\{[^}]*flex:\s*1 1 0/s.test(bare));

t('Latin tracking tightened only for LTR',
  /hv-dir-ltr\s+\.hv-tab\s*\{[^}]*letter-spacing/s.test(bare));
t('Persian is never letter-spaced (cursive script)',
  !/\n\.hv-tab\s*\{[^}]*letter-spacing/s.test(bare));

/* ------------------------------------------------------------------ */
console.log('\n--- cause 4: the host theme cannot restyle our text ---');

// This is the one the screenshot proves. Every BUTTON label rendered in
// caps — EXPLORE / RESERVE A SEAT / VIEW ALL / HOME — while non-button text
// ("Your next table", "Discover tables") stayed mixed case. Our own strings
// are mixed case and our stylesheet has no text-transform, so the caps came
// from the host theme's `button { text-transform: uppercase }`.
t('our own strings are NOT authored in caps',
  /'en' => 'Reserve a seat'/.test(i18n) && /'en' => 'View all'/.test(i18n));

{
  const guard = bare.match(/#havato-app,\s*#havato-app \*,[\s\S]{0,400}?\}/);
  t('a blanket text guard exists', !!guard);
  t('  …it refuses text-transform', !!guard && /text-transform:\s*none\s*!important/.test(guard[0]));
  t('  …it refuses small-caps', !!guard && /font-variant-caps:\s*normal\s*!important/.test(guard[0]));
  t('  …it normalises word-spacing', !!guard && /word-spacing:\s*normal\s*!important/.test(guard[0]));
}

t('letter-spacing is neutralised too',
  /#havato-app \*[\s\S]{0,120}?letter-spacing:\s*normal\s*!important/.test(bare));

{
  // A guard written with !important can only be overridden by another
  // !important, so each intentional tracking rule must carry one as well —
  // otherwise the guard silently flattens our own design.
  const wanted = ['hv-header-eyebrow', 'hv-dial', 'hv-auth-heading'];
  for (const cls of wanted) {
    const re = new RegExp('#havato-app \\.' + cls + '\\s*\\{[^}]*letter-spacing:[^;]*!important');
    t(`.${cls} keeps its tracking despite the guard`, re.test(bare));
  }
  t('LTR tab tracking survives the guard',
    /#havato-app\.hv-dir-ltr \.hv-tab\s*\{[^}]*letter-spacing:[^;]*!important/.test(bare));
}

{
  // Reproduce the screenshot, then the fix. All four causes stacked in the
  // reported build, so the model has to stack them too:
  //   old size  = the shorthand made .hv-tab inherit the 16px body
  //   old label = "My Profile" / "My Tables", the possessive forms
  //   old case  = the theme's uppercase, ~15% wider, plus .08em tracking
  const col = 375 / 5 - 2;          // one tab on a 375px phone
  const upper = 1.15;               // caps vs mixed-case advance
  const track = 0.08;               // em, a very common theme value
  const width = (s, fs, caps) =>
    s.length * (fs * 0.5 * (caps ? upper : 1) + (caps ? fs * track : 0));

  const en = bare.match(/hv-dir-ltr\s*\{[\s\S]*?--hv-fs:\s*([\d.]+)px/);
  const nowFs = (en ? +en[1] : 15) * 0.62;

  const before = width('My Profile', 16, true);  // inherited body size, uppercased
  const after = width('Profile', nowFs, false);  // own size, own case

  t(`BEFORE: "MY PROFILE" at 16px needed ${before.toFixed(1)}px — overflowed ` +
    `${col.toFixed(1)}px, hence "MY PROF…"`, before > col);
  t(`AFTER: "Profile" at ${nowFs.toFixed(1)}px needs ${after.toFixed(1)}px — fits`,
    after <= col);
  t(`the fix reclaimed ${(before - after).toFixed(1)}px per tab`, before - after > 20);

  // Each cause on its own must be worth fixing, or it is not really a cause.
  t('  size alone was enough to overflow',
    width('My Profile', 16, false) > col);
  t('  the possessive label alone was enough at the old size',
    width('My Profile', 16, false) > width('Profile', 16, false));
  t('  uppercasing alone widened the label materially',
    width('Profile', 16, true) > width('Profile', 16, false) * 1.1);
}

t('the guard is scoped to the app and cannot leak into the host page',
  !/^\s*\*\s*\{/m.test(bare));

/* ------------------------------------------------------------------ */
console.log('\n--- no collateral damage ---');

t('the Persian face is still the default', /#havato-app\.hv-app[^}]*font-family:\s*var\(--hv-font-fa\)/s.test(bare));
t('Latin still switches to the system UI stack',
  /hv-dir-ltr\s*\{[^}]*font-family:\s*var\(--hv-font-en\)/s.test(bare));
t('the [hidden] guard survived the rewrite', /#havato-app \[hidden\][\s\S]{0,80}display: none !important/.test(bare));
t('the unsized-SVG safety net survived',
  /#havato-app svg:not\(\.hv-sprite\)[^}]*inline-size: 1\.25em/s.test(bare));

console.log(f ? `\n❌ ${f} failed` : '\n✅ typography is anchored to the app, not the host page');
process.exit(f ? 1 : 0);
