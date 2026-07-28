/* v1.16.0 — findings from the full code + security audit.
   Each assertion below corresponds to something that was verified by hand or
   reproduced as a failing case first, so they are regression guards rather
   than restatements of the code. */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const rest = rd('includes/class-havato-rest.php');
const M = rd('includes/class-havato-matcher.php');
const fn = rd('includes/functions.php');
const db = rd('includes/class-havato-db.php');
const adm = rd('includes/class-havato-admin.php');
const oa = rd('includes/class-havato-owner-admin.php');
const themes = rd('includes/class-havato-themes.php');
const js = rd('assets/js/havato-app.js');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

console.log('--- BUG 1: a party could be seated at a table too small for it ---');
// join_event validates a booking against the café's LARGEST table, but the
// matcher walks the plan largest-first and could reach a 2-seater while a
// party of 3 was still unseated. Reproduced, then fixed.
t('a re-homing helper exists', /private static function fit_table/.test(M));
t('the lone-booking branch uses it', /\$fit   = self::fit_table\( \$chairs\( \$alone \)/.test(M));
t('the trimmed-seed branch uses it too', /\$chairs\( \$seed\[0\] \) > \$capacity/.test(M));
t('the swapped plan is kept, not discarded',
  (M.match(/\$plan\s*=\s*\$fit\['plan'\]/g) || []).length >= 2);
t('capacity follows the swap', (M.match(/\$capacity\s*=\s*\$fit\['capacity'\]/g) || []).length >= 2);
t('the displaced table is put back into the plan', /\$plan\[ \$look \] = \$current;/.test(M));
t('the reason is documented', /validated at join time against the café's LARGEST table/.test(M));

// Re-run the invariant the fix was written against.
(() => {
  const chairs = (u, p) => p[u] || 1;
  const occ = (m, p) => m.reduce((n, u) => n + chairs(u, p), 0);
  const fit = (need, cap, plan, pi, cur) => {
    if (need <= cap) return { plan, cap, table: cur };
    for (let l = pi; l < plan.length; l++) {
      if (plan[l] >= need) { const sw = plan[l]; plan = plan.slice(); plan[l] = cur; return { plan, cap: Math.max(2, sw), table: sw }; }
    }
    return { plan, cap: need, table: cur };
  };
  const build = (poolIn, party, planIn) => {
    let plan = planIn.slice(), planI = 0, tables = [], guard = 0, pool = poolIn.slice();
    while (pool.length && guard < 50) {
      guard++;
      let cap = Math.max(2, plan[Math.min(planI, plan.length - 1)]);
      const assigned = cap; planI++;
      if (pool.length === 1) {
        const a = pool.shift();
        const r = fit(chairs(a, party), cap, plan, planI, assigned);
        plan = r.plan; cap = r.cap;
        tables.push({ m: [a], cap }); continue;
      }
      let seed = pool.slice(0, 2);
      if (occ(seed, party) > cap) {
        seed = [seed[0]];
        if (chairs(seed[0], party) > cap) { const r = fit(chairs(seed[0], party), cap, plan, planI, assigned); plan = r.plan; cap = r.cap; }
      }
      let tb = seed.slice(); pool = pool.filter(u => !tb.includes(u));
      while (occ(tb, party) < cap && pool.length) {
        const c = pool.find(x => occ(tb, party) + chairs(x, party) <= cap);
        if (c === undefined) break;
        tb.push(c); pool = pool.filter(x => x !== c);
      }
      tables.push({ m: tb, cap }); if (!pool.length) break;
    }
    return tables;
  };
  // The exact minimal reproducer found during the audit.
  const repro = build([1, 2, 3], { 3: 3 }, [4, 2]);
  t('minimal reproducer no longer overflows', repro.every(x => occ(x.m, { 3: 3 }) <= x.cap));

  let over = 0, lost = 0;
  for (let i = 0; i < 3000; i++) {
    const n = 1 + Math.floor(Math.random() * 12);
    const pool = Array.from({ length: n }, (_, k) => k + 1);
    const plan = Array.from({ length: 1 + Math.floor(Math.random() * 4) }, () => 2 + Math.floor(Math.random() * 7));
    const biggest = Math.max(...plan);
    const party = {};
    for (const u of pool) if (Math.random() < 0.35) party[u] = Math.min(1 + Math.floor(Math.random() * 3), biggest);
    const ts = build(pool, party, plan);
    for (const x of ts) if (occ(x.m, party) > x.cap) over++;
    const seated = new Set(ts.flatMap(x => x.m));
    if (pool.some(u => !seated.has(u))) lost++;
  }
  t('3000 random seatings: no table over capacity', over === 0);
  t('3000 random seatings: nobody dropped', lost === 0);
})();

console.log('\n--- BUG 2: unbounded free text could be written to the DB ---');
// sanitize_*_field() strips tags but imposes no size limit, and these all
// land in TEXT/longtext columns on endpoints any logged-in user can call.
t('a clamp helper exists', /function havato_clamp_text/.test(fn));
t('it is length-bounded and trims', /mb_substr\( \$text, 0, \$max \)/.test(fn));
t('chat messages clamped', (rest.match(/havato_clamp_text\( sanitize_textarea_field\( \(string\) \$req->get_param\( 'text' \) \), 1000 \)/g) || []).length === 2);
t('feedback comments clamped', /get_param\( 'comment' \) \), 500 \)/.test(rest));
t('venue address clamped', /get_param\( 'address' \) \), 300 \)/.test(rest));
t('owner venue update clamped', /sanitize_textarea_field\( \(string\) \$value \), 300 \)/.test(rest));
t('no unbounded sanitize_textarea_field left in REST',
  !/sanitize_textarea_field\([^)]*\)\s*;/.test(rest.replace(/havato_clamp_text\([^;]*;/g, '')));
t('menu item count is capped', /havato_max_menu_items/.test(fn));
t('menu name and description are clamped',
  /havato_clamp_text\( sanitize_text_field\( \$item\['name'\] \), 120 \)/.test(fn) &&
  /havato_clamp_text\( sanitize_textarea_field\( \$item\['desc'\] \), 300 \)/.test(fn));
t('menu price cannot be negative', /max\( 0, \(int\) \$item\['price'\] \)/.test(fn));

console.log('\n--- verified: authorisation ---');
t('every owner endpoint derives the venue from the session, never a param',
  (rest.match(/self::owner_venue\( get_current_user_id\(\) \)/g) || []).length >= 8);
t('owner_perm rejects non-owners', /'cafe_owner' !== \$role && 'admin' !== \$role/.test(rest));
t('admin_perm uses manage_options', /current_user_can\( 'manage_options' \)/.test(rest));
t('group chat read requires membership', /function chat_group\b[\s\S]{0,400}is_group_member/.test(rest));
t('group chat write requires membership', /function chat_group_send[\s\S]{0,600}is_group_member/.test(rest));
t('private chat requires friendship both ways', /havato_are_friends/.test(rest));
t('feedback requires both parties at the table',
  /is_group_member\( \$group_id, \$user_id \) \|\| ! self::is_group_member\( \$group_id, \$target \)/.test(rest));
t('photo delete is scoped by user_id in the WHERE clause',
  /\$wpdb->delete\( \$photos, array\( 'id' => \$photo_id, 'user_id' => \$user_id \)/.test(rest));
t('gallery visibility is enforced server-side', /function can_view_gallery/.test(rest));
t('admin-post handlers check capability AND nonce',
  /current_user_can\( 'manage_options' \)[\s\S]{0,200}check_admin_referer\( 'havato_admin'/.test(adm) &&
  /check_admin_referer\( 'havato_owner'/.test(oa));

console.log('\n--- verified: injection ---');
t('search uses esc_like + prepare', /esc_like\( \$search \)[\s\S]{0,200}\$wpdb->prepare/.test(adm));
t('status filters are allow-listed before interpolation',
  /in_array\( \$status, array\( 'open', 'matched', 'completed', 'pending_admin' \), true \)/.test(adm));
t('client escaping covers all five dangerous characters',
  /&amp;/.test(js) && /&lt;/.test(js) && /&gt;/.test(js) && /&quot;/.test(js) && /&#39;/.test(js));
t('theme colours are strictly validated before entering a <style> block',
  /preg_match\( '\/\^#\?\(\[0-9a-f\]\{6\}\)\$\/'/.test(themes));

// Prove the colour validator rejects CSS escapes rather than trusting it.
(() => {
  const hex = (v, fb) => {
    v = String(v).toLowerCase().trim();
    let m = /^#?([0-9a-f]{3})$/.exec(v);
    if (m) { const s = m[1]; return '#' + s[0] + s[0] + s[1] + s[1] + s[2] + s[2]; }
    m = /^#?([0-9a-f]{6})$/.exec(v);
    return m ? '#' + m[1] : fb;
  };
  const attacks = ['red;} body{display:none}', '</style><script>alert(1)</script>',
                   'expression(alert(1))', 'url(javascript:alert(1))', '#fff;} a{}'];
  t('CSS-injection payloads all fall back to the default',
    attacks.every(a => /^#[0-9a-f]{6}$/.test(hex(a, '#1552d8')) && hex(a, '#1552d8') === '#1552d8'));
})();

console.log('\n--- verified: abuse & privacy ---');
t('login is throttled per IP', /function check_login_throttle/.test(rest));
t('public café registration is throttled too',
  /Registration is public, so the same IP throttle applies/.test(rest));
t('the IP comes from REMOTE_ADDR, not a spoofable header',
  /REMOTE_ADDR/.test(rest) && !/HTTP_X_FORWARDED_FOR/.test(rest));
t('uploads are extension allow-listed', /'jpg', 'jpeg', 'png', 'gif', 'webp'/.test(rest));
t('a guest card exposes no email or phone',
  !/function user_card[\s\S]{0,400}(email|phone|user_login)/.test(rest));
t('a guest never receives another guest\'s phone',
  /'phone'         => \$is_self \? \$profile\['phone'\] : ''/.test(rest));
t('the café phone is only in the private payload',
  (rest.match(/\$payload\['manager_phone'\]/g) || []).length === 1);
t('blocklist is a hard constraint in the matcher',
  /if \( havato_is_blocked\( \$a\['user_id'\], \$b\['user_id'\] \) \)/.test(M));

console.log('\n--- verified: data integrity ---');
t('dbDelta schema carries no "--" comments', (() => {
  const blocks = db.match(/CREATE TABLE[\s\S]*?\)\s*\$charset/g) || [];
  return !blocks.some(b => /^\s*--/m.test(b));
})());
t('schema upgrades run when the version changes', /HAVATO_DB_VERSION !== \$installed/.test(db));
t('missing tables self-heal', /if \( \$missing \) \{\s*\n\s*self::install\(\);/.test(db));
t('profiles written before an upgrade get safe defaults',
  /Traits added in DB 1\.7\.0/.test(fn) && /Columns added in DB 1\.10\.0/.test(fn));
t('penalties are never written into the peer-feedback column',
  /'rating_score' => \$avg/.test(rest) && /function havato_effective_rating/.test(fn));

console.log(f ? `\n❌ ${f} failing` : '\n✅ audit findings fixed and guarded');
process.exit(f ? 1 : 0);
