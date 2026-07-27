/* v1.12.0 — the plugin handles no money at all.
   Everything is free; joining is gated on a finished profile instead.
   Café MENU prices are deliberately kept: they belong to the café and are
   shown for information only, exactly like the rest of the menu. */
const fs = require('fs');
const path = require('path');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const rest = rd('includes/class-havato-rest.php');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const db = rd('includes/class-havato-db.php');
const adm = rd('includes/class-havato-admin.php');
const oa = rd('includes/class-havato-owner-admin.php');
const settings = rd('includes/class-havato-settings.php');
const i18n = rd('includes/class-havato-i18n.php');
const fn = rd('includes/functions.php');
const main = rd('havato.php');
const cron = rd('includes/class-havato-cron.php');
const sc = rd('includes/class-havato-shortcode.php');
const seeder = rd('includes/class-havato-seeder.php');
const uninst = rd('uninstall.php');
const icons = rd('templates/parts/icons.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

console.log('--- 1. the payment machinery is gone ---');
t('class-havato-woo.php deleted', !fs.existsSync(R + 'includes/class-havato-woo.php'));
t('class-havato-payouts.php deleted', !fs.existsSync(R + 'includes/class-havato-payouts.php'));
t('neither is required any more', !/class-havato-(woo|payouts)\.php/.test(main));
t('Havato_Woo never referenced', !/Havato_Woo/.test(main + rest + adm + oa + cron + sc));
t('Havato_Payouts never referenced', !/Havato_Payouts/.test(main + rest + adm + oa + cron + sc));
t('havato_woo_active() removed', !/function havato_woo_active/.test(fn));
t('…and never called', !/havato_woo_active\(/.test(rest + sc + js + adm + oa));

console.log('\n--- 2. no money left in the data model ---');
t('payouts table dropped', !/CREATE TABLE \{\$p\}payouts/.test(db));
t('payouts not in the table registry', !/'payouts',/.test(db));
t('events.price column dropped', !/price int\(11\)/.test(db));
t('registrations.amount dropped', !/amount int\(11\)/.test(db));
t('registrations.order_id dropped', !/order_id bigint/.test(db));
t('uninstall no longer drops a payouts table', !/'payouts',/.test(uninst));
t('table comments renumbered with no gap',
  /\/\/ 14\. Venue tables/.test(db) && /\/\/ 15\. Which tables/.test(db) && !/\/\/ 16\./.test(db));
t('schema version is at or past the money-removal bump', (() => {
  const m = /HAVATO_DB_VERSION', '(\d+)\.(\d+)\.(\d+)'/.exec(main);
  if (!m) return false;
  const [maj, min] = [Number(m[1]), Number(m[2])];
  return maj > 1 || (maj === 1 && min >= 8);
})());

console.log('\n--- 3. no money endpoints, settings or pages ---');
t('owner/payouts route gone', !/'owner\/payouts'/.test(rest));
t('admin/payout route gone', !/'admin\/payout'/.test(rest));
t('owner_payouts() gone', !/function owner_payouts/.test(rest));
t('admin_payout() gone', !/function admin_payout/.test(rest));
t('wallet_summary() gone', !/wallet_summary/.test(rest));
t('admin revenue page gone', !/function page_revenue/.test(adm) && !/'havato-revenue'/.test(adm));
t('owner payout page gone', !/function page_payouts/.test(oa) && !/'havato-venue-payouts'/.test(oa));
t('commission setting gone', !/commission_percent/.test(settings + adm));
t('default ticket price setting gone', !/default_ticket_price/.test(settings + adm));
t('wc_product_id setting gone', !/wc_product_id/.test(settings));

console.log('\n--- 4. the seat-hold machinery went with it ---');
// pending_payment only ever existed to stop concurrent checkouts overselling.
t('pending_payment status gone anywhere in the code',
  !/pending_payment/.test(rest + adm + oa + db + js));
t('queue_user no longer writes dropped money columns',
  !/'order_id'\s*=>/.test(rest) && !/'amount'\s*=>/.test(rest));
t('hold expiry job gone', !/expire_stale_holds/.test(rest));
t('seat-hold filter gone', !/havato_seat_hold_minutes/.test(rest));

console.log('\n--- 5. joining is free and gated on the profile ---');
t('join_event no longer reads a price', !/\$price = \(int\) \$event\['price'\]/.test(rest));
t('no checkout branch', !/create_checkout/.test(rest));
t('personality test required', /havato_no_profile/.test(rest));
t('personal details required too', /havato_no_details/.test(rest));
t('details check uses the real validator',
  /havato_valid_city\( \$profile\['country'\], \$profile\['city'\] \)/.test(rest));
t('both gates are bilingual strings',
  /'need_profile_first'/.test(i18n) && /'need_details_first'/.test(i18n));
t('the app no longer redirects to a gateway', !/checkout_url/.test(js));
t('the app steers either failure to the profile', /havato_no_details/.test(js));
t('events advertise that they are free', /hv-free/.test(js) && /hv-free/.test(css));

console.log('\n--- 6. nothing says money in the UI ---');
t('no wallet card', !/walletMarkup/.test(js));
t('profile stats replaced it', /function statsMarkup/.test(js));
t('wallet icon symbol removed', !/hv-i-wallet/.test(icons) && !/icon\('wallet'\)/.test(js));
t('no event price line', !/hv-event-price/.test(js + css));
t('no "redirecting to checkout" string', !/redirect_payment/.test(i18n + js));
for (const k of ['wallet_spent', 'payout_status', 'payout_gross', 'payout_commission',
                 'payout_share', 'payout_paid', 'payout_due', 'stat_revenue',
                 'revenue_by_event', 'admin_revenue'])
  t(`i18n "${k}" removed`, !new RegExp("'" + k + "'").test(i18n));
t('an "always free" string exists', /'always_free'/.test(i18n));

console.log('\n--- 7. demo content is free too ---');
t('seeder sets no event price', !/'price'\s*=>\s*\$prices/.test(seeder));
t('no price ladder left', !/\$prices\s*=/.test(seeder));

console.log('\n--- 8. what was deliberately KEPT ---');
// The café's own menu. No transaction happens; it is printed like a paper menu.
t('menu item prices still stored', /'price'/.test(seeder));
t('menu prices still rendered for guests', /price_label/.test(rest) && /hv-menu-price/.test(js));
t('havato_price() helper retained for the menu', /function havato_price/.test(fn));
t('the café price filter became an atmosphere filter',
  /Atmosphere, not price/.test(i18n) && /'atmosphere'/.test(i18n));
t('its stored keys are unchanged, so no migration is needed',
  /budget_tier varchar\(20\)/.test(db) && /'low', 'medium', 'high'/.test(rest));

console.log('\n--- 9. still coherent ---');
t('admin dashboard shows sign-ups instead of revenue',
  /'signups'/.test(rest) && /stat_signups/.test(adm) && !/revenue/.test(adm));
t('stats payload has no revenue key', !/'revenue'/.test(rest));
t('cron no longer rebuilds a ledger', !/rebuild_all/.test(cron));
t('boot payload no longer advertises WooCommerce', !/wooActive/.test(sc + js));

console.log(f ? `\n❌ ${f} failing` : '\n✅ no payments anywhere; free to join, gated on a finished profile');
process.exit(f ? 1 : 0);
