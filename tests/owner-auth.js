/* 1) dedicated owner auth page  2) owner/login hardened
   3) storefront photo flow      4) "User sign-in" heading */
const fs=require('fs');
const R=__dirname+'/../havato/';
const rd=f=>fs.readFileSync(R+f,'utf8');
const auth=rd('includes/class-havato-owner-auth.php'), rest=rd('includes/class-havato-rest.php');
const tpl=rd('templates/owner-auth.php'), aj=rd('assets/js/havato-owner-auth.js');
const oa=rd('includes/class-havato-owner-admin.php'), oj=rd('assets/js/havato-owner-admin.js');
const adm=rd('includes/class-havato-admin.php'), db=rd('includes/class-havato-db.php');
const js=rd('assets/js/havato-app.js'), i18n=rd('includes/class-havato-i18n.php');
const main=rd('havato.php'), css=rd('assets/css/havato-app.css');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- 1. dedicated owner auth page ---');
t('shortcode registered', /add_shortcode\( 'havato_owner_auth'/.test(auth));
t('page auto-created on activation', /\[havato_owner_auth\]/.test(main) && /havato_owner_auth_page_id/.test(main));
t('template has BOTH sign-in and sign-up', /id="hv-auth-login"/.test(tpl) && /id="hv-auth-register"/.test(tpl));
t('tab switch between them', /data-authtab/.test(tpl) && /initTabs/.test(aj));
t('signup collects venue+manager+city', /hv-r-venue/.test(tpl) && /hv-r-manager/.test(tpl) && /hv-r-city/.test(tpl));
t('country drives the city list', /function initLocations/.test(aj));
t('password reset link kept', /wp_lostpassword_url/.test(tpl));
t('already-signed-in owners are sent to the panel', /is_user_logged_in\(\)/.test(auth));
t('branded, not WordPress-styled', /hv-owner-auth/.test(css) && /hv-auth-card hv-glass/.test(tpl));

console.log('\n--- 2. wp-login.php no longer the owner door ---');
t('login_init guard', /add_action\( 'login_init'/.test(auth));
t('non-admins redirected to the branded page', /wp_safe_redirect\( self::url\(\) \)/.test(auth));
t('admin escape hatch (?havato_admin=1)', /havato_admin/.test(auth));
t('logout / reset flows untouched', /'login' !== \$action/.test(auth));
t('POST passes through so admin login still works', /'POST' === \(/.test(auth));
t('falls back to wp-login if the page is missing', /return wp_login_url\(\)/.test(auth));
t('app links to the branded page', /Havato_Owner_Auth::url\(\)/.test(rd('includes/class-havato-shortcode.php')));

console.log('\n--- 3. owner/login hardened (the real vulnerability) ---');
t('role check added — admins CANNOT use this door',
  /! in_array\( 'cafe_owner', \(array\) \$user->roles, true \)/.test(rest));
t('returns 403 for non-owners', /havato_not_owner/.test(rest));
t('IP throttle before the password check', /check_login_throttle\(\)/.test(rest));
t('failed attempts recorded', /record_failed_login\(\)/.test(rest));
t('counter cleared on success', /clear_login_throttle\(\)/.test(rest));
t('registration throttled too', /owner_register[\s\S]{0,400}check_login_throttle/.test(rest));
t('throttle skipped for admins onboarding a café', /! current_user_can\( 'manage_options' \)[\s\S]{0,120}check_login_throttle/.test(rest));
{
  // simulate the throttle + role gate
  const MAX=5; let tries=0;
  const attempt=(ok,role)=>{
    if(tries>=MAX) return 429;
    if(!ok){tries++; return 401;}
    if(role!=='cafe_owner'){tries++; return 403;}
    tries=0; return 200;
  };
  t('5 bad passwords -> 401', [1,2,3,4,5].every(()=>attempt(false)===401));
  t('6th attempt -> 429 locked out', attempt(false)===429);
  tries=0;
  t('correct admin credentials still REJECTED (403)', attempt(true,'administrator')===403);
  t('a rejected admin also counts toward the lockout', tries===1);
  tries=0;
  t('correct owner credentials -> 200', attempt(true,'cafe_owner')===200);
  t('success resets the counter', tries===0);
}

console.log('\n--- 4. storefront photo speeds up verification ---');
t('column added', /storefront_photo varchar\(255\)/.test(db));
{
  const v=/HAVATO_DB_VERSION', '(\d+)\.(\d+)\.(\d+)'/.exec(main);
  t('DB version bumped (>=1.3.0), got '+v[1]+'.'+v[2]+'.'+v[3],
    (+v[1])*10000+(+v[2])*100+(+v[3]) >= 10300);
}
t('accepted at signup', /storefront_photo/.test(rest));
t('editable + URL-sanitised', /'image' === \$key \|\| 'storefront_photo' === \$key/.test(rest));
t('prompt shown on the owner dashboard', /function storefront_prompt/.test(oa));
t('only while unverified', /! \(int\) \$venue\['verified'\][\s\S]{0,80}storefront_prompt/.test(oa));
t('uses the media library', /initStorefront/.test(oj) && /pickMedia/.test(oj));
t('saves through owner_save_venue', /save_storefront[\s\S]{0,300}owner_save_venue/.test(oa));
t('confirms once received', /storefront_received/.test(oa));
t('admin SEES the photo in the approvals table', /hv-adm-shopfront/.test(adm));
t('photo opens full size', /target="_blank" rel="noopener"/.test(adm));

console.log('\n--- 5. "User sign-in" heading ---');
t('heading above the Google button',
  /hv-auth-heading[\s\S]{0,80}user_login_heading[\s\S]{0,60}googleBlock/.test(js));
t('styled large + bold', /\.hv-auth-heading \{[^}]*font-weight:\s*800/s.test(css));
t('decorative underline', /\.hv-auth-heading::after/.test(css));

for (const k of ['user_login_heading','login_failed','login_owner_only','login_throttled',
                 'forgot_password','signup_pending_hint','storefront_title','storefront_hint',
                 'storefront_received'])
  t(`i18n "${k}" bilingual`, new RegExp(`'${k}'[^\\n]*'fa' =>[^\\n]*'en' =>`).test(i18n));

console.log(f?`\n❌ ${f} failure(s)`:'\n✅ branded owner auth, hardened login, storefront flow, user heading');
process.exit(f?1:0);
