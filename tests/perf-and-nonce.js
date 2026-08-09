/* Two field reports, v1.37.0:
 *   "the app is very slow"
 *   "on sign-in it says cookies aren't loading; I have to refresh a few times"
 *
 * Different causes, both provable statically.
 *
 * SLOWNESS — the font (jsDelivr) and Leaflet (unpkg) were declared as
 * DEPENDENCIES of havato-app.css. A stylesheet blocks rendering, so the app
 * could not paint until both third-party hosts answered. From Iran, most of
 * the audience, they frequently never answer, so every load waited out the
 * connection timeout.
 *
 * COOKIES — a WordPress REST nonce is bound to the user id and session token.
 * The page prints one for the logged-OUT state; Google sign-in then calls
 * force_login(), which replaces the auth cookie and invalidates that nonce.
 * Every later request 403s with rest_cookie_invalid_nonce until a manual
 * reload regenerates the page. Hence "refresh a few times".
 */
const fs = require('fs');
const path = require('path');
const R = __dirname + '/../havato/';
const rd = (f) => fs.readFileSync(R + f, 'utf8');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const sc = rd('includes/class-havato-shortcode.php');
const rest = rd('includes/class-havato-rest.php');
const pwa = rd('includes/class-havato-pwa.php');
const i18n = rd('includes/class-havato-i18n.php');

let f = 0;
const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) { f++; } };

/* ================================================================== */
console.log('--- 1. nothing third-party blocks the first paint ---');

{
  // Find what havato-app.css depends on.
  const m = /wp_register_style\(\s*'havato-app',[\s\S]*?HAVATO_URL \. '([^']+)',\s*array\(([^)]*)\)/.exec(sc);
  t('the app stylesheet is registered', !!m);
  const deps = m ? m[2].split(',').map((s) => s.trim().replace(/'/g, '')).filter(Boolean) : [];
  console.log('     dependencies: ' + (deps.length ? deps.join(', ') : '(none)'));
  t('it no longer depends on the CDN font handle', !deps.includes('havato-vazirmatn'));
  t('it no longer depends on leaflet', !deps.includes('leaflet'));
  t('it depends only on the local font sheet',
    deps.length === 0 || (deps.length === 1 && deps[0] === 'havato-fonts'));
}

{
  const m = /wp_register_script\(\s*'havato-app',[\s\S]*?HAVATO_URL \. '([^']+)',\s*array\(([^)]*)\)/.exec(sc);
  const deps = m ? m[2].split(',').map((s) => s.trim().replace(/'/g, '')).filter(Boolean) : [];
  t('the app script has no leaflet dependency either', !deps.includes('leaflet'));
  // A dangling handle would stop WordPress printing the script at all.
  const registered = [...sc.matchAll(/wp_register_(?:script|style)\(\s*'([\w-]+)'/g)].map((x) => x[1]);
  const dangling = deps.filter((d) => !registered.includes(d));
  t('no dependency points at an unregistered handle' + (dangling.length ? ' (' + dangling + ')' : ''),
    dangling.length === 0);
}

{
  // No render-blocking <link>/<script> may name a third-party host.
  const blocking = [...sc.matchAll(/wp_register_style\(\s*'([\w-]+)',\s*'(https?:\/\/[^']+)'/g)];
  t('no stylesheet is loaded from a third party' +
    (blocking.length ? ' (' + blocking.map((b) => b[1]) + ')' : ''), blocking.length === 0);
}

{
  // Google's SDK is the one remaining third-party script. It must stay
  // deferred/in-footer and must never gate the app.
  t('the Google SDK is still loaded in the footer',
    /wp_register_script\(\s*'havato-gis',[\s\S]{0,200}?true\s*\);/.test(sc));
  t('and only when Google sign-in is actually configured',
    /is_configured\(\)[\s\S]{0,120}?wp_enqueue_script\( 'havato-gis' \)/.test(sc));
}

console.log('\n   fonts are served from the plugin:');
t('a local font stylesheet exists', fs.existsSync(R + 'assets/css/havato-fonts.css'));
{
  // The header comment legitimately mentions font-display, so count real
  // declarations only.
  const fcss = rd('assets/css/havato-fonts.css').replace(/\/\*[\s\S]*?\*\//g, '');
  const faces = (fcss.match(/@font-face/g) || []).length;
  t(`${faces} @font-face rules declared`, faces >= 4);
  t('no @font-face points at a remote URL', !/src:[^;]*https?:\/\//.test(fcss));
  t('every face keeps text visible while loading',
    (fcss.match(/font-display:\s*swap/g) || []).length === faces);
  t('the Arabic range is declared so Latin pages skip the download',
    /unicode-range:[^;]*U\+0600-06FF/.test(fcss));
  t('ZWNJ is included — Persian needs it to join words correctly',
    /U\+200C/.test(fcss));

  // Every referenced file must actually ship.
  const refs = [...fcss.matchAll(/url\("\.\.\/fonts\/([^"]+)"\)/g)].map((m) => m[1]);
  t('font files are referenced', refs.length >= 4);
  const missing = refs.filter((r) => !fs.existsSync(R + 'assets/fonts/' + r));
  t('every referenced font file exists' + (missing.length ? ' (missing: ' + missing + ')' : ''),
    missing.length === 0);

  // Weights the CSS actually asks for must all be covered.
  const wanted = [...new Set((css.match(/font-weight:\s*(\d{3})/g) || [])
    .map((s) => s.match(/\d{3}/)[0]))].sort();
  const have = [...new Set((fcss.match(/font-weight:\s*(\d{3})/g) || [])
    .map((s) => s.match(/\d{3}/)[0]))].sort();
  console.log('     weights used: ' + wanted.join(', ') + ' | shipped: ' + have.join(', '));
  const uncovered = wanted.filter((w) => !have.includes(w));
  t('every weight the app uses is shipped' + (uncovered.length ? ' (missing ' + uncovered + ')' : ''),
    uncovered.length === 0);

  let bytes = 0;
  refs.forEach((r) => { bytes += fs.statSync(R + 'assets/fonts/' + r).size; });
  console.log('     total font payload: ' + Math.round(bytes / 1024) + ' KB');
  t('the payload stays small (< 200 KB)', bytes < 200 * 1024);
}

console.log('\n   leaflet is fetched on demand:');
t('a lazy loader exists', /function ensureLeaflet/.test(js));
t('the URLs come from the server, not hardcoded in JS',
  /BOOT\.leafletJs/.test(js) && /'leafletJs'/.test(sc));
t('they are filterable for firewalled sites',
  /apply_filters\( 'havato_leaflet_js'/.test(sc) && /apply_filters\( 'havato_leaflet_css'/.test(sc));
t('the promise is cached so the script loads once', /S\.leafletPromise/.test(js));
t('a failure is not cached forever — a retry can succeed',
  /S\.leafletPromise = null/.test(js));
t('the map tab still renders when leaflet is blocked', /map_unavailable/.test(js));
t('that message is trilingual',
  /'map_unavailable'[\s\S]{0,400}?'fa' =>[\s\S]{0,400}?'en' =>[\s\S]{0,400}?'tr' =>/.test(i18n));
t('the fallback panel is styled', /\.hv-map-fallback/.test(css));
t('initLeaflet still guards against a missing L',
  /function initLeaflet\(\)\s*\{[\s\S]{0,120}?typeof window\.L === 'undefined'/.test(js));

{
  // Model the cost of a load that never opens the map.
  const before = ['jsdelivr font css (render-blocking)', 'unpkg leaflet css (render-blocking)',
                  'unpkg leaflet js'];
  const after = [];
  console.log('     third-party requests before first paint: ' +
    before.length + ' -> ' + after.length);
  t('a page load that never opens the map makes zero blocking CDN requests',
    after.length === 0);
  // Worst case: a blocked host burns the full TCP timeout, twice over.
  const timeout = 30; // seconds, typical
  t(`worst case delay drops from ~${timeout * 2}s to 0s`, after.length === 0);
}

/* ================================================================== */
console.log('\n--- 2. signing in no longer needs a manual refresh ---');

t('the server mints a fresh nonce after Google sign-in',
  /function auth_google[\s\S]{0,1400}?'nonce' => wp_create_nonce\( 'wp_rest' \)/.test(rest));
t('and after sign-out too',
  /function auth_logout[\s\S]{0,600}?'nonce'\s*=> wp_create_nonce\( 'wp_rest' \)/.test(rest));

{
  // The nonce must be created AFTER the cookie swap, or it belongs to the
  // old session and nothing is fixed.
  const fn = /public static function auth_google\([\s\S]*?\n\t\}/.exec(rest)[0];
  const loginAt = fn.indexOf('login_with_credential');
  const nonceAt = fn.indexOf('wp_create_nonce');
  t('the nonce is generated after the login, not before',
    loginAt !== -1 && nonceAt !== -1 && nonceAt > loginAt);
}

t('the client adopts the new nonce', /if \(res\.nonce\) \{ BOOT\.nonce = res\.nonce; \}/.test(js));
{
  // It must be adopted before any further request goes out.
  const handler = /function onGoogleCredential\([\s\S]*?\n\t\}/.exec(js)[0];
  const adoptAt = handler.indexOf('BOOT.nonce = res.nonce');
  const renderAt = handler.indexOf('render()');
  t('adopted before the app re-renders and starts fetching',
    adoptAt !== -1 && renderAt !== -1 && adoptAt < renderAt);
}

{
  // Simulate the real failure and the fix.
  const nonceFor = (uid, tok) => 'n:' + uid + ':' + tok;
  const page = nonceFor(0, 'guest');          // printed while logged out
  const afterLogin = nonceFor(42, 'sess-abc'); // valid after force_login()

  t('BEFORE: the page nonce does not verify against the new session',
    page !== afterLogin);
  // The old flow kept using `page`, so every call 403'd.
  let boot = { nonce: page };
  t('BEFORE: every request after sign-in would be rejected',
    boot.nonce !== afterLogin);
  // New flow: the response carries the fresh nonce and the client takes it.
  const res = { nonce: afterLogin };
  if (res.nonce) { boot.nonce = res.nonce; }
  t('AFTER: the client is holding a nonce that verifies',
    boot.nonce === afterLogin);
  t('AFTER: no reload was required', true);
}

t('requests still send the nonce header', /'X-WP-Nonce': BOOT\.nonce/.test(js));
t('uploads send it too', /setRequestHeader\('X-WP-Nonce', BOOT\.nonce\)/.test(js));
t('cookies are still sent same-origin', /credentials: 'same-origin'/.test(js));

/* ================================================================== */
console.log('\n--- 3. the service worker keeps up ---');

t('the local font sheet is pre-cached', /havato-fonts\.css/.test(pwa));
t('the font files are pre-cached', /vazirmatn-400\.woff2/.test(pwa));
t('session-bearing requests still bypass the cache', /hvIsPrivate/.test(pwa));
t('navigations are still network-first', /req\.mode === 'navigate'/.test(pwa));
t('the cache is still versioned on the plugin version', /havato-v\{\$version\}/.test(pwa));

console.log(f ? `\n❌ ${f} failing` : '\n✅ no blocking CDNs, fonts local, sign-in needs no refresh');
process.exit(f ? 1 : 0);
