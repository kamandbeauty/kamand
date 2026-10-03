import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Card from './components/Card.jsx';
import Seat from './components/Seat.jsx';
import {
  MainMenu, SettingsModal, Scoreboard, RoundEndModal, GameEndModal,
  TrickViewer, TrumpChooser, RulesModal,
} from './components/Modals.jsx';
import {
  DEFAULT_SETTINGS, newGame, hakemDealStep, startRound, chooseTrump, dealRest,
  playCard, collectTrick, canPlay, nextRound, speedMs, TEAM_OF,
} from './game/engine.js';
import { chooseCardAI, chooseTrumpAI } from './game/ai.js';
import {
  SUIT_INFO, sortHand, legalCards, toPersianDigits, trickWinnerIndex,
} from './game/cards.js';
import { sfx, setSoundEnabled } from './game/sound.js';

const SAVE_KEY = 'hokm.save.v1';
const SET_KEY = 'hokm.settings.v1';
const SEAT_POS = ['south', 'east', 'north', 'west'];

function loadSettings() {
  try {
    const raw = localStorage.getItem(SET_KEY);
    return raw ? { ...DEFAULT_SETTINGS, ...JSON.parse(raw) } : { ...DEFAULT_SETTINGS };
  } catch { return { ...DEFAULT_SETTINGS }; }
}
function loadSave() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return null;
    const s = JSON.parse(raw);
    if (!s || s.phase === 'idle' || s.phase === 'gameEnd') return null;
    return s;
  } catch { return null; }
}

export default function App() {
  const [settings, setSettings] = useState(loadSettings);
  const [state, setState] = useState(null);           // null = منوی اصلی
  const [savedGame, setSavedGame] = useState(loadSave);
  const [showSettings, setShowSettings] = useState(false);
  const [showScore, setShowScore] = useState(false);
  const [showTricks, setShowTricks] = useState(false);
  const [showRules, setShowRules] = useState(false);
  const [toast, setToast] = useState(null);
  const toastTimer = useRef(null);

  // ---- تنظیمات ----------------------------------------------------------
  useEffect(() => {
    setSoundEnabled(settings.sound);
    localStorage.setItem(SET_KEY, JSON.stringify(settings));
  }, [settings]);

  const applySettings = (next) => {
    setSettings(next);
    setState((s) => (s ? { ...s, settings: { ...s.settings, ...next } } : s));
  };

  const say = useCallback((msg) => {
    setToast(msg);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 2200);
  }, []);

  // ---- ذخیره‌سازی خودکار -------------------------------------------------
  useEffect(() => {
    if (!state) return;
    if (state.phase === 'gameEnd') { localStorage.removeItem(SAVE_KEY); setSavedGame(null); return; }
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(state)); } catch { /* noop */ }
  }, [state]);

  // ---- حلقه‌ی اصلی بازی (نوبت‌ها و تایمرها) -----------------------------
  const tickKey = state
    ? `${state.phase}|${state.turn}|${state.trick.length}|${state.hakemReveal.length}|${state.round}`
    : 'none';

  useEffect(() => {
    if (!state) return undefined;
    const ms = speedMs(settings.speed);
    let t;

    switch (state.phase) {
      case 'hakemDeal':
        sfx.deal();
        t = setTimeout(() => setState((s) => hakemDealStep(s)), Math.max(240, ms * 0.55));
        break;

      case 'hakemFound':
        sfx.trump();
        t = setTimeout(() => setState((s) => startRound(s, s.hakem)), ms * 2);
        break;

      case 'chooseTrump':
        if (state.hakem !== 0) {
          t = setTimeout(() => {
            sfx.trump();
            setState((s) => {
              if (s.phase !== 'chooseTrump') return s;
              return chooseTrump(s, chooseTrumpAI(s.players[s.hakem].hand, s.settings.difficulty));
            });
          }, ms * 1.8);
        }
        break;

      case 'dealing':
        sfx.deal();
        t = setTimeout(() => setState((s) => (s.phase === 'dealing' ? dealRest(s) : s)), ms * 1.3);
        break;

      case 'playing':
        if (state.turn !== 0) {
          t = setTimeout(() => {
            sfx.play();
            setState((s) => {
              if (s.phase !== 'playing' || s.turn === 0) return s;
              return playCard(s, s.turn, chooseCardAI(s, s.turn));
            });
          }, ms);
        }
        break;

      case 'trickEnd': {
        const wi = trickWinnerIndex(state.trick, state.trump);
        const winner = state.trick[wi].player;
        if (TEAM_OF[winner] === 0) sfx.trickWin(); else sfx.trickLose();
        t = setTimeout(() => {
          sfx.collect();
          setState((s) => (s.phase === 'trickEnd' ? collectTrick(s) : s));
        }, ms * 1.6);
        break;
      }

      case 'roundEnd':
      case 'gameEnd': {
        const r = state.roundResult;
        if (r) {
          if (r.kot) sfx.kot();
          else if (r.winnerTeam === 0) sfx.roundWin();
          else sfx.roundLose();
        }
        break;
      }

      default:
        break;
    }
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tickKey, settings.speed]);

  // ---- اکشن‌ها ----------------------------------------------------------
  const startNew = () => {
    sfx.click();
    setState(newGame(settings));
    setShowScore(false);
  };
  const resume = () => { sfx.click(); setState(savedGame); };
  const toMenu = () => { sfx.click(); setState(null); setSavedGame(loadSave()); };

  const onHumanPlay = (card) => {
    if (!state || state.phase !== 'playing') return;
    if (state.turn !== 0) { sfx.error(); say('نوبت شما نیست'); return; }
    if (!canPlay(state, 0, card)) {
      sfx.error();
      const lead = state.trick[0]?.card.s;
      say(lead ? `باید از خالِ ${SUIT_INFO[lead].fa} بازی کنید` : 'این کارت مجاز نیست');
      return;
    }
    sfx.play();
    setState((s) => playCard(s, 0, card));
  };

  const onChooseTrump = (suit) => {
    sfx.trump();
    setState((s) => chooseTrump(s, suit));
  };

  // ---- رندر --------------------------------------------------------------
  if (!state) {
    return (
      <div className="app" style={surfaceStyle(settings.surface)}>
        <div className="app-overlay" />
        <MainMenu
          settings={settings}
          hasSave={!!savedGame}
          onNew={startNew}
          onResume={resume}
          onSettings={() => setShowSettings(true)}
          onRules={() => setShowRules(true)}
        />
        {showSettings && (
          <SettingsModal settings={settings} onChange={applySettings} onClose={() => setShowSettings(false)} />
        )}
        {showRules && <RulesModal onClose={() => setShowRules(false)} />}
      </div>
    );
  }

  const me = state.players[0];
  const leadSuit = state.trick.length ? state.trick[0].card.s : null;
  const myTurn = state.phase === 'playing' && state.turn === 0;
  const legal = myTurn ? legalCards(me.hand, leadSuit) : [];
  const legalIds = new Set(legal.map((c) => c.id));
  const myHand = settings.sortHand ? sortHand(me.hand, state.trump) : me.hand;

  return (
    <div className="app" style={surfaceStyle(settings.surface)}>
      <div className="app-overlay" />

      {/* ---------------- نوار بالا ---------------- */}
      <header className="topbar">
        <div className="topbar-group">
          <button className="icon-btn" onClick={toMenu} title="منوی اصلی">☰</button>
          <button className="icon-btn" onClick={() => { sfx.click(); setShowSettings(true); }} title="تنظیمات">⚙</button>
          <button
            className="icon-btn"
            onClick={() => applySettings({ ...settings, sound: !settings.sound })}
            title="صدا"
          >{settings.sound ? '🔊' : '🔇'}</button>
        </div>

        <div className="topbar-center">
          {state.trump ? (
            <div className={`trump-badge ${SUIT_INFO[state.trump].color}`}>
              <span className="trump-badge-sym">{SUIT_INFO[state.trump].sym}</span>
              <span className="trump-badge-txt">حکم: {SUIT_INFO[state.trump].fa}</span>
            </div>
          ) : (
            <div className="trump-badge trump-badge--empty">حکم هنوز تعیین نشده</div>
          )}
          <div className="tricks-counter">
            <span className="t0">ما {toPersianDigits(state.tricksWon[0])}</span>
            <span className="sep">دست</span>
            <span className="t1">حریف {toPersianDigits(state.tricksWon[1])}</span>
          </div>
        </div>

        <div className="topbar-group">
          <button className="score-pill" onClick={() => { sfx.click(); setShowScore(true); }}>
            <span className="score-pill-label">امتیاز</span>
            <span className="score-pill-val">
              {toPersianDigits(state.scores[0])} : {toPersianDigits(state.scores[1])}
            </span>
            <span className="score-pill-round">راند {toPersianDigits(Math.max(1, state.round))}</span>
          </button>
        </div>
      </header>

      {/* ---------------- میز بازی ---------------- */}
      <main className="table">
        {[1, 2, 3].map((i) => (
          <Seat
            key={i}
            player={state.players[i]}
            pos={SEAT_POS[i]}
            isHakem={state.hakem === i}
            isTurn={state.turn === i && state.phase === 'playing'}
            thinking={state.turn === i && (state.phase === 'playing' || (state.phase === 'chooseTrump' && state.hakem === i))}
            cardBack={settings.cardBack}
            label={i === 2 ? 'یار شما' : 'حریف'}
          />
        ))}

        {/* کارت‌های جمع‌شده‌ی هر تیم */}
        <button
          className="pile pile--us"
          onClick={() => { sfx.click(); setShowTricks(true); }}
          title="مشاهده‌ی دست‌های قبلی"
        >
          {state.trickPiles[0].slice(-4).map((_, i) => (
            <Card key={i} faceDown back={settings.cardBack} size="xs" style={{ '--k': i }} className="pile-card" />
          ))}
          <span className="pile-count">{toPersianDigits(state.trickPiles[0].length)}</span>
        </button>
        <button
          className="pile pile--them"
          onClick={() => { sfx.click(); setShowTricks(true); }}
          title="مشاهده‌ی دست‌های قبلی"
        >
          {state.trickPiles[1].slice(-4).map((_, i) => (
            <Card key={i} faceDown back={settings.cardBack} size="xs" style={{ '--k': i }} className="pile-card" />
          ))}
          <span className="pile-count">{toPersianDigits(state.trickPiles[1].length)}</span>
        </button>

        {/* مرکز میز */}
        <div className="center">
          {state.phase === 'hakemDeal' || state.phase === 'hakemFound' ? (
            <div className="hakem-deal">
              <div className="hakem-deal-title">تعیین حاکم</div>
              <div className="hakem-deal-cards">
                {state.hakemReveal.slice(-8).map((h, i, arr) => (
                  <div key={i} className={`hakem-deal-item ${i === arr.length - 1 ? 'is-last' : ''}`}>
                    <Card card={h.card} size="sm" />
                    <span>{state.players[h.player].name}</span>
                  </div>
                ))}
              </div>
              {state.phase === 'hakemFound' && (
                <div className="hakem-found">♔ {state.players[state.hakem].name} حاکم شد</div>
              )}
            </div>
          ) : state.phase === 'dealing' ? (
            <div className="dealing">
              <div className="deck-stack">
                {[0, 1, 2, 3, 4].map((i) => (
                  <Card key={i} faceDown back={settings.cardBack} size="sm" style={{ '--k': i }} className="deck-card" />
                ))}
              </div>
              <span>در حال پخش ورق…</span>
            </div>
          ) : (
            <div className="trick-area">
              {state.trick.map((t) => (
                <div key={t.card.id} className={`played played--${SEAT_POS[t.player]}`}>
                  <Card card={t.card} size="md" isTrump={t.card.s === state.trump} />
                </div>
              ))}
              {state.phase === 'trickEnd' && (() => {
                const wi = trickWinnerIndex(state.trick, state.trump);
                const w = state.trick[wi].player;
                return (
                  <div className={`trick-winner trick-winner--${SEAT_POS[w]}`}>
                    {state.players[w].name} برد
                  </div>
                );
              })()}
            </div>
          )}
        </div>

        {/* ---------------- دست بازیکن ---------------- */}
        <div className={`seat seat--south ${myTurn ? 'seat--turn' : ''}`}>
          <div className={`nameplate nameplate--me ${myTurn ? 'nameplate--turn' : ''} team-0`}>
            {state.hakem === 0 && <span className="crown" title="حاکم">♔</span>}
            <span className="nameplate-name">{settings.playerName || 'شما'}</span>
            <span className="nameplate-tag">{myTurn ? 'نوبت شماست' : ''}</span>
            <span className="nameplate-count">{toPersianDigits(me.hand.length)}</span>
          </div>
          <div className="hand hand--south">
            {myHand.map((c, i) => {
              const playable = myTurn && legalIds.has(c.id);
              return (
                <Card
                  key={c.id}
                  card={c}
                  size="lg"
                  className="hand-card hand-card--south"
                  style={{ '--i': i, '--n': myHand.length }}
                  isTrump={state.trump === c.s}
                  playable={playable}
                  dim={settings.showHints && myTurn && !playable}
                  onClick={() => onHumanPlay(c)}
                />
              );
            })}
          </div>
        </div>

        {state.phase === 'chooseTrump' && state.hakem === 0 && (
          <TrumpChooser hand={sortHand(me.hand, null)} onChoose={onChooseTrump} cardBack={settings.cardBack} />
        )}
      </main>

      {toast && <div className="toast">{toast}</div>}
      {state.message && (state.phase === 'hakemDeal' || state.phase === 'chooseTrump') && (
        <div className="status-strip">{state.message}</div>
      )}

      {showSettings && (
        <SettingsModal settings={settings} onChange={applySettings} onClose={() => setShowSettings(false)} inGame />
      )}
      {showScore && <Scoreboard state={state} onClose={() => setShowScore(false)} />}
      {showTricks && <TrickViewer state={state} onClose={() => setShowTricks(false)} />}
      {showRules && <RulesModal onClose={() => setShowRules(false)} />}
      {state.phase === 'roundEnd' && (
        <RoundEndModal state={state} onNext={() => { sfx.click(); setState((s) => nextRound(s)); }} />
      )}
      {state.phase === 'gameEnd' && (
        <GameEndModal state={state} onNew={startNew} onMenu={toMenu} />
      )}
    </div>
  );
}

function surfaceStyle(surface) {
  return { backgroundImage: `url(./surfaces/${surface}.jpg)` };
}
