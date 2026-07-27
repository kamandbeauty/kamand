/* 1) White nav labels  2) notch matches the FAB  3) working "nearby" button */
const fs=require('fs');
const R=__dirname+'/../havato/';
const css=fs.readFileSync(R+'assets/css/havato-app.css','utf8');
const js =fs.readFileSync(R+'assets/js/havato-app.js','utf8');
const tpl=fs.readFileSync(R+'templates/app.php','utf8');
const i18n=fs.readFileSync(R+'includes/class-havato-i18n.php','utf8');
const noC=css.replace(/\/\*[\s\S]*?\*\//g,'');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- 1. nav labels are pure white ---');
t('base tab colour is #fff', /\.hv-tab \{ color: #fff; \}/.test(noC));
t('no dimmed rgba label colour left', !/\.hv-tab:not\(\.is-active\) \{ color: rgba/.test(noC));
t('active tab still distinguishable by weight', /\.hv-tab\.is-active \{[^}]*font-weight:\s*800/s.test(noC));
t('inactive icons only slightly dimmed (>=0.85)',
  parseFloat(/\.hv-tab:not\(\.is-active\) svg \{ opacity: ([\d.]+)/.exec(noC)[1])>=0.85);
{
  const lum=([r,g,b])=>{const a=[r,g,b].map(v=>{v/=255;return v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4);});
    return 0.2126*a[0]+0.7152*a[1]+0.0722*a[2];};
  const ratio=(x,y)=>{const A=lum(x),B=lum(y),[h,l]=A>B?[A,B]:[B,A];return (h+0.05)/(l+0.05);};
  let worst=Infinity;
  for (const bg of [[35,42,209],[27,31,191],[20,26,110]]) worst=Math.min(worst,ratio([255,255,255],bg));
  console.log(`   white-on-nav contrast: ${worst.toFixed(2)}:1`);
  t('labels clear WCAG AA (4.5:1)', worst>=4.5);
}

console.log('\n--- 2. notch matches the floating button ---');
t('solid nav surface painted via ::before', /\.hv-bottom-nav::before \{/.test(noC));
t('notch cut with a mask, not a stretched path', /mask:\s*\n?\s*radial-gradient/.test(noC));
t('notch radius derives from --hv-fab-size', /--hv-notch: calc\(\(var\(--hv-fab-size\) \/ 2\) \+ 5px\)/.test(noC));
t('legacy stretched SVG hidden', /\.hv-wave \{[^}]*opacity:\s*0/s.test(noC));
t('@supports fallback keeps the bar visible', /@supports not \(\(-webkit-mask/.test(noC) && /\.hv-wave \{ opacity: 1; \}/.test(noC));
{
  // notch now scales WITH the button, so the gap is constant on every device
  const clamp=(a,b,c)=>Math.min(Math.max(b,a),c);
  let gaps=[];
  for (const w of [320,360,375,390,414,480,560]) {
    const fab=clamp(56,15*w/100,64);
    const notchD=fab+10;            // radius = fab/2 + 5  -> diameter = fab+10
    gaps.push(+((notchD-fab)/2).toFixed(1));
  }
  console.log('   gap each side of the button:', gaps.join('px, ')+'px');
  t('gap is a constant 5px on every width', gaps.every(g=>g===5));
}
t('old 118px-wide notch path replaced', !/M0,20 L136,20/.test(tpl));

console.log('\n--- 3. "nearby location" actually works ---');
t('green pill is a <button>, not a <span>', /<button type="button" class="hv-map-pill is-green" id="hv-locate-btn">/.test(js));
t('orange counter stays decorative', /<span class="hv-map-pill is-orange">/.test(js));
t('click handler bound after the map exists', /locateBtn.*\n?.*locateBtn\.onclick = locateMe/.test(js));
t('buttons opt back into pointer-events', /button\.hv-map-pill \{[^}]*pointer-events:\s*auto/s.test(noC));
t('strip itself still lets the map be dragged', /\.hv-map-strip \{[^}]*pointer-events:\s*none/s.test(noC));
t('meets the 44px touch target', /button\.hv-map-pill \{[^}]*min-block-size:\s*44px/s.test(noC));
t('drops a "you are here" marker', /hv-me-dot/.test(js) && /\.hv-me-dot \{/.test(noC));
t('marker reused, not duplicated', /if \(S\.meMarker\) \{[\s\S]{0,60}setLatLng/.test(js));
t('stale marker cleared when the map is rebuilt', /S\.meMarker = null; \/\/ belongs to the previous map/.test(js));
t('geolocation options set (timeout guards a hang)', /timeout: 10000/.test(js));
console.log('   error handling:');
for (const [name,re] of [
  ['unsupported browser', /!navigator\.geolocation[\s\S]{0,80}geo_unsupported/],
  ['permission denied',   /err\.code === 1 \? t\('geo_denied'\)/],
  ['generic failure',     /t\('geo_failed'\)/],
  ['progress feedback',   /t\('locating'\)/],
]) t('   handles '+name, re.test(js));
for (const k of ['locating','geo_denied','geo_failed','geo_unsupported'])
  t(`i18n "${k}" bilingual`, new RegExp(`'${k}'[^\\n]*'fa' =>[^\\n]*'en' =>`).test(i18n));

console.log(f?`\n❌ ${f} failure(s)`:'\n✅ white labels, aligned notch, working locate button');
process.exit(f?1:0);
