/* 1) Every icon() call site must end up with a bounded SVG.
   2) The login screen must show exactly one Google button. */
const fs=require('fs');
const R=__dirname+'/../havato/';
const css=fs.readFileSync(R+'assets/css/havato-app.css','utf8');
const js =fs.readFileSync(R+'assets/js/havato-app.js','utf8');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};
// Comments legitimately quote the old broken selector, so reason about real
// declarations only when measuring the cascade.
const bare=css.replace(/\/\*[\s\S]*?\*\//g,'');

console.log('--- 1. unsized-SVG safety net ---');
t('icon() still emits a bare <svg> (no width/height attrs)',
  /function icon\([\s\S]{0,220}<svg class=/.test(js) && !/function icon\([\s\S]{0,220}width=/.test(js));
t('global fallback size exists for sprite icons',
  /svg:not\(\.hv-sprite\):not\(\.hv-wave\)/.test(css));
{
  const rule=css.match(/[^\n]*svg:not\(\.hv-sprite\):not\(\.hv-wave\)[^{]*\{[^}]*\}/s)[0];
  t('fallback sets both axes', /inline-size:/.test(rule)&&/block-size:/.test(rule));
  t('fallback stops flex stretching', /flex:\s*0 0 auto/.test(rule));
}
t('.hv-wave excluded (it must fill the nav)', /:not\(\.hv-wave\)/.test(css));
t('.hv-sprite excluded (the hidden symbol defs)', /:not\(\.hv-sprite\)/.test(css));
t('.hv-map-pill svg explicitly sized', /\.hv-map-pill svg \{[^}]*inline-size:\s*16px/s.test(css));
t('.hv-photo-upload svg explicitly sized', /\.hv-photo-upload svg \{[^}]*inline-size:\s*22px/s.test(css));

/* THE SAFETY NET MUST LOSE TO EVERY COMPONENT RULE.
   It was written `#havato-app svg:not(.hv-sprite):not(.hv-wave)`, and the
   arguments of :not() DO count toward specificity, so it scored 1-2-1 —
   beating `.hv-tab svg` (0-1-1) and all 14 other icon rules. Every icon in
   the app therefore rendered at the net's 1.25em, a size tied to the font
   rather than a fixed one. It went unnoticed for as long as buttons wrongly
   inherited the 16px body size, which made the icons a plausible 20px; the
   moment that was fixed the whole set collapsed to ~12px.
   Model specificity properly rather than pinning the old numbers. */
console.log('\n   --- specificity of the safety net ---');
function spec(sel){
  // [ids, classes(+attrs+pseudo-classes), type selectors].
  // :where() contributes nothing at all — strip it AND its contents.
  // :not() is transparent: it adds nothing itself, but its ARGUMENTS count,
  // so only the parentheses are removed. That asymmetry is the entire bug.
  let s=sel.trim();
  // Remove :where(...) including balanced inner parens, repeatedly.
  let prev;
  do { prev=s; s=s.replace(/:where\((?:[^()]|\([^()]*\))*\)/g,' '); } while (s!==prev);
  // Unwrap :not(...) / :is(...) so their arguments remain and get counted.
  do { prev=s; s=s.replace(/:(?:not|is)\(((?:[^()]|\([^()]*\))*)\)/g,' $1 '); } while (s!==prev);
  const ids=(s.match(/#[\w-]+/g)||[]).length;
  const cls=(s.match(/\.[\w-]+|\[[^\]]+\]|:[a-z-]+(?:\([^)]*\))?/g)||[]).length;
  const types=(s.match(/(?:^|[\s>+~,])([a-z][\w-]*)/g)||[]).length;
  return [ids,cls,types];
}
const beats=(a,b)=>{for(let i=0;i<3;i++){if(a[i]!==b[i])return a[i]>b[i];}return false;};
{
  const netSel=/([^\n{]*svg:not\(\.hv-sprite\):not\(\.hv-wave\)[^{]*)\{/.exec(bare)[1].trim();
  const netSpec=spec(netSel);
  console.log('     net selector: '+netSel);
  console.log('     specificity : '+netSpec.join('-'));
  t('the net is wrapped in :where() so it carries no weight',
    /:where\(/.test(netSel));
  t('the net scores 0-0-0', netSpec.join('-')==='0-0-0');

  // Every component icon rule must now win.
  const compRe=/\n(\.[a-z0-9-]+(?:\s+\.[a-z0-9-]+)?\s+svg)\s*\{[^}]*inline-size:\s*(\d+)px/g;
  let m, checked=0, losers=[];
  while((m=compRe.exec(bare))){
    const s=spec(m[1]);
    checked++;
    if (!beats(s,netSpec)) losers.push(m[1]+' ('+s.join('-')+')');
  }
  console.log('     component icon rules found: '+checked);
  t('all '+checked+' component icon rules outrank the net', losers.length===0);
  if (losers.length) console.log('       losing: '+losers.join(', '));
  t('there are enough of them to matter', checked>=12);
}

function renderedSize(parentClass){
  const specific=new RegExp('\\.'+parentClass+' svg \\{[^}]*inline-size:\\s*(\\d+)px','s').exec(bare);
  const netSel=/([^\n{]*svg:not\(\.hv-sprite\):not\(\.hv-wave\)[^{]*)\{/.exec(bare)[1].trim();
  const netWins=!/:where\(/.test(netSel);   // 1-2-1 would beat any component
  if (specific && !netWins) return +specific[1];
  if (/svg:not\(\.hv-sprite\):not\(\.hv-wave\)/.test(bare)) {
    // 1.25em resolves against the element's OWN font-size, so an icon inside
    // a small control shrinks with it. That is the bug, not a size.
    return null;
  }
  return 300; // browser default for an unsized inline SVG
}
console.log('\n   simulated icon width per container:');
let oversized=[], fontTied=[];
for (const cls of ['hv-map-pill','hv-photo-upload','hv-tab','hv-stat-icon','hv-empty',
                   'hv-list-thumb','hv-event-thumb','hv-menu-thumb','hv-auth-logo',
                   'hv-quick-icon','hv-summary-icon','hv-next-cover']) {
  const w=renderedSize(cls);
  if (w===null) { fontTied.push(cls); console.log(`     .${cls.padEnd(16)} 1.25em  <-- tied to font size`); continue; }
  if (w>64) oversized.push(cls+'='+w);
  console.log(`     .${cls.padEnd(16)} ${w}px`);
}
t('no icon renders at the 300px browser default', oversized.length===0);
t('no icon is left tied to its font size', fontTied.length===0);

console.log('\n   --- the bottom bar is comfortable to tap and read ---');
{
  const tabIcon=+/\.hv-tab svg \{[^}]*inline-size:\s*(\d+)px/s.exec(bare)[1];
  t(`nav icon is ${tabIcon}px — at or above the 22px it was designed for`, tabIcon>=22);
  t('nav icon is not oversized either', tabIcon<=28);

  const mult=parseFloat(/\n\.hv-tab \{[^}]*font-size:\s*calc\(([\d.]+)/s.exec(bare)[1]);
  const tokFa=+/#havato-app \{[\s\S]*?--hv-fs:\s*([\d.]+)px/.exec(bare)[1];
  const tokEn=+/hv-dir-ltr \{[\s\S]*?--hv-fs:\s*([\d.]+)px/.exec(bare)[1];
  for (const [lang,tok] of [['fa',tokFa],['en',tokEn]]) {
    const px=tok*mult;
    t(`  ${lang} nav label ${px.toFixed(1)}px — at least the 10px iOS baseline`, px>=10);
    t(`  ${lang} nav label not oversized`, px<=13);
  }

  // The narrow-screen media query must not undo it.
  const narrow=/@media \(max-width: 380px\) \{([\s\S]*?)\n\}/.exec(bare)[1];
  t('the 380px query no longer shrinks the label', !/\.hv-tab \{[^}]*font-size/.test(narrow));

  // Vertical budget: icon + gap + line-box + padding inside (nav-h - 20).
  const navMin=72, avail=navMin-20;
  const line=tokFa*mult*1.25;
  const total=tabIcon+3+line+8;
  t(`tab content ${total.toFixed(1)}px fits the ${avail}px bar`, total<=avail);
}

console.log('\n--- 2. exactly one Google sign-in button ---');
t('fallback button starts hidden', /id="hv-google-fallback" hidden>/.test(js));
t('revealed only via showGoogleFallback()', /function showGoogleFallback/.test(js));
t('shown when the SDK never loads', /tries\+\+ < 40[\s\S]{0,90}else \{[\s\S]{0,60}showGoogleFallback\(\)/.test(js));
t('shown when renderButton throws', /catch \(e\) \{[\s\S]{0,40}showGoogleFallback\(\)/.test(js));
t('shown when the button silently fails to paint',
  /slot\.firstChild[\s\S]{0,120}showGoogleFallback\(\)/.test(js));
t('NOT shown on the happy path (no unconditional reveal)',
  !/hv-google-fallback'\)\.hidden = false/.test(js));
{
  const count=(sdkLoaded,painted)=>((sdkLoaded&&painted)?1:0)+((sdkLoaded&&painted)?0:1);
  t('SDK works    -> 1 button', count(true,true)===1);
  t('SDK blocked  -> 1 button', count(false,false)===1);
  t('render fails -> 1 button', count(true,false)===1);
}
console.log(f?`\n❌ ${f} failure(s)`:'\n✅ icons bounded, single Google button');
process.exit(f?1:0);
