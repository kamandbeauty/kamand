import { newGame, hakemDealStep, startRound, chooseTrump, dealRest, playCard, collectTrick, nextRound, DEFAULT_SETTINGS, TEAM_OF } from '../src/game/engine.js';
import { chooseCardAI, chooseTrumpAI } from '../src/game/ai.js';
// تیم ۰ = hard ، تیم ۱ = حریفِ تعیین‌شده
function run(oppDiff, n=300) {
  let w0=0, t0r=0, t1r=0;
  for (let g=0; g<n; g++) {
    let st = newGame({...DEFAULT_SETTINGS, targetMode:'points', targetPoints:7});
    let guard=0;
    while (st.phase!=='gameEnd' && guard++<20000) {
      const diffFor = p => TEAM_OF[p]===0 ? 'hard' : oppDiff;
      switch(st.phase){
        case 'hakemDeal': st=hakemDealStep(st); break;
        case 'hakemFound': st=startRound(st, st.hakem); break;
        case 'chooseTrump': st=chooseTrump(st, chooseTrumpAI(st.players[st.hakem].hand, diffFor(st.hakem))); break;
        case 'dealing': st=dealRest(st); break;
        case 'playing': {
          const p=st.turn;
          const s2={...st, settings:{...st.settings, difficulty: diffFor(p)}};
          st=playCard(st,p,chooseCardAI(s2,p)); break;
        }
        case 'trickEnd': st=collectTrick(st); break;
        case 'roundEnd': t0r+=st.roundResult.winnerTeam===0?1:0; t1r+=st.roundResult.winnerTeam===1?1:0; st=nextRound(st); break;
      }
    }
    if (st.gameResult.winnerTeam===0) w0++;
  }
  console.log(`hard vs ${oppDiff}: برد تیم hard = ${(100*w0/n).toFixed(1)}% | راندها ${t0r}-${t1r}`);
}
run('easy'); run('normal'); run('hard');
