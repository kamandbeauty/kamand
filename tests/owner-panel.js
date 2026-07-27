/* 1) mobile owner portal removed  2) wp-admin panel works
   3) cafe_owner locked to its own panel + profile */
const fs=require('fs');
const R=__dirname+'/../havato/';
const rd=f=>fs.readFileSync(R+f,'utf8');
const js=rd('assets/js/havato-app.js'), oa=rd('includes/class-havato-owner-admin.php');
const oj=rd('assets/js/havato-owner-admin.js'), main=rd('havato.php');
const roles=rd('includes/class-havato-roles.php'), adm=rd('includes/class-havato-admin.php');
const rest=rd('includes/class-havato-rest.php'), i18n=rd('includes/class-havato-i18n.php');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- 1. mobile owner portal fully removed ---');
for (const fn of ['viewOwnerDashboard','viewOwnerEvents','viewMenuBuilder','viewVenueSettings',
                  'openCreateEvent','openOwnerEvent','renderMenuDraft','menuRowMarkup',
                  'bindMenuRows','addMenuRow','saveMenu','initOwnerMap','saveVenueForm',
                  'ownerLoginMarkup','ownerRegisterMarkup','kpiCard'])
  t(`${fn}() gone from the web app`, !new RegExp('function '+fn+'\\s*\\(').test(js));
t('no owner tabs left', !/tab_venue_events|tab_menu_builder|tab_venue_settings/.test(js));
t('no cafe_owner branching left', !/cafe_owner/.test(js));
t('no owner auth views', !/owner-login|owner-register/.test(js));
t('no dead owner form ids', !/hv-owner-login-btn|hv-reg-manager|hv-v-manager/.test(js));
t('no menuDraft state', !/menuDraft/.test(js));
// The owner link was REMOVED from the guest auth wall on purpose (v1.9.1):
// owners reach the portal directly, guests should only see one door.
t('auth wall no longer shows an owner link', !/BOOT\.ownerPanelUrl/.test(js));
t('dead ownerPanelUrl boot value dropped',
  !/'ownerPanelUrl'/.test(rd('includes/class-havato-shortcode.php')));
t('dead .hv-auth-foot styles dropped', !/hv-auth-foot/.test(rd('assets/css/havato-app.css')));
t('owners can still reach the portal (shortcode intact)',
  /havato_owner_auth/.test(rd('includes/class-havato-owner-auth.php')));
t('wp-login still redirects owners to it',
  /guard_wp_login/.test(rd('includes/class-havato-owner-auth.php')));
t('web app still has the 4 guest tabs',
  /nav-explore/.test(js)&&/nav-map/.test(js)&&/nav-chat/.test(js)&&/nav-profile/.test(js));

console.log('\n--- 2. wp-admin owner panel ---');
t('class loaded in admin', /class-havato-owner-admin\.php/.test(main) && /Havato_Owner_Admin::init\(\)/.test(main));
for (const [p,fn] of [['dashboard','page_dashboard'],['events','page_events'],
                      ['menu','page_menu'],['settings','page_settings'],['payouts','page_payouts']])
  t(`${p} page exists`, new RegExp('function '+fn).test(oa));
t('all owner submenus registered',
  ['havato-venue','havato-venue-events','havato-venue-menu','havato-venue-settings','havato-venue-payouts']
    .every(p=>new RegExp("'"+p+"'\\s*=>\\s*array\\(").test(oa)));
t('the new "My tables" page is among them', /'havato-venue-tables'/.test(oa));
t('reuses the REST controllers, no duplicated logic',
  /Havato_REST::owner_create_event/.test(oa) && /Havato_REST::owner_checkin/.test(oa) &&
  /Havato_REST::owner_save_venue/.test(oa) && /Havato_REST::owner_save_menu/.test(oa));
t('all forms nonce-protected', /check_admin_referer\( 'havato_owner'/.test(oa));
t('POST handler rejects non-owners', /! self::is_owner\(\) && ! current_user_can\( 'manage_options' \)/.test(oa));
t('check-in toggle present', /havato_action" value="checkin/.test(oa) || /'checkin'/.test(oa));
t('menu builder JS', /initMenu/.test(oj));
t('media library for photos', /wp\.media/.test(oj) && /wp_enqueue_media/.test(oa));
t('draggable pin writes to inputs', /marker\.on\('dragend'/.test(oj) && /hv-owner-lat/.test(oj));
t('leaflet tiles unclamped in admin', /#hv-owner-map img \{ max-width: none !important/.test(rd('assets/css/havato-admin.css')));
t('payouts show share only, never platform revenue',
  /rebuild_venue\( \$venue\['id'\] \)/.test(oa) && !/payout_gross/.test(oa));
t('shared stat-card widget', /Havato_Admin_UI::stat_card/.test(oa));

console.log('\n--- 3. role lockdown ---');
t('owner detection excludes admins', /current_user_can\( 'manage_options' \)[\s\S]{0,40}return false/.test(oa));
t('foreign menus removed', /function restrict_menus/.test(oa));
t('only Havato + profile allowed', /\$allowed = array\( 'havato-venue', 'profile\.php' \)/.test(oa));
t('dashboard/editor blocked', /function block_dashboard/.test(oa));
t('non-Havato admin.php redirected', /0 !== strpos\( \$page, 'havato-venue' \)/.test(oa));
t('uploads still reachable', /async-upload\.php/.test(oa));
t('admin bar trimmed', /function clean_admin_bar/.test(oa));
t('login lands on the panel', /function login_redirect/.test(oa));
t('gatherers bounced out of wp-admin', /function block_gatherers/.test(roles));
t('gatherer uploads still work', /async-upload\.php/.test(roles));
{
  // who can reach what?
  const can=(role,page)=>{
    if(role==='admin') return true;
    if(role==='cafe_owner') return page.startsWith('havato-venue')||page==='profile.php';
    return false; // gatherer
  };
  t('owner -> own panel', can('cafe_owner','havato-venue-events'));
  t('owner -> own profile', can('cafe_owner','profile.php'));
  t('owner BLOCKED from platform admin', !can('cafe_owner','havato-revenue'));
  t('owner BLOCKED from posts', !can('cafe_owner','edit.php'));
  t('gatherer BLOCKED entirely', !can('gatherer','havato-venue'));
  t('admin keeps full access', can('admin','edit.php'));
}

console.log('\n--- 4. cafés can still be onboarded ---');
t('admin has a create-café form', /function render_new_venue_form/.test(adm));
t('wired to owner_register', /Havato_REST::owner_register/.test(adm));
t('admin session restored after the call', /wp_set_auth_cookie\( \$admin_id, true \)/.test(adm));
t('password not mangled by sanitising', /Not sanitised: a password must survive verbatim/.test(adm));
t('owner_register endpoint still registered', /'owner\/register'/.test(rest));
t('i18n owner_panel bilingual', /'owner_panel'[^\n]*'fa' =>[^\n]*'en' =>/.test(i18n));

console.log(f?`\n❌ ${f} failure(s)`:'\n✅ owner panel moved to wp-admin, mobile portal removed, role locked down');
process.exit(f?1:0);
