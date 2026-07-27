/* v1.9.1 —
   1) the café-owner button is gone from the guest auth wall
   2) signing out really ends the session (no stale cache, real navigation)
   3) no text on a dark surface relies on inheritance alone            */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const pwa = rd('includes/class-havato-pwa.php');
const sc = rd('includes/class-havato-shortcode.php');
const rest = rd('includes/class-havato-rest.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

console.log('--- 1. owner button removed from the landing screen ---');
t('no owner link in the auth wall markup', !/ownerPanelUrl/.test(js));
t('login_owner string no longer rendered', !/t\('login_owner'\)/.test(js));
t('boot payload no longer ships the URL', !/'ownerPanelUrl'/.test(sc));
t('orphaned .hv-auth-foot CSS removed', !/hv-auth-foot/.test(css));
t('the Google sign-in block is still there', /hv-google-slot/.test(js));
t('owner portal itself untouched',
  /havato_owner_auth/.test(rd('includes/class-havato-owner-auth.php')));

console.log('\n--- 2. logout actually logs out ---');
t('a dedicated doLogout() exists', /function doLogout\s*\(/.test(js));
t('button no longer just re-renders in place',
  !/api\('auth\/logout'[\s\S]{0,220}render\(\);\s*\}\);/.test(js));
t('Google auto-select disabled first', /disableAutoSelect\(\)/.test(js));
t('caches wiped on the way out', /function clearAppCaches/.test(js) && /caches\.delete/.test(js));
t('service worker told to purge', /havato-logout/.test(js));
t('a real top-level navigation happens', /window\.location\.replace/.test(js));
t('falls back to wp_logout_url when REST fails', /BOOT\.logoutUrl/.test(js));
t('server exposes a nonced logout URL', /'logoutUrl'\s*=>\s*esc_url_raw\(\s*wp_logout_url/.test(sc));
t('REST logout still calls wp_logout()', /wp_logout\(\)/.test(rest));

console.log('\n--- 3. service worker can no longer serve a signed-in page ---');
t('plain-permalink REST form excluded', /rest_route/.test(pwa));
t('pretty-permalink REST form excluded', /wp-json/.test(pwa));
t('wp-admin excluded', /wp-admin/.test(pwa));
t('wp-login excluded', /wp-login\.php/.test(pwa));
t('navigations are network-first', /req\.mode === 'navigate'/.test(pwa));
t('HTML is never written to the cache',
  /never written to the cache|caching it/i.test(pwa));
t('only plugin assets are cached', /HV_ASSET_SCOPE/.test(pwa));
t('cross-origin requests pass through', /url\.origin !== self\.location\.origin/.test(pwa));
t('worker listens for the logout purge', /'havato-logout'/.test(pwa));
t('pre-cache uses the real ?ver= URLs', /add_query_arg\(\s*'ver'/.test(pwa));

console.log('\n--- 4. no dark-surface text left to inheritance ---');
// Every one of these sits on a saturated background and was rendering
// near-black wherever the active theme styled the bare tag.
const mustHaveColour = [
  '.hv-profile-name', '.hv-profile-meta', '.hv-header-eyebrow',
  '.hv-auth-title', '.hv-auth-sub', '.hv-msg-time', '.hv-modal-title'
];
// crude rule parser: selector -> body
const rules = [];
const re = /([^{}]+)\{([^{}]*)\}/g; let m;
while ((m = re.exec(css))) {
  rules.push({
    sel: m[1].replace(/\/\*[\s\S]*?\*\//g, '').trim().replace(/\s+/g, ' '),
    body: m[2]
  });
}
const declaresColour = new Set();
rules.filter(r => /(^|[;\s])color\s*:/.test(r.body))
  .forEach(r => r.sel.split(',').forEach(s => declaresColour.add(s.trim())));

for (const c of mustHaveColour) {
  t(`${c} sets its own colour`, declaresColour.has(c));
}
t('a blanket dark-surface guard exists', /DARK-SURFACE TEXT GUARD/.test(css));
t('the guard covers the reported profile card',
  /#havato-app \.hv-profile-head/.test(css));
t('badges/buttons opt out of the guard', /:not\(\.hv-badge\)/.test(css));
t('secondary text uses translucent white, not opacity',
  /rgba\(255, 255, 255, 0\.88\)/.test(css));
t('profile meta no longer dimmed with opacity',
  !/\.hv-profile-meta \{[^}]*opacity/.test(css));

console.log(f ? `\n❌ ${f} failing` : '\n✅ owner button gone, logout is real, dark text fixed');
process.exit(f ? 1 : 0);
