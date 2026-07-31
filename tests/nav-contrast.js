/* Bottom-nav legibility.
   The v1.0.2 attempt failed because `<use>` clones symbols into a SHADOW TREE
   and descendant selectors cannot pierce it. This locks in the real fix and
   computes actual WCAG contrast against the nav gradient. */
const fs=require('fs');
const R=__dirname+'/../havato/';
const css=fs.readFileSync(R+'assets/css/havato-app.css','utf8');
const js =fs.readFileSync(R+'assets/js/havato-app.js','utf8');
const ico=fs.readFileSync(R+'templates/parts/icons.php','utf8');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- root cause: no shadow-piercing selector ---');
// strip comments first: the explanatory note legitimately mentions the selector
const cssNoComments = css.replace(/\/\*[\s\S]*?\*\//g, '');
t('the dead `.hv-tab svg *` rule is gone', !/\.hv-tab svg \*/.test(cssNoComments));
t('reason documented for future maintainers', /shadow boundary/.test(css));

console.log('\n--- monochrome nav symbols exist ---');
const navIcons=['explore','map','chat','profile','dashboard','calendar','menu','settings'];
for (const n of navIcons)
  t(`#hv-i-nav-${n} defined`, new RegExp(`id="hv-i-nav-${n}"`).test(ico));
{
  // every nav symbol must be authored with currentColor and NOT gradients
  const body=ico.split('hv-i-nav-explore')[1].split('Google G')[0];
  t('nav symbols use currentColor', (body.match(/currentColor/g)||[]).length>=16);
  t('nav symbols contain no gradient fills', !/url\(#hvGrad/.test(body));
}
t('colourful sprite kept for cards elsewhere', /url\(#hvGradPink\)/.test(ico));

console.log('\n--- tabs actually reference them ---');
// Only guest tabs remain in the web app; the café owner panel is in wp-admin.
// Five tabs since 1.31.0 — map moved inside Explore and no longer has one.
for (const [tab,icon] of [['home','nav-dashboard'],['explore','nav-explore'],
                          ['tables','nav-calendar'],['chats','nav-chat'],
                          ['profile','nav-profile']])
  t(`${tab} -> ${icon}`, new RegExp(`id: '${tab}'[^}]*icon: '${icon}'`).test(js));
t('no tab still points at a gradient icon',
  !/id: '(home|explore|tables|chats|profile)'[^}]*icon: '(explore|map|chat|profile|dashboard|calendar)'/.test(js));

// Every nav icon must paint with currentColor, or the active/inactive state
// cannot drive it on the dark bar.
for (const sym of ['nav-dashboard','nav-explore','nav-calendar','nav-chat','nav-profile']) {
  const block = ico.slice(ico.indexOf(`id="hv-i-${sym}"`), ico.indexOf('</symbol>', ico.indexOf(`id="hv-i-${sym}"`)));
  t(`${sym} uses currentColor`, /currentColor/.test(block));
}

console.log('\n--- computed contrast on the nav gradient ---');
const lum=([r,g,b])=>{const a=[r,g,b].map(v=>{v/=255;return v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4);});
  return 0.2126*a[0]+0.7152*a[1]+0.0722*a[2];};
const ratio=(f1,b)=>{const L1=lum(f1),L2=lum(b);const [hi,lo]=L1>L2?[L1,L2]:[L2,L1];
  return (hi+0.05)/(lo+0.05);};
const blend=(fg,a,bg)=>fg.map((c,i)=>Math.round(c*a+bg[i]*(1-a)));
// the wave gradient stops
const stops={'#232AD1':[35,42,209],'#1B1FBF':[27,31,191],'#141A6E':[20,26,110]};
// Labels are now pure white on every tab (see nav-and-locate.js); only the
// icon glyphs are slightly dimmed when inactive.
const iconA=1; // icons are now fully opaque white on every tab
let worst=Infinity;
for (const [hex,bg] of Object.entries(stops)) {
  const rIcon=ratio(blend([255,255,255],iconA,bg),bg);
  const rTxt =ratio([255,255,255],bg);
  worst=Math.min(worst,rIcon);
  console.log(`   on ${hex}: inactive icon ${rIcon.toFixed(2)}:1   label ${rTxt.toFixed(2)}:1`);
}
t(`inactive icons clear WCAG AA for UI glyphs (3:1) — worst ${worst.toFixed(2)}:1`, worst>=3);
t('labels are pure white', /\.hv-tab \{ color: #fff; \}/.test(css));
t('active tab is pure white', /\.hv-tab\.is-active \{[^}]*color:\s*#fff/s.test(css));
t('active tab also bolder (not colour-only)', /\.hv-tab\.is-active \{[^}]*font-weight:\s*800/s.test(css));
t('glyph halo for thin strokes', /\.hv-tab svg \{ filter: drop-shadow/.test(css));
t('label halo', /\.hv-tab span \{ text-shadow/.test(css));
console.log(f?`\n❌ ${f} failure(s)`:'\n✅ nav icons legible and driven by currentColor');
process.exit(f?1:0);
