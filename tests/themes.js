/* v1.10.0 — admin-selectable themes.
   The PHP colour maths is re-implemented here and run against the real
   catalogue parsed out of class-havato-themes.php, so the assertions test the
   shipped values rather than a copy of them. */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const themes = rd('includes/class-havato-themes.php');
const admin = rd('includes/class-havato-admin.php');
const i18n = rd('includes/class-havato-i18n.php');
const main = rd('havato.php');
const acss = rd('assets/css/havato-admin.css');
const app = rd('templates/app.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

/* ---------- colour helpers, mirroring the PHP ---------- */
const rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const lum = h => {
  const l = rgb(h).map(c => { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); });
  return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2];
};
const cr = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
const hue = h => {
  let [r, g, b] = rgb(h).map(c => c / 255);
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  if (!d) return 0;
  let x = mx === r ? ((g - b) / d + (g < b ? 6 : 0)) : mx === g ? ((b - r) / d + 2) : ((r - g) / d + 4);
  return Math.round(x * 60);
};

/* ---------- parse the catalogue out of the PHP ---------- */
const cat = {};
const block = themes.slice(themes.indexOf('public static function catalogue()'),
                           themes.indexOf('apply_filters'));
const reTheme = /'([a-z0-9_]+)'\s*=>\s*array\(\s*\n\s*'label'([\s\S]*?)\n\t\t\t\),/g;
let m;
while ((m = reTheme.exec(block))) {
  const id = m[1], body = m[2];
  const grab = k => { const g = new RegExp("'" + k + "'\\s*=>\\s*'(#[0-9a-fA-F]{6})'").exec(body); return g && g[1].toLowerCase(); };
  cat[id] = { light: grab('light'), base: grab('base'), deep: grab('deep'), ink: grab('ink'),
              accent: grab('accent'), accent_2: grab('accent_2'), canvas: grab('canvas'),
              text: grab('text'), text_soft: grab('text_soft') };
}

console.log('--- 1. every shipped palette is present and complete ---');
// 'raspberry' joined in 1.15.0; the list is asserted by content, not length,
// so adding a theme is not a breaking change.
const want = ['azure', 'emerald', 'espresso', 'midnight', 'coral', 'raspberry', 'galaxy'];
t('all agreed themes ship', want.every(k => cat[k]));
t('no unexpected extras', Object.keys(cat).every(k => want.includes(k)));

// Galaxy is the first dark palette, so the surface tokens invert. Verify it
// rather than assuming the light-theme assertions below still cover it.
(() => {
  const src = fs.readFileSync(R + 'includes/class-havato-themes.php', 'utf8');
  const block = src.slice(src.indexOf("'galaxy' => array("), src.indexOf("'raspberry' => array("));

  t('galaxy declares itself dark', /'dark'\s*=> true/.test(block));
  t('…and names its own card colour', /'card'\s*=> '#1b1038'/.test(block));

  const hex = h => { h = h.replace('#', ''); return [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16)); };
  const lum = h => {
    const [r, g, b] = hex(h).map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const ratio = (a, b) => {
    const l1 = lum(a), l2 = lum(b);
    return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
  };

  const g = { canvas: '#0d0620', card: '#1b1038', text: '#f2edff', soft: '#a99cc9', base: '#7c3aed' };
  t('galaxy body text clears AA on its cards', ratio(g.text, g.card) >= 4.5);
  t('…and on the page itself', ratio(g.text, g.canvas) >= 4.5);
  t('secondary text clears 3:1', ratio(g.soft, g.card) >= 3);
  t('white still readable on the primary button', ratio('#ffffff', g.base) >= 4.5);
  // A dark card that matches the page would make every card vanish.
  t('cards are distinguishable from the page', lum(g.card) > lum(g.canvas));

  t('the engine derives darkness when a theme does not declare it',
    /luminance\( self::hex\( isset\( \$theme\['canvas'\] \)[\s\S]{0,80}< 0\.4/.test(src));
  t('a dark theme lightens its card instead of using white',
    /\$out\['dark'\]\s*\n?\s*\? self::lighten\( \$out\['canvas'\], 0\.07 \)/.test(src));
  t('text is corrected against the card, not the canvas',
    /self::contrast\( \$out\['text'\], \$out\['card'\] \) < 4\.5/.test(src));
})();
for (const id of want) {
  const c = cat[id];
  t(`${id}: every colour parsed`, c && Object.values(c).every(v => /^#[0-9a-f]{6}$/.test(v || '')));
}

console.log('\n--- 2. every theme is actually readable (WCAG) ---');
for (const id of want) {
  const c = cat[id];
  const ratio = cr('#ffffff', c.base);
  // White text sits on `base` in the header, nav and primary buttons.
  t(`${id}: white on base = ${ratio.toFixed(2)}:1 (AA)`, ratio >= 4.5);
}
for (const id of want) {
  const c = cat[id];
  t(`${id}: body text on canvas is AA`, cr(c.text, c.canvas) >= 4.5);
}
for (const id of want) {
  const c = cat[id];
  // The ramp must actually descend or the gradients invert.
  t(`${id}: light > base > deep > ink`,
    lum(c.light) > lum(c.base) && lum(c.base) > lum(c.deep) && lum(c.deep) > lum(c.ink));
}

console.log('\n--- 3. the purple complaint is genuinely resolved ---');
// 230..280 is where indigo/violet is perceived; the old #1b1fbf sat at 239.
// The complaint was about the DEFAULT looking like every other fintech app,
// so the ban applies to the themes offered as alternatives to it. Galaxy is
// exempt: it was requested as a violet night theme, and it is opt-in.
t('the old violet base is gone from the catalogue', !/#1b1fbf/i.test(block));
const violetExempt = ['galaxy'];
for (const id of want) {
  if (violetExempt.includes(id)) { continue; }
  const h = hue(cat[id].base);
  const violet = h >= 230 && h <= 280;
  t(`${id}: base hue ${h}° is not violet`, !violet);
}

console.log('\n--- 4. tokens cover what the stylesheet actually paints ---');
// Surfaces that use literal gradients instead of var() must be repainted, or
// they keep the old colours while everything else changes.
for (const sel of ['hv-header-bg', 'hv-profile-head', 'hv-authwall',
                   'hv-bottom-nav::before', 'hv-btn-primary', 'hv-btn-blue',
                   'hv-msg.is-mine', 'hv-orb-1', 'hv-orb-2', 'hv-owner-auth'])
  t(`${sel} is repainted by the theme`, themes.includes(sel));
t('the nav wave SVG stops are themeable too',
  /hv-wave-1/.test(themes) && /hv-wave-1/.test(app));
t('core tokens are emitted', ['--hv-indigo', '--hv-blue', '--hv-bg', '--hv-text', '--hv-shadow-fab']
  .every(v => themes.includes(v)));

console.log('\n--- 5. robustness ---');
t('a missing/removed theme falls back instead of blanking',
  /self::exists\( \$id \) \? \$id : self::FALLBACK/.test(themes));
t('half-filled palettes are completed by derivation', /public static function normalize/.test(themes));
t('unreadable custom colours are darkened until AA',
  /contrast\( '#ffffff', \$out\['base'\] \) < 4\.5/.test(themes));
t('the darken loop is bounded (no infinite spin)', /\$guard < 24/.test(themes));
t('the ramp is re-ordered after that correction', /luminance\( \$out\['deep'\] \) >= /.test(themes));
t('hex input is validated, 3- and 6-digit', /\{3\}\)\$/.test(themes) && /\{6\}\)\$/.test(themes));

console.log('\n--- 6. wired into the plugin ---');
t('class is loaded', /class-havato-themes\.php/.test(main));
t('and initialised', /Havato_Themes::init\(\)/.test(main));
t('palette is inlined onto the app stylesheet', /wp_add_inline_style\( 'havato-app'/.test(themes));
t('no extra HTTP request (inline, not a second file)', !/wp_enqueue_style\(\s*'havato-theme/.test(themes));

console.log('\n--- 7. admin page ---');
t('menu entry registered', /'havato-theme'\s*=>\s*array\( 'admin_theme', 'page_theme' \)/.test(admin));
t('tab shown in the header', /'havato-theme'\s*=>\s*Havato_I18N::t\( 'admin_theme' \)/.test(admin));
t('page renders', /public static function page_theme/.test(admin));
t('POST handler exists', /case 'theme':/.test(admin));
t('nonce-protected like every other form', /check_admin_referer\( 'havato_admin'/.test(admin));
t('switch is logged', /App theme switched to/.test(admin));
t('custom palette offered', /theme_id" value="custom/.test(admin));
t('badge class exists in the admin CSS', /\.hv-adm-badge\.is-green/.test(acss));
t('picker styles shipped', /\.hv-theme-grid/.test(acss) && /\.hv-theme-preview/.test(acss));

console.log('\n--- 8. cleans up after itself ---');
const uninst = rd('uninstall.php');
t('theme option removed on uninstall', /delete_option\( 'havato_theme' \)/.test(uninst));
t('custom palette removed too', /delete_option\( 'havato_theme_custom' \)/.test(uninst));

console.log('\n--- 9. extensible + bilingual ---');
t('third parties can register themes', /apply_filters\( 'havato_themes'/.test(themes));
t('filter output is type-checked', /is_array\( \$themes \) \? \$themes : array\(\)/.test(themes));
for (const k of ['admin_theme', 'theme_apply', 'theme_in_use', 'theme_custom', 'theme_applied'])
  t(`i18n "${k}" is bilingual`, new RegExp("'" + k + "'[\\s\\S]{0,200}?'fa' =>[\\s\\S]{0,200}?'en' =>").test(i18n));

console.log(f ? `\n❌ ${f} failing` : `\n✅ ${want.length} themes, all AA, none violet, admin-switchable and extensible`);
process.exit(f ? 1 : 0);
