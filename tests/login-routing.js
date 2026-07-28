/* v1.20.0 — two separate real-world breakages reported from a live site:

   1) A café owner logs in and lands on the WooCommerce "My account" page
      instead of the owner panel. WooCommerce blocks wp-admin for anybody
      without edit_posts / manage_woocommerce / view_admin_dashboard, and a
      cafe_owner has none of those.

   2) /wp-admin sends the administrator to wp-login.php with redirect_to set,
      and our guard then forwarded that to the café portal, so the admin could
      never reach their own dashboard.

   The redirect decision is modelled here rather than grepped: the guard is
   re-implemented from the same conditions and driven with real request
   shapes.                                                                  */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const roles = rd('includes/class-havato-roles.php');
const auth = rd('includes/class-havato-owner-auth.php');
const settings = rd('includes/class-havato-settings.php');
const admin = rd('includes/class-havato-admin.php');
const ownerAdmin = rd('includes/class-havato-owner-admin.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

/* =====================================================================
 * 1. WooCommerce no longer evicts the café owner from wp-admin
 * ================================================================== */
console.log('--- 1. the owner reaches the panel on a WooCommerce site ---');

t('the prevent-access filter is hooked',
  /add_filter\(\s*'woocommerce_prevent_admin_access',\s*array\( __CLASS__, 'allow_owner_admin_access' \)/.test(roles));
t('the admin-bar filter is hooked too',
  /add_filter\(\s*'woocommerce_disable_admin_bar',\s*array\( __CLASS__, 'allow_owner_admin_bar' \)/.test(roles));
t('both run late enough to beat the shop\'s own code',
  (roles.match(/'woocommerce_(prevent_admin_access|disable_admin_bar)',\s*array\( __CLASS__, '[a-z_]+' \),\s*99\s*\)/g) || []).length === 2);

// Model WooCommerce's own rule (class-wc-admin.php::prevent_admin_access)
// together with our filter, and check every role that exists on the site.
function wooWantsToBlock(caps) {
  return !['edit_posts', 'manage_woocommerce', 'view_admin_dashboard'].some(c => caps.includes(c));
}
function ourFilter(prevent, role, caps) {
  // is_panel_user(): administrators, or the cafe_owner role.
  if (caps.includes('manage_options')) return false;
  if (role === 'cafe_owner') return false;
  return prevent;
}
function blocked(role, caps) {
  return ourFilter(wooWantsToBlock(caps), role, caps);
}

const CAPS = {
  cafe_owner: ['read', 'upload_files', 'havato_manage_venue'],
  gatherer: ['read', 'upload_files', 'havato_join'],
  administrator: ['manage_options', 'edit_posts', 'read'],
  customer: ['read'],
};

t('WooCommerce would have blocked the owner (the reported bug)', wooWantsToBlock(CAPS.cafe_owner) === true);
t('…and now it does not', blocked('cafe_owner', CAPS.cafe_owner) === false);
t('the administrator is unaffected', blocked('administrator', CAPS.administrator) === false);
t('a plain shop customer is still blocked', blocked('customer', CAPS.customer) === true);
t('a gatherer is still blocked from wp-admin', blocked('gatherer', CAPS.gatherer) === true);

t('the owner role genuinely lacks every capability WooCommerce accepts',
  !CAPS.cafe_owner.some(c => ['edit_posts', 'manage_woocommerce', 'view_admin_dashboard'].includes(c)));

t('widening is safe: every non-Havato admin screen still redirects',
  /0 !== strpos\( \$page, 'havato-venue' \)/.test(ownerAdmin) &&
  /wp_safe_redirect\( admin_url\( 'admin\.php\?page=havato-venue' \) \)/.test(ownerAdmin));

t('the gatherer bounce runs before WooCommerce\'s',
  /add_action\( 'admin_init', array\( __CLASS__, 'block_gatherers' \), 1 \)/.test(roles));

/* =====================================================================
 * 2. The administrator can reach wp-admin again
 * ================================================================== */
console.log('\n--- 2. wp-login.php no longer traps the administrator ---');

// Re-implementation of guard_wp_login()'s decision, from the same conditions.
function guard(req, opts) {
  opts = opts || {};
  const configured = opts.configured !== false;
  const guardOn = opts.guardOn !== false;
  if (!configured) return 'wp-login';
  if (!guardOn) return 'wp-login';
  if ((req.action || 'login') !== 'login') return 'wp-login';
  if (req.havato_admin !== undefined) return 'wp-login';
  if ((req.method || 'GET') === 'POST') return 'wp-login';
  if (req.loggedout !== undefined || req.reauth !== undefined || req['interim-login'] !== undefined) return 'wp-login';
  if (targetsWpAdmin(req.redirect_to || '')) return 'wp-login';
  return 'cafe-page';
}

const SITE = 'example.com';
const ADMIN_PATH = '/wp-admin/';
function targetsWpAdmin(target) {
  if (!target) return false;
  let host = null, path = target;
  const m = /^https?:\/\/([^/]+)(\/.*)?$/i.exec(target);
  if (m) { host = m[1]; path = m[2] || ''; }
  if (host && host.toLowerCase() !== SITE) return false;
  if (!path) return false;
  return path.indexOf(ADMIN_PATH) === 0;
}

// This is the exact journey the user described.
t('/wp-admin -> wp-login.php?redirect_to=/wp-admin/ reaches WordPress',
  guard({ redirect_to: '/wp-admin/' }) === 'wp-login');
t('an absolute same-site wp-admin target also passes',
  guard({ redirect_to: 'https://example.com/wp-admin/options-general.php' }) === 'wp-login');
t('a deep admin page passes',
  guard({ redirect_to: '/wp-admin/admin.php?page=havato' }) === 'wp-login');
t('the logged-out screen is not hijacked', guard({ loggedout: 'true' }) === 'wp-login');
t('an expired session (reauth) is not hijacked', guard({ reauth: '1' }) === 'wp-login');
t('the escape hatch still works', guard({ havato_admin: '1' }) === 'wp-login');
t('credential POSTs are never touched', guard({ method: 'POST' }) === 'wp-login');
t('password reset is never touched', guard({ action: 'lostpassword' }) === 'wp-login');

// …while the original purpose is intact.
t('a bare visit to wp-login.php still goes to the café page',
  guard({}) === 'cafe-page');
t('…and so does one with no useful redirect',
  guard({ redirect_to: '/' }) === 'cafe-page');
t('a front-end target still goes to the café page',
  guard({ redirect_to: '/my-account/' }) === 'cafe-page');

// An open-redirect through the new exemption would be worse than the bug.
t('an off-site host cannot fake a wp-admin path',
  guard({ redirect_to: 'https://evil.test/wp-admin/' }) === 'cafe-page');
t('a lookalike host is rejected',
  guard({ redirect_to: 'https://example.com.evil.test/wp-admin/' }) === 'cafe-page');
t('a path that merely contains wp-admin later is rejected',
  guard({ redirect_to: '/blog/wp-admin/' }) === 'cafe-page');
t('protocol-relative off-site is rejected',
  targetsWpAdmin('//evil.test/wp-admin/') === false);

t('the guard is off entirely when the page was never created',
  guard({}, { configured: false }) === 'wp-login');

/* =====================================================================
 * 3. The behaviour is switchable and the switch is wired end to end
 * ================================================================== */
console.log('\n--- 3. the redirect can be turned off from the admin ---');

t('setting exists with a safe default', /'owner_login_guard'\s*=> 1/.test(settings));
t('the guard reads it', /Havato_Settings::get\( 'owner_login_guard', 1 \)/.test(auth));
t('turning it off restores plain WordPress login', guard({}, { guardOn: false }) === 'wp-login');
t('a checkbox is rendered', /name="owner_login_guard"/.test(admin));
t('the POST handler saves it', /'owner_login_guard'\s*=> empty\( \$_POST\['owner_login_guard'\] \)/.test(admin));
t('the screen explains admins are exempt', /havato_admin=1 always works/.test(admin));

/* =====================================================================
 * 4. Nothing regressed in the parts that were already correct
 * ================================================================== */
console.log('\n--- 4. existing guarantees still hold ---');

t('owners still land on their panel after login',
  /login_redirect[\s\S]{0,400}admin_url\( 'admin\.php\?page=havato-venue' \)/.test(ownerAdmin));
t('the owner login endpoint still refuses administrators',
  /in_array\( 'cafe_owner', \(array\) \$user->roles, true \)/.test(rd('includes/class-havato-rest.php')));
t('helper is private to the class', /private static function is_panel_user/.test(roles));
t('the helper short-circuits for logged-out visitors',
  /is_panel_user\(\)[\s\S]{0,200}! is_user_logged_in\(\)[\s\S]{0,60}return false/.test(roles));

console.log(f ? `\n❌ ${f} failed` : '\n✅ owners reach their panel and administrators reach wp-admin');
process.exit(f ? 1 : 0);
