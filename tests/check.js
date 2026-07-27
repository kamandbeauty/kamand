const p=require('php-parser'),fs=require('fs'),path=require('path');
const parser=new p.Engine({parser:{suppressErrors:false}});
function walk(d){let r=[];for(const f of fs.readdirSync(d)){const fp=path.join(d,f);const s=fs.statSync(fp);if(s.isDirectory())r=r.concat(walk(fp));else if(f.endsWith('.php'))r.push(fp);}return r;}
let bad=0;
for(const f of walk(process.argv[2])){try{parser.parseCode(fs.readFileSync(f,'utf8'),f);}catch(e){bad++;console.log('FAIL',f,e.message);}}
console.log(bad?'errors:'+bad:'all php files parse OK');
process.exit(bad?1:0);
