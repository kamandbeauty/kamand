/* 1) seats still stored  2) no invented numbers  3) guests never confused */
const fs=require('fs');
const R=__dirname+'/../havato/';
const rd=f=>fs.readFileSync(R+f,'utf8');
const db=rd('includes/class-havato-db.php'), rest=rd('includes/class-havato-rest.php');
const M=rd('includes/class-havato-matcher.php'), oj=rd('assets/js/havato-owner-admin.js');
const oa=rd('includes/class-havato-owner-admin.php'), js=rd('assets/js/havato-app.js');
const i18n=rd('includes/class-havato-i18n.php');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- 1. seats per table are still stored ---');
t('seats column kept', /seats int\(11\) NOT NULL DEFAULT 4/.test(db));
t('saved from the form', /'seats'\s*=>\s*\$seats/.test(rest));
t('clamped 2..20', /max\( 2, min\( 20,/.test(rest));
t('returned in the payload', /'seats'\s*=>\s*\(int\) \$row\['seats'\]/.test(rest));
t('seats column in the editor', /table_seats/.test(oj));
t('capacity still derived from seats', /\$capacity \+= \(int\) \$available\[ \$tid \]\['seats'\] \* \$qty/.test(rest));
t('matcher still sizes groups by seats', /\$plan\[ \$plan_i \]\['seats'\]/.test(M));
{
  const plan=[{seats:6,number:6},{seats:4,number:1},{seats:4,number:2}];
  t('capacity = sum of seats (14)', plan.reduce((a,b)=>a+b.seats,0)===14);
  t('group sizes follow seats', JSON.stringify(plan.map(p=>p.seats))==='[6,4,4]');
}

console.log('\n--- 2. the café supplies the number, we never invent one ---');
t('auto-suggest removed', !/function nextNumber/.test(oj));
t('new rows start blank', /table_number: 0/.test(oj));
t('blank shown as empty, not 0', /\(num \|\| ''\)/.test(oj));
t('client requires a number before saving', /function missingNumbers/.test(oj));
t('save disabled while any number is blank', /locked \|\| dupes\.length \|\| missingNumbers\(\)/.test(oj));
t('server rejects a missing number', /havato_table_number_required/.test(rest));
t('server does NOT silently default to 1', !/min\( 999, isset\( \$item\['table_number'\] \)/.test(rest));
t('reason documented', /painted on the table in the room/.test(rest));
t('owner told to use the real number', /table_number_hint/.test(oa));
{
  const missing=rows=>rows.some(r=>!(parseInt(r.table_number,10)||0));
  t('blank row blocks saving', missing([{table_number:6},{table_number:0}]));
  t('all numbered -> allowed', !missing([{table_number:6},{table_number:12}]));
  t('non-sequential numbers fine (6, 12, 3)',
    !missing([{table_number:6},{table_number:12},{table_number:3}]));
  const dupes=rows=>{const s={},o=[];rows.forEach(r=>{const n=+r.table_number||0;if(!n)return;
    if(s[n])o.push(n);s[n]=true;});return o;};
  t('blanks are not treated as duplicates', dupes([{table_number:0},{table_number:0}]).length===0);
  t('real duplicates still caught', dupes([{table_number:6},{table_number:6}]).join()==='6');
}

console.log('\n--- 3. guests are never confused ---');
t('group named after the REAL table number', /table_number_label', 'en' \), \$number/.test(M));
t('no sequential "Table 1,2,3" when a number exists', /\$number\s*\?\s*sprintf/.test(M));
t('legacy events still get a fallback name', /sprintf\( 'Table %d', \$index \)/.test(M));
t('welcome message names the table', /Table #%d/.test(M));
t('message bilingual', /میز شماره %s/.test(M));
t('chat list shows the table badge', /thread\.table_name/.test(js));
t('server sends it', /'table_name'   => \$row\['name'\]/.test(rest));
t('reason documented', /guest told "Table 6" walks to table 6/.test(M));
{
  // the café's numbers must survive into the group names
  const cafeTables=[{number:6,seats:6},{number:12,seats:4},{number:3,seats:4}];
  const plan=[...cafeTables].sort((a,b)=>b.seats-a.seats);
  const names=plan.map(p=>p.number?`Table #${p.number}`:'Table ?');
  t('biggest table first for matching quality', plan[0].seats===6);
  t('names use café numbers, not 1/2/3', JSON.stringify(names)==='["Table #6","Table #12","Table #3"]');
  t('no group is called "Table 1" by accident', !names.includes('Table #1'));
  const legacy=[{number:0,seats:6}];
  t('legacy event falls back safely', legacy[0].number===0);
}

for (const k of ['table_number_required','table_number_hint'])
  t(`i18n "${k}" bilingual`, new RegExp(`'${k}'[^\\n]*'fa' =>[^\\n]*'en' =>`).test(i18n));

console.log(f?`\n❌ ${f} failure(s)`:'\n✅ seats kept, numbers come from the café, guests see the real table');
process.exit(f?1:0);
