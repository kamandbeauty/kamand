import { newGame, hakemDealStep, startRound, chooseTrump, dealRest, playCard, collectTrick, canPlay, nextRound, DEFAULT_SETTINGS, TEAM_OF } from '../src/game/engine.js';
import { chooseCardAI, chooseTrumpAI } from '../src/game/ai.js';
import { legalCards, trickWinnerIndex } from '../src/game/cards.js';

let errors = [];
function assert(c, m, st) { if (!c) { errors.push(m); if (errors.length<4) console.log('FAIL:', m); } }

let winsT0=0, kots=0, hakemKots=0, rounds=0, games=0, aceHakem=0;
const diffs=['easy','normal','hard'];
for (let g=0; g<400; g++) {
  let st = newGame({...DEFAULT_SETTINGS, difficulty: diffs[g%3], targetMode: g%2?'points':'rounds', targetPoints:7, targetRounds:5});
  let guard=0;
  while (st.phase !== 'gameEnd' && guard++ < 20000) {
    switch(st.phase) {
      case 'hakemDeal': st = hakemDealStep(st); break;
      case 'hakemFound': {
        const last = st.hakemReveal[st.hakemReveal.length-1];
        assert(last.card.r===14 && last.player===st.hakem, 'hakem must be the ace holder');
        aceHakem++;
        st = startRound(st, st.hakem); break;
      }
      case 'chooseTrump': {
        assert(st.players[st.hakem].hand.length===5, 'hakem gets exactly 5 cards before trump');
        st.players.forEach((p,i)=>{ if(i!==st.hakem) assert(p.hand.length===0,'others have 0 cards before trump'); });
        st = chooseTrump(st, chooseTrumpAI(st.players[st.hakem].hand, st.settings.difficulty)); break;
      }
      case 'dealing': {
        st = dealRest(st);
        st.players.forEach(p=>assert(p.hand.length===13,'each player has 13 cards'));
        const ids = new Set(st.players.flatMap(p=>p.hand.map(c=>c.id)));
        assert(ids.size===52,'52 distinct cards dealt');
        assert(st.turn===st.hakem && st.leader===st.hakem,'hakem leads first trick');
        break;
      }
      case 'playing': {
        const p = st.turn;
        const card = chooseCardAI(st, p);
        const lead = st.trick.length ? st.trick[0].card.s : null;
        const legal = legalCards(st.players[p].hand, lead);
        assert(legal.some(c=>c.id===card.id), 'AI plays a legal card');
        if (lead && st.players[p].hand.some(c=>c.s===lead)) assert(card.s===lead,'must follow suit');
        assert(canPlay(st,p,card),'canPlay agrees');
        st = playCard(st, p, card);
        break;
      }
      case 'trickEnd': {
        assert(st.trick.length===4,'trick has 4 cards');
        const wi = trickWinnerIndex(st.trick, st.trump);
        const lead = st.trick[0].card.s;
        const trumpsIn = st.trick.filter(t=>t.card.s===st.trump);
        const w = st.trick[wi].card;
        if (trumpsIn.length) assert(w.s===st.trump && w.r===Math.max(...trumpsIn.map(t=>t.card.r)),'highest trump wins');
        else { const ls=st.trick.filter(t=>t.card.s===lead); assert(w.s===lead && w.r===Math.max(...ls.map(t=>t.card.r)),'highest lead suit wins'); }
        const before = st.tricksWon.slice();
        st = collectTrick(st);
        assert(st.tricksWon[0]+st.tricksWon[1]===before[0]+before[1]+1,'trick counted');
        break;
      }
      case 'roundEnd': {
        const r = st.roundResult;
        rounds++;
        assert(r.tricks[0]+r.tricks[1]<=13,'<=13 tricks');
        assert(Math.max(...r.tricks)===7,'round ends exactly at 7 tricks');
        if (r.kot) { kots++; assert(r.tricks[1-r.winnerTeam]===0,'kot means 0 for loser'); }
        if (r.hakemKot) { hakemKots++; assert(r.points===3,'hakem kot = 3'); assert(TEAM_OF[r.hakem]!==r.winnerTeam,'hakem kot only vs hakem'); }
        else if (r.kot) assert(r.points===2,'kot = 2');
        else assert(r.points===1,'normal = 1');
        // hakem rotation
        const prevH = st.hakem;
        st = nextRound(st);
        const expected = TEAM_OF[prevH]===r.winnerTeam ? prevH : (prevH+1)%4;
        assert(st.hakem===expected,'hakem rotation rule');
        break;
      }
      default: throw new Error('unknown phase '+st.phase);
    }
  }
  games++;
  if (st.gameResult.winnerTeam===0) winsT0++;
  const s=st.settings;
  if (s.targetMode==='points') assert(Math.max(...st.scores)>=s.targetPoints,'points target reached');
  else assert(st.round===s.targetRounds,'round target reached');
  assert(st.scores[0]+st.scores[1] === st.history.reduce((a,h)=>a+h.points[0]+h.points[1],0),'score totals match history');
}
console.log({games, rounds, kots, hakemKots, winsT0, errors: errors.length});
if (errors.length) { console.log([...new Set(errors)]); process.exit(1); }
console.log('ALL RULE CHECKS PASSED');
