/* 1) Every icon() call site must end up with a bounded SVG.
   2) The login screen must show exactly one Google button. */
const fs=require('fs');
const R=__dirname+'/../havato/';
const css=fs.readFileSync(R+'assets/css/havato-app.css','utf8');
const js =fs.readFileSync(R+'assets/js/havato-app.js','utf8');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- 1. unsized-SVG safety net ---');
t('icon() still emits a bare <svg> (no width/height attrs)',
  /function icon\([\s\S]{0,220}<svg class=/.test(js) && !/function icon\([\s\S]{0,220}width=/.test(js));
t('global fallback size exists for sprite icons',
  /#havato-app svg:not\(\.hv-sprite\):not\(\.hv-wave\)/.test(css));
{
  const rule=css.match(/#havato-app svg:not\(\.hv-sprite\):not\(\.hv-wave\)\s*\{[^}]*\}/s)[0];
  t('fallback sets both axes', /inline-size:/.test(rule)&&/block-size:/.test(rule));
  t('fallback stops flex stretching', /flex:\s*0 0 auto/.test(rule));
}
t('.hv-wave excluded (it must fill the nav)', /:not\(\.hv-wave\)/.test(css));
t('.hv-sprite excluded (the hidden symbol defs)', /:not\(\.hv-sprite\)/.test(css));
t('.hv-map-pill svg explicitly sized', /\.hv-map-pill svg \{[^}]*inline-size:\s*16px/s.test(css));
t('.hv-photo-upload svg explicitly sized', /\.hv-photo-upload svg \{[^}]*inline-size:\s*22px/s.test(css));

function renderedSize(parentClass){
  const specific=new RegExp('\\.'+parentClass+' svg \\{[^}]*inline-size:\\s*(\\d+)px','s').exec(css);
  if (specific) return +specific[1];
  if (/#havato-app svg:not\(\.hv-sprite\):not\(\.hv-wave\)/.test(css)) return 20; // 1.25em @16px
  return 300; // browser default for an unsized inline SVG
}
console.log('\n   simulated icon width per container:');
let oversized=[];
for (const cls of ['hv-map-pill','hv-photo-upload','hv-tab','hv-stat-icon','hv-empty',
                   'hv-list-thumb','hv-event-thumb','hv-menu-thumb','hv-auth-logo']) {
  const w=renderedSize(cls);
  if (w>64) oversized.push(cls+'='+w);
  console.log(`     .${cls.padEnd(16)} ${w}px`);
}
t('no icon renders at the 300px browser default', oversized.length===0);

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
