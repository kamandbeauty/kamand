/* Proves the matcher now seats one group per PHYSICAL table
   ("3x4 + 1x6" -> 4,4,4,6) instead of one giant group. */
const fs=require('fs');
const M=fs.readFileSync(__dirname+'/../havato/includes/class-havato-matcher.php','utf8');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- wiring ---');
t('seat_plan() derives sizes from furniture', /private static function seat_plan/.test(M));
t('reads the event_tables rows', /Havato_REST::event_tables\( \$event\['id'\] \)/.test(M));
t('expands quantity into individual tables', /for \( \$i = 0; \$i < max\( 1, \(int\) \$row\['quantity'\] \)/.test(M));
t('biggest table first', /rsort\( \$plan \)/.test(M));
t('legacy events still work', /\$plan\[\] = max\( 2, \(int\) \$event\['max_capacity'\] \)/.test(M));
t('build_tables takes the plan', /function build_tables\( \$user_ids, \$profiles, \$seat_plan, \$relaxed \)/.test(M));
t('capacity advances per table', /\$plan_i\+\+;/.test(M));
t('total capacity = sum of seats', /\$capacity\s*=\s*array_sum\( \$seat_plan \)/.test(M));
t('plan logged for the admin console', /Seating plan: %d table/.test(M));

console.log('\n--- behavioural simulation ---');
// mirror seat_plan()
function seatPlan(tables, legacyCap){
  let plan=[];
  for(const r of tables) for(let i=0;i<Math.max(1,r.quantity);i++) plan.push(Math.max(2,r.seats));
  if(!plan.length) plan=[Math.max(2,legacyCap)];
  return plan.sort((a,b)=>b-a);
}
// mirror the per-table loop: fill each table in turn, never drop anyone
function seat(guests, plan){
  const pool=[...guests]; const out=[]; let i=0;
  while(pool.length){
    const cap = i<plan.length ? plan[i] : plan[plan.length-1];
    out.push(pool.splice(0, cap)); i++;
    if(i>50) break;
  }
  return out;
}
{
  const plan=seatPlan([{seats:4,quantity:3},{seats:6,quantity:1}],6);
  t('3x4 + 1x6 -> [6,4,4,4]', JSON.stringify(plan)==='[6,4,4,4]');
  t('total capacity 18', plan.reduce((a,b)=>a+b,0)===18);

  const g=Array.from({length:18},(_,i)=>i+1);
  const tables=seat(g,plan);
  t('18 guests -> 4 separate groups', tables.length===4);
  t('group sizes match the furniture', JSON.stringify(tables.map(x=>x.length))==='[6,4,4,4]');
  t('everyone seated', tables.flat().length===18);
  t('NOT one group of 18', !tables.some(x=>x.length===18));
}
{
  // the old behaviour, for contrast
  const oldWay=seat(Array.from({length:18},(_,i)=>i),[18]);
  t('old model would have made one group of 18', oldWay.length===1 && oldWay[0].length===18);
}
{
  const plan=seatPlan([{seats:4,quantity:3}],6);
  const tables=seat(Array.from({length:7},(_,i)=>i),plan);
  t('under-filled: 7 guests on 3x4 -> 4+3', JSON.stringify(tables.map(x=>x.length))==='[4,3]');
  t('third table simply unused', tables.length===2);
}
{
  const plan=seatPlan([],6);
  t('legacy event -> single table of max_capacity', JSON.stringify(plan)==='[6]');
  const tables=seat(Array.from({length:6},(_,i)=>i),plan);
  t('legacy still seats everyone', tables.length===1 && tables[0].length===6);
}
{
  // overflow beyond the plan must not drop guests
  const plan=seatPlan([{seats:4,quantity:1}],4);
  const tables=seat(Array.from({length:9},(_,i)=>i),plan);
  t('overflow keeps seating (no one lost)', tables.flat().length===9);
}
console.log(f?`\n❌ ${f} failure(s)`:'\n✅ one group per physical table, legacy events unaffected');
process.exit(f?1:0);
