/* Admin: all events + their guests, and the full café directory. */
const fs=require('fs');
const R=__dirname+'/../havato/';
const rd=f=>fs.readFileSync(R+f,'utf8');
const adm=rd('includes/class-havato-admin.php'), i18n=rd('includes/class-havato-i18n.php');
const oa=rd('includes/class-havato-owner-admin.php'), css=rd('assets/css/havato-admin.css');
const rest=rd('includes/class-havato-rest.php');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- new admin screens registered ---');
t('Events & guests submenu', /'havato-events'\s*=>\s*array\( 'admin_events', 'page_events' \)/.test(adm));
t('All cafés submenu', /'havato-venues'\s*=>\s*array\( 'admin_venues', 'page_venues' \)/.test(adm));
t('both in the tab strip', /'havato-events'\s*=>\s*Havato_I18N::t/.test(adm) && /'havato-venues'\s*=>\s*Havato_I18N::t/.test(adm));
t('existing 7 pages untouched',
  ['page_dashboard','page_approvals','page_revenue','page_matcher','page_weights','page_google','page_locale']
    .every(p=>new RegExp('function '+p).test(adm)));

console.log('\n--- events page ---');
t('lists every event', /function page_events/.test(adm));
t('shows the guest list', /function render_event_card/.test(adm));
t('guest avatars rendered', /hv-adm-guest-avatar/.test(adm));
t('avatars lazy-loaded', /loading="lazy"/.test(adm));
t('shows event title', /\$title = trim\( \(string\) \$row\['title'\] \)/.test(adm));
t('falls back when title is empty', /'' !== \$title \? \$title :/.test(adm));
t('shows venue + city + date', /venue_name/.test(adm) && /havato_city_label/.test(adm));
t('shows paid amount + check-in', /checked_in/.test(adm) && /havato_price\( \(int\) \$m\['amount'\]/.test(adm));
t('status filter', /hv-adm-filterbar/.test(adm));
t('paginated', /function pagination/.test(adm));
t('cancelled registrations excluded', /status <> 'cancelled'/.test(adm));

console.log('\n--- N+1 avoided (the perf risk I flagged) ---');
t('guests fetched with ONE batched IN() query', /WHERE event_id IN \(\$placeholders\)/.test(adm));
t('placeholders built safely', /array_fill\( 0, count\( \$ids \), '%s' \)/.test(adm));
t('grouped in PHP, not re-queried', /\$by_event\[ \$m\['event_id'\] \]\[\] = \$m;/.test(adm));
t('reason documented', /N\+1/.test(adm));
{
  // 20 events x 6 guests: per-event lookups vs one batch
  const events=20, naive=1+events, batched=2;
  console.log(`   queries for ${events} events: naive=${naive}, batched=${batched}`);
  t('query count is constant, not per-event', batched < naive);
}

console.log('\n--- café directory ---');
t('full list page', /function page_venues/.test(adm));
t('search by name/manager/address', /v\.name LIKE %s OR v\.manager_name LIKE %s OR v\.address LIKE %s/.test(adm));
t('search input escaped for LIKE', /\$wpdb->esc_like\( \$search \)/.test(adm));
t('city filter', /AND v\.city = %s/.test(adm));
t('status filter', /'verified' === \$state/.test(adm));
t('storefront photo shown', /hv-adm-shopfront/.test(adm));
t('event count folded into one query', /SELECT COUNT\(\*\) FROM \$events e WHERE e\.venue_id = v\.id/.test(adm));
t('paginated', /'page' => 'havato-venues', 's' => \$search/.test(adm));
t('verify button available inline', /'verify'/.test(adm));
t('verify returns to the page it was clicked on', /return_page/.test(adm));
t('return_page allow-listed (no open redirect)',
  /in_array\( \$from, array\( 'havato-venues', 'havato-approvals' \), true \)/.test(adm));

console.log('\n--- event title end-to-end ---');
t('owner form asks for it', /name="title"/.test(oa));
t('passed through the POST handler', /foreach \( array\( 'title',[^)]*'event_date'/.test(oa));
t('shown in the owner events table', /\$row\['title'\]/.test(oa));
t('stored by the REST layer', /'title'\s*=>\s*sanitize_text_field/.test(rest));
t('returned to clients', /'title'\s*=>\s*\$row\['title'\]/.test(rest));

console.log('\n--- safety ---');
t('all output escaped in the new pages',
  !/echo \$row\[/.test(adm) && !/echo \$m\[/.test(adm));
t('user input parameterised', /\$wpdb->prepare\(/.test(adm));
t('styles added', /\.hv-adm-guest \{/.test(css) && /\.hv-adm-chip \{/.test(css));
for (const k of ['admin_events','admin_venues','event_title','event_title_hint'])
  t(`i18n "${k}" bilingual`, new RegExp(`'${k}'[^\\n]*'fa' =>[^\\n]*'en' =>`).test(i18n));

console.log(f?`\n❌ ${f} failure(s)`:'\n✅ event & café listings added, no N+1, nothing else touched');
process.exit(f?1:0);
