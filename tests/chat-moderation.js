/* v1.18.0 —
   1) chats are stored server-side and the administrator can read them
   2) guests can report a message and block its sender from inside the chat */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const db = rd('includes/class-havato-db.php');
const rest = rd('includes/class-havato-rest.php');
const adm = rd('includes/class-havato-admin.php');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const i18n = rd('includes/class-havato-i18n.php');
const fn = rd('includes/functions.php');
const main = rd('havato.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

console.log('--- 1. messages are persisted ---');
t('group chat table exists', /CREATE TABLE \{\$p\}chats \(/.test(db));
t('private chat table exists', /CREATE TABLE \{\$p\}private_chats \(/.test(db));
t('both keep the text and a timestamp',
  (db.match(/message_text text NULL/g) || []).length === 2 &&
  (db.match(/message_time datetime/g) || []).length === 2);
t('sender is recorded', /sender_id bigint/.test(db));

console.log('\n--- 2. report queue ---');
t('message_reports table added', /CREATE TABLE \{\$p\}message_reports \(/.test(db));
t('registered in the table list', /'message_reports',/.test(db));
t('it covers group AND private via a scope column', /scope varchar\(16\)/.test(db));
t('one report per person per message', /UNIQUE KEY one_per_reporter \(scope,message_id,reporter_id\)/.test(db));
t('an excerpt is kept for the moderator', /excerpt text NULL/.test(db));
t('schema is at or past the report table', (() => {
  const m = /HAVATO_DB_VERSION', '(\d+)\.(\d+)\.(\d+)'/.exec(main);
  if (!m) return false;
  const [maj, min] = [Number(m[1]), Number(m[2])];
  return maj > 1 || (maj === 1 && min >= 12);
})());
t('table numbering has no gap', (() => {
  const nums = [...db.matchAll(/^\t\t\/\/ (\d+)\. /gm)].map(m => Number(m[1]));
  return nums.length > 0 && nums.every((n, i) => n === i + 1);
})());

console.log('\n--- 3. reporting is authorised, not just accepted ---');
t('endpoint registered', /'chat\/report'\s*=>\s*array\( 'POST', 'report_message', \$auth \)/.test(rest));
t('handler exists', /function report_message/.test(rest));
// A guessed message id must not leak somebody else's conversation.
t('group reports require membership of that group',
  /function report_message[\s\S]{0,1400}is_group_member\( \$row\['group_id'\], \$user_id \)/.test(rest));
t('private reports require being one of the two participants',
  /\(int\) \$row\['sender_id'\] !== \$user_id && \(int\) \$row\['receiver_id'\] !== \$user_id/.test(rest));
t('you cannot report yourself', /havato_self_report/.test(rest));
t('the reason is allow-listed', /array\( 'nudity', 'fake', 'spam', 'other' \)/.test(rest));
t('the excerpt is length-clamped', /havato_clamp_text\( \(string\) \$row\['message_text'\], 500 \)/.test(rest));
t('duplicate taps cannot flood the queue', /\$wpdb->replace\(\s*\n\s*\$reports/.test(rest));

console.log('\n--- 4. blocking ---');
t('block endpoint registered', /'chat\/block'\s*=>\s*array\( 'POST', 'block_user', \$auth \)/.test(rest));
t('unblock endpoint registered', /'chat\/unblock'\s*=>\s*array\( 'POST', 'unblock_user', \$auth \)/.test(rest));
t('you cannot block yourself', /\$target === \$user_id/.test(rest));
t('blocking also ends the friendship', /function block_user[\s\S]{0,900}DELETE FROM \$friends/.test(rest));
t('unblock rewrites the list without the target', /array_diff\( \$profile\['blocklist'\], array\( \$target \) \)/.test(rest));
t('the block is symmetric', /function havato_is_blocked/.test(fn));
// The gap found while building this: a block hid the person everywhere
// except the lines they had already posted to a table.
t('blocked senders disappear from group history too',
  /in_array\( \$sender, \$blocked, true \)[\s\S]{0,40}continue;/.test(rest));
t('the reason is documented', /including the\s*\n\s*\/\/ lines they already posted/.test(rest));
t('the blocklist is resolved once, not per message', /\$blocked = array_map\( 'intval', \(array\) \$profile\['blocklist'\] \);/.test(rest));

console.log('\n--- 5. polling still advances past filtered messages ---');
// Without a server cursor the client would re-request a trailing blocked
// message on every poll, forever.
t('the server returns a cursor', /'cursor'   => \$cursor,/.test(rest));
t('the cursor counts scanned rows, not delivered ones', /\$cursor = max\( \$cursor, \(int\) \$row\['id'\] \);/.test(rest));
t('the client honours it', /typeof res\.cursor === 'number'/.test(js));
(() => {
  const rows = [{ id: 1, s: 2 }, { id: 2, s: 3 }];
  const blocked = [3];
  // with the cursor
  let last = 0, stalls = 0;
  for (let i = 0; i < 3; i++) {
    const batch = rows.filter(r => r.id > last);
    const cursor = batch.reduce((m, r) => Math.max(m, r.id), last);
    const before = last;
    last = Math.max(last, cursor);
    if (i > 0 && last === before && batch.length) stalls++;
  }
  t('a trailing blocked message is not re-queried forever', last === 2 && stalls === 0);
})();

console.log('\n--- 6. the administrator can read everything ---');
t('admin page registered', /'havato-chats'\s*=>\s*array\( 'admin_chats', 'page_chats' \)/.test(adm));
t('shown in the tab strip', /'havato-chats'\s*=>\s*Havato_I18N::t\( 'admin_chats' \)/.test(adm));
t('page renders', /function page_chats/.test(adm));
t('report queue rendered', /function render_chat_reports/.test(adm));
t('full archive rendered', /function render_chat_archive/.test(adm));
t('archive covers both kinds of chat', /'private' === \$scope[\s\S]{0,120}private_chats/.test(adm));
t('archive is searchable with esc_like', /esc_like\( \$search \)/.test(adm));
t('archive is paginated', /self::pagination\( \$total, \$per_page, \$paged/.test(adm));
t('resolution endpoint is admin-only', /'admin\/chat-report'\s*=>\s*array\( 'POST', 'admin_chat_report', \$admin \)/.test(rest));
t('the admin form is nonce-protected', /self::form_fields\( 'chat_report' \)/.test(adm));
t('POST handler wired', /case 'chat_report':/.test(adm));
// Deleting a row would break the order of the surrounding conversation.
t('removing a message blanks it rather than deleting the row',
  /'message_text' => Havato_I18N::t\( 'message_removed' \)/.test(rest));
t('the report is then marked resolved', /'removed' : 'kept'/.test(rest));

console.log('\n--- 7. the guest-facing UI ---');
t('foreign messages are tappable', /is-actionable/.test(js) && /\.hv-msg\.is-actionable/.test(css));
t('own and system messages are not', /!msg\.mine && !msg\.is_system && msg\.sender_id/.test(js));
t('an action sheet exists', /function openMessageActions/.test(js));
t('it offers all four reasons',
  ['nudity', 'fake', 'spam', 'other'].every(r => new RegExp("key: '" + r + "'").test(js)));
t('it offers block', /hv-msg-block/.test(js));
t('blocking asks for confirmation first', /hv-block-go/.test(js) && /block_confirm/.test(js));
t('after blocking the room is closed', /S\.chatRoom = null;\s*\n\s*stopPolling\(\);\s*\n\s*viewChats\(\);/.test(js));
t('the scope is derived from the open room', /S\.chatRoom\.type === 'private'\) \? 'private' : 'group'/.test(js));
// Removed in 1.19.0 at the site owner's request: guests are no longer shown
// a storage notice anywhere in the app.
t('no storage notice is shown to guests',
  !/chat_privacy_note/.test(js) && !/chat_privacy_note/.test(i18n));

console.log('\n--- 8. strings ---');
for (const k of ['block_user', 'unblock_user', 'block_confirm', 'report_message',
                 'message_reported', 'message_removed', 'admin_chats', 'chat_reports',
                 'chat_log', 'col_message', 'col_date'])
  t(`i18n "${k}" trilingual`, new RegExp("'" + k + "'[\\s\\S]{0,400}?'fa' =>[\\s\\S]{0,400}?'tr' =>").test(i18n));

// col_date was referenced in four places but never defined, so those table
// headers were printing the raw key.
t('col_date is now defined (it was referenced but missing)', /'col_date'\s*=>\s*array\(/.test(i18n));
t('every string is still trilingual', (() => {
  const b = i18n.slice(i18n.indexOf('self::$map = array('));
  const keys = [...b.matchAll(/'([a-z0-9_]+)'\s*=>\s*array\(\s*(?:\n\s*)?'fa'/g)].map(m => m[1]);
  const tr = [...b.matchAll(/'([a-z0-9_]+)'\s*=>\s*array\([\s\S]{0,800}?'tr'\s*=>/g)].map(m => m[1]);
  return [...new Set(keys)].every(k => tr.includes(k));
})());

console.log(f ? `\n❌ ${f} failing` : '\n✅ chats archived, reportable and blockable; admin can moderate');
process.exit(f ? 1 : 0);
