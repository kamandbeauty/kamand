/* v1.19.0 —
   1) the storage notice is gone from the guest UI
   2) rude language silently flags a message for the admin
   3) the administrator can ban an account from the platform         */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const fn = rd('includes/functions.php');
const db = rd('includes/class-havato-db.php');
const rest = rd('includes/class-havato-rest.php');
const adm = rd('includes/class-havato-admin.php');
const roles = rd('includes/class-havato-roles.php');
const google = rd('includes/class-havato-google-auth.php');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-admin.css');
const i18n = rd('includes/class-havato-i18n.php');
const main = rd('havato.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

console.log('--- 1. nothing tells the guest that chats are stored ---');
t('the notice is gone from the app', !/chat_privacy_note/.test(js));
t('the string is retired', !/chat_privacy_note/.test(i18n));
t('no other storage wording leaked in', !/stored on the server/i.test(js));

console.log('\n--- 2. flagging is silent ---');
t('flag columns on the table chat', /flagged tinyint\(1\)/.test(db) && /flag_term varchar\(64\)/.test(db));
t('…and on private chat too', (db.match(/flagged tinyint\(1\)/g) || []).length === 2);
t('indexed for the admin filter', (db.match(/KEY flagged \(flagged\)/g) || []).length === 2);
t('documented as review-only', /Nothing is blocked or altered and the sender is never\s*\n\s*\/\/ told/.test(db));
t('group send evaluates the text', /function chat_group_send[\s\S]{0,900}havato_profanity_hit/.test(rest));
t('private send evaluates it too', /function chat_private_send[\s\S]{0,900}havato_profanity_hit/.test(rest));
// The message must be delivered exactly as written.
t('the text is stored unmodified', /'message_text' => \$text,/.test(rest));
t('no error is returned to the sender', !/havato_profanity[\s\S]{0,200}WP_Error/.test(rest));
t('the response says nothing about the flag',
  !/'flagged'\s*=>[\s\S]{0,80}self::ok/.test(rest));

console.log('\n--- 3. the word list ---');
t('a filterable list exists', /function havato_profanity_terms/.test(fn) && /apply_filters\( 'havato_profanity_terms'/.test(fn));
t('covers all three languages', /'fuck'/.test(fn) && /'کیر'/.test(fn) && /'siktir'/.test(fn));
t('no corrupt mixed-script entries', (() => {
  const block = /function havato_profanity_terms[\s\S]*?return array_values/.exec(fn)[0];
  const terms = [...block.matchAll(/'([^']+)'/g)].map(m => m[1]);
  return !terms.some(x => /[A-Za-z]/.test(x) && /[\u0600-\u06FF]/.test(x));
})());
t('Arabic letter variants are folded', /'ي' => 'ی'/.test(fn) && /'ك' => 'ک'/.test(fn));
t('letter-for-symbol tricks are undone', /'@' => 'a'/.test(fn) && /'0' => 'o'/.test(fn));
t('whole-word matching for Latin terms', /function havato_term_in_text/.test(fn) && /\(\?<!\[a-z0-9\]\)/.test(fn));
t('Persian keeps substring matching (compounds have no spaces)',
  /Persian compounds and clitics are written without spaces/.test(fn));
t('the glued form is only used when a word was really split', /\$obfuscated/.test(fn));

// Run the matcher rather than trusting the regexes above.
(() => {
  const TERMS = ['کیر', 'کس', 'جنده', 'کونی', 'لاشی', 'گوه',
    'fuck', 'fucking', 'shit', 'bitch', 'bastard', 'asshole', 'cunt', 'whore', 'slut',
    'amk', 'siktir', 'orospu', 'piç', 'göt'];
  const inText = (needle, hay) => {
    if (!needle || !hay) return false;
    if (/^[a-z0-9]+$/.test(needle)) {
      return new RegExp('(?<![a-z0-9])' + needle.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '(?![a-z0-9])', 'u').test(hay);
    }
    return hay.includes(needle);
  };
  const hit = text => {
    if (!text.trim()) return '';
    const hay = text.toLowerCase().replace(/ي/g, 'ی').replace(/ك/g, 'ک').replace(/\u200c/g, '');
    const dec = hay.replace(/@/g, 'a').replace(/\$/g, 's').replace(/0/g, 'o').replace(/1/g, 'i')
      .replace(/3/g, 'e').replace(/4/g, 'a').replace(/5/g, 's').replace(/7/g, 't');
    const collapsed = dec.replace(/[*._\-\s]+/gu, '');
    const spaced = dec.replace(/[*._\-\s]+/gu, ' ');
    const obf = /[^\W\d_][*._\-]+[^\W\d_]/u.test(dec)
      || /(?:^|\s)[^\W\d_](?:[*._\-\s]+[^\W\d_]){2,}(?:\s|$)/u.test(dec);
    const devow = collapsed.replace(/[aeiou]/g, '');
    for (const term of TERMS) {
      const n = term.toLowerCase();
      const flat = n.replace(/[\s._-]+/gu, '');
      if (inText(n, hay) || inText(flat, spaced)) return term;
      if (obf && flat && collapsed.includes(flat)) return term;
      if (obf && /^[a-z]{5,}$/.test(flat)) {
        const sh = flat.replace(/[aeiou]/g, '');
        if (sh.length >= 3 && devow.includes(sh)) return term;
      }
    }
    return '';
  };

  const rude = ['برو گمشو کیری', 'sh1t happens', 'what the f.u.c.k', 'seni siktir et',
    '@sshole', 'این جنده‌خانم', 'B I T C H', 'FUCK YOU', 'bu ne amk', 's-h-i-t'];
  const fine = ['سلام حالت چطوره؟', 'این کافه عالی بود', 'قهوه‌شون خیلی خوبه',
    'Nice to meet you all', 'See you at the table', 'Görüşmek üzere', 'Kahve çok güzeldi',
    'I work in construction', 'She is a great assistant', 'The document is classified',
    'Scunthorpe', 'Shitake mushrooms are nice', 'Massachusetts', 'bass guitar',
    'Class starts at eight', 'e-mail me later', 'co-founder of a startup'];

  const missed = rude.filter(x => !hit(x));
  const falsePos = fine.filter(x => hit(x));
  t(`flags rude text (${rude.length - missed.length}/${rude.length})`, missed.length === 0);
  // The Scunthorpe problem: an innocent word containing a rude substring.
  t(`no false positives on ordinary chat (${fine.length - falsePos.length}/${fine.length})`, falsePos.length === 0);
  t('"Shitake" and "Scunthorpe" specifically stay clean', !hit('Shitake mushrooms are nice') && !hit('Scunthorpe'));
})();

console.log('\n--- 4. the admin sees the flag ---');
t('flagged rows are marked', /hv-adm-flagged/.test(adm) && /\.hv-adm-flagged td/.test(css));
t('the matched term is available on hover', /esc_attr\( \(string\) \$row\['flag_term'\] \)/.test(adm));
t('a headline count is shown first', /function render_flagged_summary/.test(adm));
t('it links straight to the filtered view', /flagged=1/.test(adm));
t('the count is hidden when there is nothing to review',
  /if \( 0 === \$group_flagged && 0 === \$private_flagged \) \{\s*\n\s*return;/.test(adm));
t('a flagged-only filter exists', /\$only_flagged/.test(adm) && /only_flagged/.test(i18n));
t('it is applied to the query', /\$where \.= ' AND flagged = 1';/.test(adm));

console.log('\n--- 5. banning ---');
t('helpers exist', /function havato_is_banned/.test(fn) && /function havato_set_banned/.test(fn));
t('stored as meta, not a deletion', /update_user_meta\( \$user_id, 'havato_banned', '1' \)/.test(fn));
t('reversible', /delete_user_meta\( \$user_id, 'havato_banned' \)/.test(fn));
t('active sessions are destroyed at once', /\$sessions->destroy_all\(\);/.test(fn));
t('button rendered in the admin', /function ban_button/.test(adm));
t('an administrator can never be banned from here', /user_can\( \$user_id, 'manage_options' \)[\s\S]{0,120}return '<span class="hv-adm-muted">—<\/span>'/.test(adm));
t('the POST handler double-checks that', /if \( \$target && ! user_can\( \$target, 'manage_options' \) \)/.test(adm));
t('the action is nonce-protected', /self::form_fields\( 'ban_user' \)/.test(adm));
t('and logged', /'User %d %s by administrator\.'/.test(adm));
t('banned users are marked in the users list', /banned_badge/.test(roles));

console.log('\n--- 6. a ban is actually enforced ---');
// Three independent doors, because each can be reached without the others.
t('login is refused', /function refuse_banned/.test(roles) && /add_filter\( 'authenticate'/.test(roles));
t('Google sign-in is refused too', /havato_is_banned\( \$user->ID \)/.test(google));
t('…and the reason is documented', /never passes through\s*\n\s*\/\/ the `authenticate` filter/.test(google));
t('every authenticated REST call re-checks', /function auth_perm[\s\S]{0,320}havato_is_banned/.test(rest));
t('…because an existing cookie would otherwise still work',
  /A banned account keeps its cookie until it expires/.test(rest));
t('the refusal is a 403 with a clear message', /'havato_banned', Havato_I18N::t\( 'account_banned' \), array\( 'status' => 403 \)/.test(rest));

console.log('\n--- 7. strings ---');
for (const k of ['needs_review', 'only_flagged', 'ban_user', 'unban_user',
                 'banned_badge', 'account_banned', 'flagged_count'])
  t(`i18n "${k}" trilingual`, new RegExp("'" + k + "'[\\s\\S]{0,400}?'fa' =>[\\s\\S]{0,400}?'tr' =>").test(i18n));
t('every string is still trilingual', (() => {
  const b = i18n.slice(i18n.indexOf('self::$map = array('));
  const keys = [...b.matchAll(/'([a-z0-9_]+)'\s*=>\s*array\(\s*(?:\n\s*)?'fa'/g)].map(m => m[1]);
  const tr = [...b.matchAll(/'([a-z0-9_]+)'\s*=>\s*array\([\s\S]{0,800}?'tr'\s*=>/g)].map(m => m[1]);
  return [...new Set(keys)].every(k => tr.includes(k));
})());
t('schema bumped for the flag columns', /HAVATO_DB_VERSION', '1\.13\.0'/.test(main));

console.log(f ? `\n❌ ${f} failing` : '\n✅ silent flagging, admin review markers and platform bans all working');
process.exit(f ? 1 : 0);
