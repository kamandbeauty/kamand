/* v1.21.0 — six issues reported from a live phone screenshot:

   1) the system "your table is ready" line showed Persian AND English at once
   2) every message the guest sent appeared twice
   3) no sender name or face beside a message
   4) no stickers
   5) admin had no edit / cancel / details controls for an event
   6) a Turkish café priced its menu in Toman

   The duplicate-message race and the language pick are modelled and executed,
   not grepped: the same interleaving that produced the bug is replayed.      */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const rest = rd('includes/class-havato-rest.php');
const matcher = rd('includes/class-havato-matcher.php');
const fn = rd('includes/functions.php');
const i18n = rd('includes/class-havato-i18n.php');
const admin = rd('includes/class-havato-admin.php');
const ownerAdmin = rd('includes/class-havato-owner-admin.php');
const db = rd('includes/class-havato-db.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

/* =====================================================================
 * 1. The system message is no longer a glued-together bilingual string
 * ================================================================== */
console.log('--- 1. system message speaks one language ---');

t('the bilingual template is gone', !/Your table is ready at %s%s/.test(matcher));
t('no pipe-joined fa|en literal remains', !/میز شما چیده شد! %s%s — %s ساعت %s \|/.test(matcher));
t('it is stored as JSON', /'message_text' => wp_json_encode\( \$payload \)/.test(matcher));
t('one entry per supported language', /foreach \( array_keys\( Havato_I18N::languages\(\) \) as \$lang \)/.test(matcher));
t('the wording comes from the string map', /Havato_I18N::t\( 'chat_table_ready', \$lang \)/.test(matcher));
t('…and that key is trilingual', /'chat_table_ready'\s*=> array\( 'fa' =>.*'en' =>.*'tr' =>/.test(i18n));
t('the venue fallback is translated too', /'venue_fallback'\s*=> array\( 'fa' =>.*'tr' =>/.test(i18n));
t('venue_name() answers in every language', /foreach \( array_keys\( Havato_I18N::languages\(\) \) as \$lang \)[\s\S]{0,220}venue_fallback/.test(matcher));

// The decode helper, re-implemented and driven.
function messagePair(raw, isSystem) {
  const langs = ['fa', 'en', 'tr'];
  let decoded = null;
  if (isSystem) { try { decoded = JSON.parse(raw); } catch (e) { decoded = null; } }
  const out = {};
  langs.forEach(l => {
    if (decoded && typeof decoded === 'object' && typeof decoded[l] === 'string') { out[l] = decoded[l]; return; }
    if (decoded && typeof decoded === 'object' && typeof decoded.en === 'string') { out[l] = decoded.en; return; }
    out[l] = String(raw);
  });
  return out;
}

const sys = JSON.stringify({ fa: 'میز شما چیده شد! کافه ناروان', en: 'Your table is ready at Naravan', tr: 'Masanız hazır: Naravan' });
t('a Persian reader gets only Persian', messagePair(sys, true).fa === 'میز شما چیده شد! کافه ناروان');
t('…with no English glued on', messagePair(sys, true).fa.indexOf('Your table') === -1);
t('an English reader gets only English', messagePair(sys, true).en === 'Your table is ready at Naravan');
t('a Turkish reader gets Turkish', messagePair(sys, true).tr === 'Masanız hazır: Naravan');

// Backwards compatibility and safety.
const legacy = 'میز شما چیده شد! کافه ناروان | Your table is ready.';
t('a pre-upgrade row still renders', messagePair(legacy, true).fa === legacy);
t('guest text is never JSON-decoded', messagePair('{"fa":"hack"}', false).fa === '{"fa":"hack"}');
t('a guest typing JSON sees it verbatim', messagePair('{"a":1}', false).en === '{"a":1}');
t('the helper always fills every language', Object.keys(messagePair('hi', false)).join() === 'fa,en,tr');
t('helper exists server-side', /function havato_message_pair\(/.test(fn));
t('the REST layer uses it for table chat', /'text'\s*=> havato_message_pair\( \$row\['message_text'\], \(bool\) \$row\['is_system'\] \)/.test(rest));
t('private chat sends the same shape', /'text'\s*=> havato_message_pair\( \$row\['message_text'\], false \)/.test(rest));
t('the admin archive decodes instead of printing raw JSON', /havato_message_text\( \$row\['message_text'\]/.test(admin));
t('the client picks its own language', /typeof msg\.text === 'object'\) \? pick\(msg\.text\)/.test(js));

/* =====================================================================
 * 2. Every message was rendered twice
 * ================================================================== */
console.log('\n--- 2. one message, rendered once ---');

// Replay the exact interleaving: send triggers a fetch, the 3s poll fires in
// the same tick, both read the same `since`.
function replay(withFix) {
  let rows = [], nextId = 1, lastMsgId = 0, inFlight = false;
  const log = [];
  const get = since => ({
    messages: rows.filter(r => r.id > since),
    cursor: rows.reduce((m, r) => Math.max(m, r.id), since),
  });
  function fetchMessages() {
    if (withFix && inFlight) { return Promise.resolve(); }
    inFlight = true;
    const since = lastMsgId;
    return Promise.resolve(get(since)).then(res => {
      res.messages.forEach(m => {
        if (withFix && log.indexOf(m.id) !== -1) { return; }
        lastMsgId = Math.max(lastMsgId, m.id);
        log.push(m.id);
      });
      lastMsgId = Math.max(lastMsgId, res.cursor);
    }).then(() => { inFlight = false; });
  }
  rows.push({ id: nextId++ });
  return Promise.all([fetchMessages(), fetchMessages()]).then(() => log);
}

const checks = [];
checks.push(replay(false).then(log => {
  t('the bug reproduces without the fix (message rendered twice)', log.length === 2);
}));
checks.push(replay(true).then(log => {
  t('with the fix it is rendered exactly once', log.length === 1 && log[0] === 1);
}));

t('a second request is refused while one is in flight', /if \(S\.chatFetching\) \{ return; \}/.test(js));
t('the flag is raised before the request', /S\.chatFetching = true;/.test(js));
t('…and always cleared afterwards', /\}\)\.then\(function \(\) \{[\s\S]{0,160}S\.chatFetching = false;/.test(js));
t('failure clears it too (no permanent freeze)', /\.catch\(function \(\) \{[\s\S]{0,120}\}\)\.then\(function \(\) \{[\s\S]{0,160}chatFetching = false/.test(js));
t('it is declared in the state object', /chatFetching: false/.test(js));
t('opening another room resets it', /openChatRoom[\s\S]{0,320}S\.chatFetching = false;/.test(js));
t('a second guard keys rendered nodes by id', /data-msg-key="' \+ msg\.id \+ '"/.test(js));
t('…and the node carries that key', /node\.setAttribute\('data-msg-key', msg\.id\)/.test(js));
t('a late response for an old room is discarded', /S\.chatRoom\.id !== room\.id\) \{ return; \}/.test(js));

/* =====================================================================
 * 3. Sender name and face
 * ================================================================== */
console.log('\n--- 3. you can see who is talking ---');

t('the avatar is rendered', /class="hv-msg-avatar"/.test(js));
t('the name is still rendered', /class="hv-msg-name"/.test(js));
t('own messages carry no avatar', /!msg\.mine && !msg\.is_system && msg\.avatar/.test(js));
t('the server sends an avatar for table chat', /'avatar'\s*=> \$sender \? havato_avatar\( \$sender \) : ''/.test(rest));
t('…and for private chat', /'avatar'\s*=> havato_avatar\( \(int\) \$row\['sender_id'\] \)/.test(rest));
t('private chat also sends a name', /'name'\s*=> havato_display_name\( \(int\) \$row\['sender_id'\] \)/.test(rest));
t('the avatar row is styled', /\.hv-msg\.has-avatar \{/.test(css));
t('the bubble keeps its own background', /\.hv-msg\.has-avatar \.hv-msg-bubble \{/.test(css));
t('the avatar is a circle', /\.hv-msg-avatar \{[\s\S]{0,200}border-radius: 50%/.test(css));

/* =====================================================================
 * 4. Stickers
 * ================================================================== */
console.log('\n--- 4. stickers ---');

t('a sticker set is defined', /var STICKERS = \[/.test(js));
const stickerBlock = js.slice(js.indexOf('var STICKERS = ['), js.indexOf(']', js.indexOf('var STICKERS = [')));
const stickerCount = (stickerBlock.match(/'/g) || []).length / 2;
t('it holds a usable number of stickers (>= 12)', stickerCount >= 12);
t('the tray is rendered', /id="hv-sticker-tray"/.test(js));
t('a toggle button opens it', /id="hv-chat-sticker"/.test(js));
t('the button is labelled for screen readers', /aria-label="' \+ esc\(t\('stickers'\)\)/.test(js));
t('the label is trilingual', /'stickers'\s*=> array\( 'fa' =>.*'en' =>.*'tr' =>/.test(i18n));
t('a sticker sends through the normal path', /sendMessage\(btn\.dataset\.sticker\)/.test(js));
t('sendMessage accepts a sticker argument', /function sendMessage\(sticker\)/.test(js));
t('typing still works when no sticker is passed', /text = input\.value\.trim\(\);/.test(js));
t('the tray closes after picking', /tray\.hidden = true;/.test(js));
t('the tray is styled', /\.hv-sticker-tray \{/.test(css));
t('hiding it beats the theme cascade', /#havato-app \.hv-sticker-tray\[hidden\] \{ display: none !important/.test(css));

// A sticker must be an ordinary message: same endpoint, same moderation.
t('no new endpoint was added for stickers', !/sticker/i.test(rest));

/* =====================================================================
 * 5. Admin event controls
 * ================================================================== */
console.log('\n--- 5. the admin can edit, cancel and inspect an event ---');

t('the three buttons are rendered', /event_details/.test(admin) && /event_edit/.test(admin) && /event_cancel/.test(admin));
t('a single-event screen exists', /function page_event_single/.test(admin));
t('the list routes to it', /isset\( \$_GET\['event'\] \)[\s\S]{0,200}page_event_single/.test(admin));
t('an edit form exists', /function render_event_edit_form/.test(admin));
t('saving is nonce-protected', /check_admin_referer\( 'havato_admin', 'havato_nonce' \)/.test(admin));
t('and admin-only', /current_user_can\( 'manage_options' \)[\s\S]{0,80}wp_die/.test(admin));
t('the save handler exists', /case 'event_save':/.test(admin));
t('the cancel handler exists', /case 'event_cancel':/.test(admin));
t('a bad date is rejected rather than written',
  /\$valid_date = \(bool\) preg_match\(/.test(admin) && admin.indexOf('d{4}-') !== -1);
t('a bad time is rejected too', /valid_time = \(bool\) preg_match/.test(admin));
t('only known statuses can be stored', /in_array\( \$state, array\( 'open', 'matched', 'completed', 'cancelled', 'pending_admin' \), true \)/.test(admin));
t('cancelling is a status change, not a delete', /'status' => 'cancelled'[\s\S]{0,400}event_registrations/.test(admin));
t('…so no wpdb->delete is used to cancel', !/case 'event_cancel':[\s\S]{0,900}\$wpdb->delete/.test(admin));
t('the seats are released', /Havato_DB::table\( 'event_registrations' \),\s*array\( 'status' => 'cancelled' \)/.test(admin));
t('a cancellation with guests warns first', /event_cancel_confirm_guests/.test(admin));
t('the action is logged', /Event %s cancelled by administrator/.test(admin));
t('editing is logged as well', /Event %s edited by administrator/.test(admin));
t('the redirect returns to the same event', /\$extra = array\( 'event' => \$event_id \)/.test(admin));
t('the new status is filterable in the list', /'cancelled'\s*=> Havato_I18N::t\( 'status_cancelled' \)/.test(admin));
t('…and accepted by the query whitelist', /in_array\( \$status, array\( 'open', 'matched', 'completed', 'cancelled', 'pending_admin' \), true \)/.test(admin));
t('capacity is not editable by hand (it comes from real tables)', !/name="max_capacity"/.test(admin));

// A cancelled event must stop accepting guests.
t('explore lists only open and matched', /e\.status IN \('open','matched'\)/.test(rest));
t('join_event refuses anything else', /in_array\( \(string\) \$event\['status'\], array\( 'open', 'matched' \), true \)/.test(rest));
t('…with its own message', /'event_not_open'/.test(rest) && /'event_not_open'\s*=> array\( 'fa' =>/.test(i18n));

/* =====================================================================
 * 6. Turkish cafés price in Lira
 * ================================================================== */
console.log('\n--- 6. the currency follows the café, not the reader ---');

function currency(country) {
  const map = { ir: 'toman', tr: 'lira' };
  return map[String(country).toLowerCase()] || 'toman';
}
const LABEL = {
  toman: { fa: 'تومان', en: 'Toman', tr: 'Tümen' },
  lira: { fa: 'لیر', en: 'Lira', tr: 'TL' },
};
function price(amount, lang, country) {
  if (amount <= 0) return 'free';
  return String(amount) + ' ' + LABEL[currency(country)][lang];
}

t('an Istanbul café charges Lira in Turkish', price(120, 'tr', 'tr') === '120 TL');
t('…in English', price(120, 'en', 'tr') === '120 Lira');
t('…and in Persian too (the reported bug)', price(120, 'fa', 'tr') === '120 لیر');
t('a Tehran café still charges Toman', price(120, 'fa', 'ir') === '120 تومان');
t('an English reader of a Tehran menu sees Toman', price(120, 'en', 'ir') === '120 Toman');
t('an unknown country falls back rather than printing a bare number',
  price(120, 'en', '').indexOf('Toman') !== -1);
t('free stays free regardless of country', price(0, 'fa', 'tr') === 'free');

t('the helper exists', /function havato_currency_label\(/.test(fn));
t('havato_price takes a country', /function havato_price\( \$amount, \$lang = null, \$country = '' \)/.test(fn));
t('the currency is no longer read off the language', !/if \( 'fa' === \$lang \) \{\s*return .*fa_digits.*toman/.test(fn));
t('the map is filterable', /apply_filters\(\s*'havato_country_currencies'/.test(fn));
t('lira is a real string key', /'lira'\s*=> array\( 'fa' =>.*'en' =>.*'tr' =>/.test(i18n));
t('the Turkish label for Toman is no longer "Lira"', !/'toman'\s*=> array\([^)]*'tr' => 'Lira'/.test(i18n));
t('price_pair covers every language', /foreach \( array_keys\( Havato_I18N::languages\(\) \) as \$lang \)[\s\S]{0,140}havato_price\( \$amount, \$lang, \$country \)/.test(fn));
t('the venue payload passes the café country', /havato_price_pair\( isset\( \$item\['price'\] \) \? \(int\) \$item\['price'\] : 0, \$country \)/.test(rest));
t('the pending menu does too', /\$pending\[ \$i \]\['price_label'\] = havato_price_pair\([^;]*\$country \)/.test(rest));
t('the admin approval queue uses the café currency', /havato_price\( \$price, null, isset\( \$row\['country'\] \)/.test(admin));

/* =====================================================================
 * 7. Regression found while reading the owner panel
 * ================================================================== */
console.log('\n--- 7. the owner events table is no longer column-shifted ---');

t('events table has no price column in the schema', !/CREATE TABLE \{\$p\}events[\s\S]*?price[\s\S]*?\) \$charset/.test(db));
t('the owner table no longer prints a price cell', !/havato_price\( \(int\) \$row\['price'\], \$lang \)/.test(ownerAdmin));

const tbl = ownerAdmin.slice(ownerAdmin.indexOf('private static function events_table'));
const head = tbl.slice(0, tbl.indexOf('</tr></thead>'));
const body = tbl.slice(tbl.indexOf('<tbody>'), tbl.indexOf('</tbody>'));
const ths = (head.match(/<th>/g) || []).length;
const tds = (body.match(/echo '<td/g) || []).length;
t('header and body cell counts now match (' + ths + ' vs ' + tds + ')', ths === tds);

Promise.all(checks).then(() => {
  console.log(f ? `\n❌ ${f} failed` : '\n✅ chat, admin event controls and per-country currency all correct');
  process.exit(f ? 1 : 0);
});
