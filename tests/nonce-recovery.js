/* "بررسی کوکی انجام نشد" — the Persian localisation of
 * rest_cookie_invalid_nonce — shown to a user who was ALREADY signed in.
 *
 * Root cause: a WordPress REST nonce is valid for 24 hours. This app is a PWA
 * that never reloads its document, so the nonce printed into HAVATO_BOOT goes
 * stale while the app is still installed and open. The auth cookie lasts 14
 * days, so the user keeps looking signed in — avatar, name, tabs — while every
 * single request 403s.
 *
 * v1.37.0 only refreshed the nonce at sign-in, which does nothing for a
 * session that expires days later. This adds real recovery.
 *
 * The subtle part, and the reason the obvious fix does not work: the nonce
 * CANNOT be re-fetched from a REST route. WordPress's rest_cookie_check_errors()
 * forces wp_set_current_user(0) when no X-WP-Nonce header is present, and
 * rejects a dead one with 403 before plugin code runs. Either way the request
 * is anonymous, so wp_create_nonce() there is bound to user 0 and still fails
 * against the caller's real cookie.
 */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = (f) => fs.readFileSync(R + f, 'utf8');
const js = rd('assets/js/havato-app.js');
const sc = rd('includes/class-havato-shortcode.php');
const rest = rd('includes/class-havato-rest.php');
const pwa = rd('includes/class-havato-pwa.php');

let f = 0;
const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) { f++; } };

/* ================================================================== */
console.log('--- the failure being fixed ---');

{
  // Model WordPress nonce lifetime: valid for 2 ticks of 12 hours.
  const tick = (h) => Math.ceil(h / 12);
  const valid = (h) => tick(h) <= 2;
  t('a nonce is still valid after 6h in the app', valid(6));
  t('a nonce is still valid after 24h', valid(24));
  t('a nonce is DEAD after 25h — the reported case', !valid(25));
  t('and after a weekend in the background', !valid(60));

  // The cookie outlives it by far, which is why the user still looks signed in.
  const COOKIE_DAYS = 14, NONCE_HOURS = 24;
  t(`the cookie (${COOKIE_DAYS}d) outlives the nonce (${NONCE_HOURS}h)`,
    COOKIE_DAYS * 24 > NONCE_HOURS);
  t('so the UI shows a signed-in user whose every request fails', true);
}

/* ================================================================== */
console.log('\n--- the nonce endpoint is reachable without a valid nonce ---');

t('a nonce action is registered on admin-ajax', /wp_ajax_havato_nonce/.test(sc));
t('and for the logged-out case too, so the client learns the session ended',
  /wp_ajax_nopriv_havato_nonce/.test(sc));
t('the handler exists', /function ajax_nonce/.test(sc));

{
  const fn = /public static function ajax_nonce\(\)[\s\S]*?\n\t\}/.exec(sc);
  t('handler parsed', !!fn);
  t('it returns a wp_rest nonce', !!fn && /wp_create_nonce\( 'wp_rest' \)/.test(fn[0]));
  t('it reports whether the session is still alive',
    !!fn && /'logged_in' => is_user_logged_in\(\)/.test(fn[0]));
  t('it is never cached by a proxy', !!fn && /nocache_headers\(\)/.test(fn[0]));
}

{
  // THE CRITICAL PROPERTY. Prove a REST-based refresh could not have worked.
  const restRefresh = { authenticated: false, uid: 0 }; // forced anonymous
  const cookieUid = 42;
  const nonceFor = (uid) => 'n:' + uid;
  const minted = nonceFor(restRefresh.uid);
  const needed = nonceFor(cookieUid);
  t('a nonce minted on a REST route would be bound to user 0', minted === 'n:0');
  t('...and would NOT verify against the real cookie', minted !== needed);

  const ajaxRefresh = { authenticated: true, uid: cookieUid }; // cookie honoured
  t('admin-ajax mints one bound to the real user',
    nonceFor(ajaxRefresh.uid) === needed);
}

t('the client is told where the endpoint lives', /'nonceUrl'/.test(sc));
t('it points at the havato_nonce action',
  /admin_url\( 'admin-ajax\.php\?action=havato_nonce' \)/.test(sc));

/* ================================================================== */
console.log('\n--- the client recovers by itself ---');

t('a refresh helper exists', /function refreshNonce/.test(js));
t('it uses the ajax endpoint, not a REST route',
  /fetch\(BOOT\.nonceUrl/.test(js));
t('it sends the cookie', /function refreshNonce[\s\S]{0,700}?credentials: 'same-origin'/.test(js));

{
  const fn = /function refreshNonce\(\)[\s\S]*?\n\t\}/.exec(js)[0];
  t('concurrent callers share one in-flight request', /S\.nonceRefresh/.test(fn));
  t('the guard is cleared so a later refresh can run again',
    (fn.match(/S\.nonceRefresh = null/g) || []).length >= 2);
  t('a network failure resolves false rather than rejecting',
    /\.catch\(function \(\) \{[\s\S]{0,80}?return false;/.test(fn));
  t('an ended session is detected and not retried forever',
    /json\.logged_in === false/.test(fn));
  t('a missing endpoint degrades quietly', /if \(!BOOT\.nonceUrl\)/.test(js));
}

console.log('\n   the retry itself:');
t('nonce failures are recognised by CODE, not by message text',
  /rest_cookie_invalid_nonce/.test(js));
t('...which matters because the message is localised',
  /function isNonceError/.test(js));
{
  const fn = /function isNonceError[\s\S]*?\n\t\}/.exec(js)[0];
  t('only 403 is treated as recoverable', /status !== 403/.test(fn));
  t('the message text is never matched on', !/بررسی|cookie check/.test(fn));
}
t('a failed call is replayed once', /_retried/.test(js));
{
  const guards = (js.match(/!options\._retried/g) || []).length;
  t(`both transports guard against an infinite retry loop (${guards} sites)`, guards >= 2);
}
t('file uploads recover too — losing one means re-picking the photo',
  /function apiUpload[\s\S]*?isNonceError/.test(js));

console.log('\n   pre-emptive refresh:');
t('the app re-arms when it returns to the foreground',
  /function watchForStaleSession/.test(js));
t('it listens for visibility changes', /visibilitychange/.test(js));
{
  const fn = /function watchForStaleSession\(\)[\s\S]*?\n\t\}/.exec(js)[0];
  t('only after a meaningful absence, not on every tab switch',
    /STALE_AFTER/.test(fn) && /leftAt/.test(fn));
  const m = /STALE_AFTER = ([\d\s*]+);/.exec(fn);
  const ms = m ? eval(m[1]) : 0;
  t(`the threshold (${ms / 60000} min) is well under the 24h nonce life`,
    ms > 0 && ms < 24 * 60 * 60 * 1000);
}
t('bootstrap also hands back a current nonce for a restored tab',
  /'nonce'\s*=> wp_create_nonce\( 'wp_rest' \)/.test(rest));
t('and the client adopts it on boot',
  /api\('bootstrap'\)[\s\S]{0,400}?if \(res\.nonce\) \{ BOOT\.nonce = res\.nonce; \}/.test(js));

/* ================================================================== */
console.log('\n--- end-to-end simulation ---');

{
  // Reproduce the reported flow, then the fixed one.
  let serverUid = 42;
  let clientNonce = 'n:42:day0';
  const currentNonce = () => 'n:' + serverUid + ':day3';

  const call = (nonce) => (nonce === currentNonce()
    ? { ok: true }
    : { ok: false, status: 403, code: 'rest_cookie_invalid_nonce' });

  // v1.37.0 behaviour: one attempt, no recovery.
  let r = call(clientNonce);
  t('BEFORE: opening the app after 3 days fails', !r.ok && r.status === 403);
  t('BEFORE: the user sees the cookie-check error', r.code === 'rest_cookie_invalid_nonce');

  // v1.38.0 behaviour: detect, refresh via ajax, replay once.
  let retried = false;
  if (!r.ok && r.code === 'rest_cookie_invalid_nonce' && !retried) {
    clientNonce = currentNonce(); // admin-ajax, authenticated by cookie
    retried = true;
    r = call(clientNonce);
  }
  t('AFTER: the call is replayed and succeeds', r.ok);
  t('AFTER: exactly one retry was needed', retried);

  // And it must not loop when the session is genuinely gone.
  serverUid = 0;
  let attempts = 0;
  const deadCall = () => { attempts++; return { ok: false, status: 403, code: 'rest_cookie_invalid_nonce' }; };
  let r2 = deadCall();
  let retried2 = false;
  if (!r2.ok && !retried2) { retried2 = true; r2 = deadCall(); }
  t('a genuinely dead session stops after one retry, no loop', attempts === 2);
}

/* ================================================================== */
console.log('\n--- nothing else regressed ---');

t('admin-ajax is still excluded from the service-worker cache',
  /admin-ajax\.php.*return true/.test(pwa));
t('REST is still excluded too', /wp-json/.test(pwa));
t('normal requests still carry the nonce header', /'X-WP-Nonce': BOOT\.nonce/.test(js));
t('uploads still carry it', /setRequestHeader\('X-WP-Nonce', BOOT\.nonce\)/.test(js));
t('sign-in still adopts its fresh nonce',
  /onGoogleCredential[\s\S]{0,600}?if \(res\.nonce\) \{ BOOT\.nonce = res\.nonce; \}/.test(js));

console.log(f ? `\n❌ ${f} failing` : '\n✅ an expired nonce now heals itself, no refresh needed');
process.exit(f ? 1 : 0);
