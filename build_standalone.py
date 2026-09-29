import json
import os

kamand_dir = os.path.dirname(os.path.abspath(__file__))
levels = []
for i in range(1, 31):
    with open(os.path.join(kamand_dir, f"data/levels/level_{i}.json"), "r") as f:
        levels.append(json.load(f))

levels_json_str = json.dumps(levels)

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Lumi: Bubblewood Chronicle — Playable Game</title>
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; user-select: none; -webkit-user-select: none; }}
    body {{
      background-color: #030712;
      color: #FFFFFF;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      overflow: hidden;
    }}
    #game-container {{
      position: relative;
      width: 100vw;
      height: 100vh;
      max-width: 480px;
      max-height: 853px;
      aspect-ratio: 720 / 1280;
      background: #064e3b;
      border-radius: 16px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7);
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }}
    canvas {{
      width: 100%;
      height: 100%;
      display: block;
      cursor: crosshair;
      touch-action: none;
    }}
    .overlay-screen {{
      position: absolute;
      inset: 0;
      z-index: 30;
      display: flex;
      flex-direction: column;
      padding: 24px;
      background: linear-gradient(180deg, #022c22 0%, #064e3b 50%, #022c22 100%);
    }}
    .hidden {{ display: none !important; }}
    button {{
      cursor: pointer;
      font-weight: bold;
      border: none;
      border-radius: 12px;
      transition: transform 0.1s, opacity 0.2s;
    }}
    button:active {{ transform: scale(0.96); }}
    .btn-primary {{
      background: linear-gradient(90deg, #10b981 0%, #14b8a6 100%);
      color: #022c22;
      padding: 16px;
      font-size: 18px;
      font-weight: 900;
      box-shadow: 0 10px 15px -3px rgba(16, 185, 129, 0.3);
    }}
    .btn-secondary {{
      background: rgba(6, 78, 59, 0.6);
      color: #a7f3d0;
      border: 1px solid rgba(16, 185, 129, 0.4);
      padding: 14px;
      font-size: 15px;
    }}
    .btn-dark {{
      background: rgba(30, 41, 59, 0.8);
      color: #cbd5e1;
      border: 1px solid rgba(51, 65, 85, 0.8);
      padding: 12px;
    }}
    .header-hud {{
      position: absolute;
      top: 0; left: 0; right: 0;
      z-index: 20;
      padding: 12px 16px;
      background: linear-gradient(180deg, rgba(2, 44, 34, 0.95) 0%, rgba(2, 44, 34, 0.6) 80%, transparent 100%);
      display: flex;
      flex-direction: column;
      gap: 6px;
    }}
    .modal-backdrop {{
      position: absolute;
      inset: 0;
      z-index: 40;
      background: rgba(0, 0, 0, 0.75);
      backdrop-filter: blur(4px);
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }}
    .modal-box {{
      width: 100%;
      max-width: 320px;
      background: linear-gradient(180deg, #0f172a 0%, #064e3b 100%);
      border: 2px solid #10b981;
      border-radius: 24px;
      padding: 24px;
      text-align: center;
      display: flex;
      flex-direction: column;
      gap: 16px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.8);
    }}
    .grid-levels {{
      display: grid;
      grid-template-columns: repeat(5, 1fr);
      gap: 10px;
      margin-top: 12px;
      overflow-y: auto;
      max-height: 420px;
      padding-bottom: 20px;
    }}
    .level-badge {{
      aspect-ratio: 1;
      border-radius: 14px;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: rgba(6, 78, 59, 0.5);
      border: 1px solid rgba(16, 185, 129, 0.4);
      color: white;
      font-weight: 800;
      font-size: 14px;
    }}
    .level-badge.locked {{
      background: rgba(15, 23, 42, 0.7);
      border-color: rgba(51, 65, 85, 0.5);
      opacity: 0.5;
      cursor: not-allowed;
    }}
  </style>
</head>
<body>

<div id="game-container">
  <!-- CANVAS -->
  <canvas id="gameCanvas" width="720" height="1280"></canvas>

  <!-- TOP HUD -->
  <div id="hud" class="header-hud hidden">
    <div style="display: flex; justify-content: space-between; align-items: center; font-size: 12px; font-weight: bold;">
      <div style="display: flex; gap: 8px; align-items: center;">
        <button id="btnHudMap" class="btn-secondary" style="padding: 4px 10px; font-size: 11px;">🗺️ MAP</button>
        <span id="txtLvlName" style="color: #6ee7b7;">LVL 1</span>
      </div>
      <div id="txtStars" style="color: #fbbf24; letter-spacing: 2px; font-size: 14px;">☆ ☆ ☆</div>
      <button id="btnPause" class="btn-dark" style="padding: 4px 12px; font-size: 12px;">⏸</button>
    </div>
    <div style="display: flex; justify-content: space-between; align-items: center; font-weight: 900; margin-top: 2px;">
      <div id="txtScore" style="font-size: 18px; color: #ffffff;">SCORE: 0</div>
      <div id="txtShots" style="font-size: 15px; color: #34d399;">SHOTS: 30</div>
    </div>
    <div id="txtCombo" class="hidden" style="align-self: center; background: rgba(245, 158, 11, 0.2); border: 1px solid rgba(245, 158, 11, 0.5); color: #fbbf24; font-size: 11px; font-weight: 900; padding: 2px 12px; border-radius: 9999px;">
      COMBO x2!
    </div>
  </div>

  <!-- BOTTOM SWAP BUTTON -->
  <div id="bottomControls" class="hidden" style="position: absolute; bottom: 16px; left: 16px; z-index: 20;">
    <button id="btnSwap" class="btn-secondary" style="padding: 8px 16px; font-size: 12px; display: flex; align-items: center; gap: 6px;">
      <span>🔄</span> <span>SWAP</span>
    </button>
  </div>

  <!-- MAIN MENU SCREEN -->
  <div id="screenMenu" class="overlay-screen" style="justify-content: space-between; align-items: center;">
    <div style="text-align: center; margin-top: 30px;">
      <div style="display: inline-block; padding: 4px 16px; border-radius: 9999px; background: rgba(16, 185, 129, 0.2); color: #6ee7b7; font-weight: bold; font-size: 11px; border: 1px solid rgba(16, 185, 129, 0.4); margin-bottom: 12px;">
        ✨ PROCEDURAL FANTASY ADVENTURE
      </div>
      <h1 style="font-size: 48px; font-weight: 900; background: linear-gradient(90deg, #6ee7b7, #fef08a, #99f6e4); -webkit-background-clip: text; -webkit-text-fill-color: transparent; letter-spacing: 2px;">
        LUMI
      </h1>
      <p style="color: #a7f3d0; opacity: 0.8; font-size: 13px; margin-top: 4px;">Bubblewood Chronicle • 30 Levels</p>
    </div>

    <div style="text-align: center; margin: 20px 0;">
      <div style="width: 140px; height: 140px; border-radius: 50%; background: radial-gradient(circle, rgba(251, 191, 36, 0.3) 0%, transparent 70%); display: flex; align-items: center; justify-content: center; margin: 0 auto;">
        <div style="width: 100px; height: 100px; border-radius: 50%; background: #fffbeb; display: flex; align-items: center; justify-content: center; font-size: 48px; box-shadow: 0 10px 25px rgba(251, 191, 36, 0.4);">
          ✨
        </div>
      </div>
      <p style="font-size: 13px; color: #fde68a; margin-top: 16px; font-weight: bold;">
        Total Stars: <span id="txtMenuTotalStars" style="color: #fbbf24; font-size: 16px;">★ 0 / 90</span>
      </p>
    </div>

    <div style="width: 100%; display: flex; flex-direction: column; gap: 12px; margin-bottom: 20px;">
      <button id="btnMenuPlay" class="btn-primary" style="width: 100%;">PLAY GAME ▶</button>
      <button id="btnMenuMap" class="btn-secondary" style="width: 100%;">🗺️ WORLD MAP & LEVELS</button>
      <button id="btnMenuSettings" class="btn-dark" style="width: 100%;">⚙️ SETTINGS</button>
    </div>
  </div>

  <!-- WORLD MAP SCREEN -->
  <div id="screenMap" class="overlay-screen hidden">
    <div style="display: flex; justify-content: space-between; align-items: center; padding-bottom: 12px; border-bottom: 1px solid rgba(6, 78, 59, 0.8);">
      <button id="btnMapBack" class="btn-dark" style="padding: 6px 14px; font-size: 12px;">← BACK</button>
      <h2 style="font-size: 16px; font-weight: 900; color: #fde68a;">WORLD MAP</h2>
      <div style="color: #fbbf24; font-weight: 900; font-size: 13px;"><span id="txtMapStars">★ 0/90</span></div>
    </div>

    <!-- World Tabs -->
    <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin: 16px 0 12px 0;">
      <button id="tabWorld1" class="btn-secondary" style="padding: 8px 4px; font-size: 11px; text-align: center; border-color: #34d399;">
        🌲 Woods
      </button>
      <button id="tabWorld2" class="btn-dark" style="padding: 8px 4px; font-size: 11px; text-align: center;">
        💎 Caverns<br><span style="font-size: 9px; color: #fbbf24;">10★</span>
      </button>
      <button id="tabWorld3" class="btn-dark" style="padding: 8px 4px; font-size: 11px; text-align: center;">
        🌊 Grove<br><span style="font-size: 9px; color: #fbbf24;">25★</span>
      </button>
    </div>

    <!-- World Info Banner -->
    <div id="worldBanner" style="padding: 12px; border-radius: 12px; background: rgba(6, 78, 59, 0.4); border: 1px solid rgba(16, 185, 129, 0.3); font-size: 12px;">
      <div style="display: flex; justify-content: space-between; font-weight: bold; color: #a7f3d0;">
        <span id="txtWorldTitle">🌲 Whispering Woods</span>
        <span id="txtWorldRange" style="color: #6ee7b7; opacity: 0.8;">Levels 1-10</span>
      </div>
      <p id="txtWorldDesc" style="color: #94a3b8; font-size: 11px; margin-top: 4px;">A serene emerald forest introducing core bubble matching.</p>
    </div>

    <!-- Levels Grid -->
    <div id="levelsGrid" class="grid-levels"></div>
  </div>

  <!-- SETTINGS SCREEN -->
  <div id="screenSettings" class="overlay-screen hidden" style="justify-content: space-between;">
    <div>
      <div style="display: flex; justify-content: space-between; align-items: center; padding-bottom: 12px; border-bottom: 1px solid rgba(51, 65, 85, 0.8);">
        <button id="btnSettingsBack" class="btn-dark" style="padding: 6px 14px; font-size: 12px;">← BACK</button>
        <h2 style="font-size: 16px; font-weight: 900;">SETTINGS</h2>
        <div style="width: 40px;"></div>
      </div>

      <div style="display: flex; flex-direction: column; gap: 14px; margin-top: 24px;">
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 14px; border-radius: 12px; background: rgba(30, 41, 59, 0.6); border: 1px solid rgba(51, 65, 85, 0.6);">
          <div>
            <div style="font-weight: bold; font-size: 14px;">Sound Effects</div>
            <div style="font-size: 11px; color: #94a3b8;">Real-time procedural audio synthesis</div>
          </div>
          <input type="checkbox" id="chkSound" checked style="width: 20px; height: 20px; accent-color: #10b981; cursor: pointer;">
        </div>

        <div style="display: flex; justify-content: space-between; align-items: center; padding: 14px; border-radius: 12px; background: rgba(30, 41, 59, 0.6); border: 1px solid rgba(51, 65, 85, 0.6);">
          <div>
            <div style="font-weight: bold; font-size: 14px;">Accessibility Runes</div>
            <div style="font-size: 11px; color: #94a3b8;">Carved runes for colorblind clarity</div>
          </div>
          <input type="checkbox" id="chkRunes" checked style="width: 20px; height: 20px; accent-color: #10b981; cursor: pointer;">
        </div>

        <div style="display: flex; justify-content: space-between; align-items: center; padding: 14px; border-radius: 12px; background: rgba(30, 41, 59, 0.6); border: 1px solid rgba(51, 65, 85, 0.6);">
          <div>
            <div style="font-weight: bold; font-size: 14px;">Reduced Effects Mode</div>
            <div style="font-size: 11px; color: #94a3b8;">Disable heavy camera shakes & particles</div>
          </div>
          <input type="checkbox" id="chkReduced" style="width: 20px; height: 20px; accent-color: #10b981; cursor: pointer;">
        </div>
      </div>
    </div>

    <button id="btnResetData" class="btn-dark" style="background: rgba(127, 29, 29, 0.4); border-color: rgba(185, 28, 28, 0.6); color: #fca5a5; font-size: 12px; padding: 14px; margin-bottom: 20px;">
      ⚠️ RESET ALL GAME SAVE DATA
    </button>
  </div>

  <!-- TUTORIAL MODAL -->
  <div id="modalTutorial" class="modal-backdrop hidden">
    <div class="modal-box">
      <div style="width: 56px; height: 56px; border-radius: 50%; background: rgba(251, 191, 36, 0.2); display: flex; align-items: center; justify-content: center; font-size: 28px; margin: 0 auto;">
        ✨
      </div>
      <h3 id="txtTutTitle" style="font-size: 16px; font-weight: 900; color: #fde68a;">TUTORIAL</h3>
      <p id="txtTutBody" style="font-size: 12px; color: #cbd5e1; line-height: 1.5;"></p>
      <button id="btnTutOk" class="btn-primary" style="width: 100%; padding: 12px; font-size: 14px;">GOT IT! 👍</button>
    </div>
  </div>

  <!-- PAUSE MODAL -->
  <div id="modalPause" class="modal-backdrop hidden">
    <div class="modal-box" style="max-width: 280px;">
      <h3 style="font-size: 20px; font-weight: 900;">PAUSED</h3>
      <button id="btnResume" class="btn-primary" style="width: 100%; padding: 12px; font-size: 14px;">RESUME ▶</button>
      <button id="btnRestart" class="btn-dark" style="width: 100%; padding: 10px; font-size: 12px;">RESTART LEVEL 🔄</button>
      <button id="btnPauseMap" class="btn-dark" style="width: 100%; padding: 10px; font-size: 12px;">WORLD MAP 🗺️</button>
    </div>
  </div>

  <!-- WIN MODAL -->
  <div id="modalWin" class="modal-backdrop hidden">
    <div class="modal-box">
      <h3 style="font-size: 22px; font-weight: 900; color: #fde68a;">★ LEVEL COMPLETE! ★</h3>
      <div id="txtWinStars" style="font-size: 32px; color: #fbbf24; letter-spacing: 4px;">★ ★ ★</div>
      <div style="font-size: 14px; color: #a7f3d0; font-weight: bold;">
        Final Score: <span id="txtWinScore" style="color: #ffffff; font-size: 18px; font-weight: 900;">0</span>
      </div>
      <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 8px;">
        <button id="btnWinNext" class="btn-primary" style="width: 100%; padding: 14px; font-size: 15px;">NEXT LEVEL →</button>
        <button id="btnWinReplay" class="btn-secondary" style="width: 100%; padding: 10px; font-size: 12px;">PLAY AGAIN 🔄</button>
        <button id="btnWinMap" class="btn-dark" style="width: 100%; padding: 10px; font-size: 12px;">WORLD MAP 🗺️</button>
      </div>
    </div>
  </div>

  <!-- LOSE MODAL -->
  <div id="modalLose" class="modal-backdrop hidden">
    <div class="modal-box" style="border-color: #ef4444; background: linear-gradient(180deg, #450a0a 0%, #0f172a 100%);">
      <h3 style="font-size: 20px; font-weight: 900; color: #f87171;">LEVEL FAILED</h3>
      <p id="txtLoseReason" style="font-size: 13px; color: #cbd5e1;">Out of shots!</p>
      <div style="font-size: 13px; color: #94a3b8;">Score: <span id="txtLoseScore">0</span></div>
      <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 8px;">
        <button id="btnLoseRetry" class="btn-primary" style="background: linear-gradient(90deg, #ef4444, #f43f5e); color: white; width: 100%; padding: 14px; font-size: 15px;">TRY AGAIN 🔄</button>
        <button id="btnLoseMap" class="btn-dark" style="width: 100%; padding: 10px; font-size: 12px;">WORLD MAP 🗺️</button>
      </div>
    </div>
  </div>
</div>

<script>
// Game Data & Engine Code
const LEVELS = {levels_json_str};

const SCREEN_WIDTH = 720;
const SCREEN_HEIGHT = 1280;
const BUBBLE_RADIUS = 36;
const BUBBLE_DIAMETER = 72;
const GRID_COLUMNS_EVEN = 8;
const GRID_COLUMNS_ODD = 7;
const LEFT_WALL_X = 72;
const RIGHT_WALL_X = 648;
const GRID_START_Y = 160;
const ROW_SPACING = 62.3538;
const MAX_GRID_ROWS = 14;
const DEFAULT_DANGER_ROW = 12;
const SHOOTER_POS = {{ x: 360, y: 1150 }};
const NEXT_POS = {{ x: 250, y: 1150 }};
const LUMI_POS = {{ x: 575, y: 1155 }};
const SHOT_SPEED = 1400;

const COLOR_MAP = {{
  0: '#EB4040', 1: '#3373F2', 2: '#38D159', 3: '#FAD126', 4: '#AE47E6', 5: '#2ECCDE'
}};
const RUNES = {{ 0: '▲', 1: '💧', 2: '🌿', 3: '★', 4: '✦', 5: '❄' }};
const CHAR_MAP = {{ 'R': 0, 'B': 1, 'G': 2, 'Y': 3, 'P': 4, 'C': 5, '.': -1 }};

const WORLDS = [
  {{ id: 1, name: "Whispering Woods", icon: "🌲", start: 1, end: 10, reqStars: 0, desc: "A serene emerald forest introducing core bubble matching." }},
  {{ id: 2, name: "Crystal Caverns", icon: "💎", start: 11, end: 20, reqStars: 10, desc: "Subterranean grottos introducing Bombs 💣, Lightning ⚡, and Ice Shells 🔒." }},
  {{ id: 3, name: "Sunken Grove", icon: "🌊", start: 21, end: 30, reqStars: 25, desc: "Ancient mossy ruins guarded by hardened Stone Boulders 🪨." }}
];

const TUTORIALS = {{
  1: {{ title: "WELCOME TO LUMI!", text: "Aim by dragging or moving your mouse, then release to shoot. Match 3 or more bubbles of the same color to pop them!" }},
  4: {{ title: "COMBOS & DROPS", text: "Match bubbles consecutive times for multiplier combos! Severing bubbles from the ceiling drops them for massive drop points!" }},
  11: {{ title: "BOMB BUBBLES 💣", text: "Bomb bubbles detonate a 3x3 blast radius, clearing all neighboring bubbles instantly!" }},
  15: {{ title: "FROZEN ICE SHELLS 🔒", text: "Locked ice bubbles cannot be matched directly. Pop standard bubbles adjacent to them to crack their frozen shell!" }},
  21: {{ title: "STONE BOULDERS 🪨", text: "Stone bubbles are indestructible to normal matches. Drop them by severing their ceiling anchors or detonating nearby bombs!" }}
}};

// Global App State
let currentScreen = 'MENU';
let currentLevelIdx = 0;
let activeWorldTab = 1;
let currentScore = 0;
let shotsLeft = 30;
let currentCombo = 0;
let gameState = 'PLAYING';

let highScores = JSON.parse(localStorage.getItem('lumi_highscores_v3') || '{{}}');
let starsEarned = JSON.parse(localStorage.getItem('lumi_stars_v3') || '{{"1":0}}');
let unlockedLevels = JSON.parse(localStorage.getItem('lumi_unlocked_v3') || '[1]');
let seenTutorials = JSON.parse(localStorage.getItem('lumi_tutorials_v3') || '[]');

let soundEnabled = true;
let showRunes = true;
let reducedEffects = false;

// Engine State
let grid = [];
let activeProj = null;
let curColor = 0;
let nextColor = 1;
let isAiming = false;
let aimAngle = -Math.PI / 2;
let particles = [];
let popups = [];
let trauma = 0;
let lumiState = 'IDLE';
let lumiTimer = 0;

let audioCtx = null;
function getAudioCtx() {{
  if (!audioCtx) {{
    const AudioCtor = window.AudioContext || window.webkitAudioContext;
    if (AudioCtor) audioCtx = new AudioCtor();
  }}
  if (audioCtx && audioCtx.state === 'suspended') audioCtx.resume();
  return audioCtx;
}}

function playSound(type, param = 1) {{
  if (!soundEnabled) return;
  try {{
    const ctx = getAudioCtx();
    if (!ctx) return;
    const t = ctx.currentTime;
    if (type === 'POP') {{
      const osc = ctx.createOscillator();
      const g = ctx.createGain();
      const freq = 480 + param * 60;
      osc.frequency.setValueAtTime(freq, t);
      osc.frequency.exponentialRampToValueAtTime(freq * 1.8, t + 0.08);
      g.gain.setValueAtTime(0.3, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.09);
      osc.connect(g); g.connect(ctx.destination);
      osc.start(t); osc.stop(t + 0.09);
    }} else if (type === 'BOMB') {{
      const osc = ctx.createOscillator();
      const g = ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(140, t);
      osc.frequency.exponentialRampToValueAtTime(30, t + 0.35);
      g.gain.setValueAtTime(0.6, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.38);
      osc.connect(g); g.connect(ctx.destination);
      osc.start(t); osc.stop(t + 0.38);
    }} else if (type === 'BOUNCE') {{
      const osc = ctx.createOscillator();
      const g = ctx.createGain();
      osc.frequency.setValueAtTime(320, t);
      osc.frequency.exponentialRampToValueAtTime(220, t + 0.05);
      g.gain.setValueAtTime(0.25, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.05);
      osc.connect(g); g.connect(ctx.destination);
      osc.start(t); osc.stop(t + 0.05);
    }} else if (type === 'WIN') {{
      [523.25, 659.25, 783.99, 1046.50].forEach((f, i) => {{
        const osc = ctx.createOscillator();
        const g = ctx.createGain();
        osc.frequency.setValueAtTime(f, t + i * 0.09);
        g.gain.setValueAtTime(0.3, t + i * 0.09);
        g.gain.exponentialRampToValueAtTime(0.001, t + i * 0.09 + 0.22);
        osc.connect(g); g.connect(ctx.destination);
        osc.start(t + i * 0.09); osc.stop(t + i * 0.09 + 0.22);
      }});
    }}
  }} catch(e) {{}}
}}

function saveState() {{
  localStorage.setItem('lumi_highscores_v3', JSON.stringify(highScores));
  localStorage.setItem('lumi_stars_v3', JSON.stringify(starsEarned));
  localStorage.setItem('lumi_unlocked_v3', JSON.stringify(unlockedLevels));
  localStorage.setItem('lumi_tutorials_v3', JSON.stringify(seenTutorials));
}}

function getTotalStars() {{
  return Object.values(starsEarned).reduce((a, b) => a + b, 0);
}}

function getCols(r) {{ return (r % 2 === 0) ? GRID_COLUMNS_EVEN : GRID_COLUMNS_ODD; }}
function getOffsetX(r) {{ return (r % 2 === 0) ? LEFT_WALL_X + BUBBLE_RADIUS : LEFT_WALL_X + BUBBLE_RADIUS * 2; }}
function gridToWorld(r, c) {{ return {{ x: getOffsetX(r) + c * BUBBLE_DIAMETER, y: GRID_START_Y + r * ROW_SPACING }}; }}

function getNeighbors(r, c) {{
  const isEven = (r % 2 === 0);
  const offsets = [[0, -1], [0, 1], [-1, isEven ? -1 : 0], [-1, isEven ? 0 : 1], [1, isEven ? -1 : 0], [1, isEven ? 0 : 1]];
  const list = [];
  for (const [dr, dc] of offsets) {{
    const nr = r + dr, nc = c + dc;
    if (nr >= 0 && nr < MAX_GRID_ROWS && nc >= 0 && nc < getCols(nr)) list.push([nr, nc]);
  }}
  return list;
}}

function pickColor(allowed) {{
  const active = new Set();
  grid.forEach(row => row.forEach(c => {{ if (c && c.color >= 0) active.add(c.color); }}));
  const pool = Array.from(active).filter(c => allowed.includes(c));
  const finalPool = pool.length > 0 ? pool : allowed;
  return finalPool[Math.floor(Math.random() * finalPool.length)];
}}

function loadLevel(idx) {{
  currentLevelIdx = idx;
  const ldata = LEVELS[idx] || LEVELS[0];
  currentScore = 0;
  shotsLeft = ldata.max_shots || 30;
  currentCombo = 0;
  gameState = 'PLAYING';

  grid = [];
  for (let r = 0; r < MAX_GRID_ROWS; r++) {{
    const cols = getCols(r);
    const rowArr = [];
    const rowStr = ldata.layout_rows ? ldata.layout_rows[r] : null;
    for (let c = 0; c < cols; c++) {{
      let col = -1, spec = 0;
      if (rowStr && c < rowStr.length) col = CHAR_MAP[rowStr[c]] !== undefined ? CHAR_MAP[rowStr[c]] : -1;
      const key = `${{r}},${{c}}`;
      if (ldata.special_layout && ldata.special_layout[key]) spec = ldata.special_layout[key];
      if (col >= 0 || spec > 0) rowArr.push({{ color: col, special: spec, radius: BUBBLE_RADIUS }});
      else rowArr.push(null);
    }}
    grid.push(rowArr);
  }}

  const allowed = ldata.allowed_colors || [0, 1];
  curColor = pickColor(allowed);
  nextColor = pickColor(allowed);
  activeProj = null;
  particles = [];
  popups = [];
  trauma = 0;
  lumiState = 'IDLE';

  updateHUD();

  const lvlId = ldata.level_id || (idx + 1);
  if (TUTORIALS[lvlId] && !seenTutorials.includes(lvlId)) {{
    document.getElementById('txtTutTitle').innerText = TUTORIALS[lvlId].title;
    document.getElementById('txtTutBody').innerText = TUTORIALS[lvlId].text;
    document.getElementById('modalTutorial').classList.remove('hidden');
    gameState = 'PAUSED';
    seenTutorials.push(lvlId);
    saveState();
  }}
}}

function updateHUD() {{
  const ldata = LEVELS[currentLevelIdx] || LEVELS[0];
  document.getElementById('txtLvlName').innerText = `LVL ${{ldata.level_id || currentLevelIdx + 1}}: ${{ldata.level_name.split(':')[1] || ldata.level_name}}`;
  document.getElementById('txtScore').innerText = `SCORE: ${{currentScore}}`;
  document.getElementById('txtShots').innerText = `SHOTS: ${{shotsLeft}}`;
  
  let s = 0;
  const tgt = ldata.target_score || 300;
  if (currentScore >= tgt * 0.3) s = 1;
  if (currentScore >= tgt) s = 2;
  if (currentScore >= tgt * 1.5) s = 3;
  document.getElementById('txtStars').innerText = s === 3 ? '★ ★ ★' : s === 2 ? '★ ★ ☆' : s === 1 ? '★ ☆ ☆' : '☆ ☆ ☆';

  if (currentCombo > 1) {{
    document.getElementById('txtCombo').innerText = `COMBO x${{currentCombo}}!`;
    document.getElementById('txtCombo').classList.remove('hidden');
  }} else {{
    document.getElementById('txtCombo').classList.add('hidden');
  }}
}}

function showScreen(name) {{
  currentScreen = name;
  document.getElementById('screenMenu').classList.toggle('hidden', name !== 'MENU');
  document.getElementById('screenMap').classList.toggle('hidden', name !== 'WORLD_MAP');
  document.getElementById('screenSettings').classList.toggle('hidden', name !== 'SETTINGS');
  document.getElementById('hud').classList.toggle('hidden', name !== 'GAMEPLAY');
  document.getElementById('bottomControls').classList.toggle('hidden', name !== 'GAMEPLAY');

  if (name === 'MENU') {{
    document.getElementById('txtMenuTotalStars').innerText = `★ ${{getTotalStars()}} / 90`;
  }} else if (name === 'WORLD_MAP') {{
    renderWorldMap();
  }}
}}

function renderWorldMap() {{
  document.getElementById('txtMapStars').innerText = `★ ${{getTotalStars()}} / 90`;
  const w = WORLDS.find(w => w.id === activeWorldTab) || WORLDS[0];
  document.getElementById('txtWorldTitle').innerText = `${{w.icon}} ${{w.name}}`;
  document.getElementById('txtWorldRange').innerText = `Levels ${{w.start}}-${{w.end}}`;
  document.getElementById('txtWorldDesc').innerText = w.desc;

  const gridEl = document.getElementById('levelsGrid');
  gridEl.innerHTML = '';
  const isWorldLocked = getTotalStars() < w.reqStars;

  LEVELS.filter(l => l.level_id >= w.start && l.level_id <= w.end).forEach(lvl => {{
    const isUnlocked = unlockedLevels.includes(lvl.level_id) && !isWorldLocked;
    const stars = starsEarned[lvl.level_id] || 0;
    const btn = document.createElement('button');
    btn.className = `level-badge ${{!isUnlocked ? 'locked' : ''}}`;
    btn.innerHTML = `<span>${{lvl.level_id}}</span><span style="font-size: 10px; color: #fbbf24; margin-top: 2px;">${{isUnlocked ? (stars === 3 ? '★★★' : stars === 2 ? '★★☆' : stars === 1 ? '★☆☆' : '☆☆☆') : '🔒'}}</span>`;
    if (isUnlocked) {{
      btn.onclick = () => {{ playSound('BOUNCE'); loadLevel(lvl.level_id - 1); showScreen('GAMEPLAY'); }};
    }}
    gridEl.appendChild(btn);
  }});
}}

// Canvas & Physics
const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');

let lastT = performance.now();
function gameLoop(now) {{
  const dt = Math.min((now - lastT) / 1000, 0.05);
  lastT = now;

  if (currentScreen === 'GAMEPLAY') {{
    updatePhysics(dt);
    drawGame(dt);
  }}
  requestAnimationFrame(gameLoop);
}}

function updatePhysics(dt) {{
  if (trauma > 0) trauma = Math.max(0, trauma - dt * 2.5);
  lumiTimer += dt;
  if (lumiState !== 'IDLE' && lumiTimer > 1.8) lumiState = 'IDLE';

  for (let i = popups.length - 1; i >= 0; i--) {{
    popups[i].y -= popups[i].vy * dt;
    popups[i].alpha -= dt * 1.2;
    if (popups[i].alpha <= 0) popups.splice(i, 1);
  }}

  for (let i = particles.length - 1; i >= 0; i--) {{
    const p = particles[i];
    p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 400 * dt;
    p.life -= dt; p.alpha = Math.max(0, p.life / p.maxLife);
    if (p.life <= 0) particles.splice(i, 1);
  }}

  if (!activeProj || gameState === 'PAUSED') return;

  const move = SHOT_SPEED * dt;
  let nx = activeProj.x + activeProj.vx * move;
  let ny = activeProj.y + activeProj.vy * move;

  const lb = LEFT_WALL_X + BUBBLE_RADIUS, rb = RIGHT_WALL_X - BUBBLE_RADIUS, cb = GRID_START_Y + BUBBLE_RADIUS;
  if (nx <= lb) {{ nx = lb + (lb - nx); activeProj.vx = Math.abs(activeProj.vx); playSound('BOUNCE'); }}
  if (nx >= rb) {{ nx = rb - (nx - rb); activeProj.vx = -Math.abs(activeProj.vx); playSound('BOUNCE'); }}

  activeProj.x = nx; activeProj.y = ny;

  if (ny <= cb) {{ attachProj(activeProj); return; }}

  const threshSq = Math.pow(BUBBLE_DIAMETER * 0.94, 2);
  for (let r = 0; r < MAX_GRID_ROWS; r++) {{
    for (let c = 0; c < getCols(r); c++) {{
      if (grid[r][c]) {{
        const bp = gridToWorld(r, c);
        const dx = activeProj.x - bp.x, dy = activeProj.y - bp.y;
        if (dx*dx + dy*dy <= threshSq) {{ attachProj(activeProj); return; }}
      }}
    }}
  }}
}}

function attachProj(proj) {{
  gameState = 'RESOLVING';
  activeProj = null;

  let bestDSq = Infinity, snap = {{ r: 0, c: 0 }};
  for (let r = 0; r < MAX_GRID_ROWS; r++) {{
    for (let c = 0; c < getCols(r); c++) {{
      if (!grid[r][c]) {{
        const pos = gridToWorld(r, c);
        const dSq = Math.pow(proj.x - pos.x, 2) + Math.pow(proj.y - pos.y, 2);
        if (dSq < bestDSq) {{ bestDSq = dSq; snap = {{ r, c }}; }}
      }}
    }}
  }}

  grid[snap.r][snap.c] = {{ color: proj.color, special: proj.special || 0, radius: BUBBLE_RADIUS }};
  setTimeout(() => resolveGrid(snap), 80);
}}

function resolveGrid(snap) {{
  const placed = grid[snap.r][snap.c];
  let cleared = [];
  let isSpecial = false;

  if (placed && placed.special === 1) {{ // Bomb
    isSpecial = true;
    cleared.push([snap.r, snap.c]);
    getNeighbors(snap.r, snap.c).forEach(n => {{ if (grid[n[0]][n[1]]) cleared.push(n); }});
    playSound('BOMB');
    trauma = reducedEffects ? 0 : 0.6;
    lumiState = 'LARGE_COMBO'; lumiTimer = 0;
    currentScore += 50;
  }} else if (placed && placed.special === 3) {{ // Lightning
    isSpecial = true;
    for (let c = 0; c < getCols(snap.r); c++) if (grid[snap.r][c]) cleared.push([snap.r, c]);
    playSound('BOUNCE');
    trauma = reducedEffects ? 0 : 0.4;
    lumiState = 'MATCH_SUCCESS'; lumiTimer = 0;
    currentScore += 60;
  }} else {{
    // BFS Matches
    cleared = findMatches(snap.r, snap.c);
  }}

  if (cleared.length >= 3 || isSpecial) {{
    currentCombo++;
    const mult = 1.0 + (currentCombo - 1) * 0.25;
    const matchPts = Math.floor(cleared.length * 10 * mult);
    currentScore += matchPts;
    if (!isSpecial) {{ playSound('POP', currentCombo); lumiState = cleared.length >= 5 ? 'LARGE_COMBO' : 'MATCH_SUCCESS'; lumiTimer = 0; }}

    const sp = gridToWorld(snap.r, snap.c);
    popups.push({{ x: sp.x, y: sp.y, text: `+${{matchPts}}${{currentCombo > 1 ? ` (x${{currentCombo}}!)` : ''}}`, color: '#FAD126', alpha: 1, vy: 80 }});

    cleared.forEach(([cr, cc]) => {{
      const b = grid[cr][cc];
      if (b) {{ emitPop(gridToWorld(cr, cc), b.color); grid[cr][cc] = null; }}
    }});

    // Crack adjacent locked ice
    cleared.forEach(([cr, cc]) => {{
      getNeighbors(cr, cc).forEach(([nr, nc]) => {{
        if (grid[nr][nc] && grid[nr][nc].special === 5) {{
          grid[nr][nc].special = 0;
          currentScore += 25;
          emitPop(gridToWorld(nr, nc), grid[nr][nc].color);
        }}
      }});
    }});

    // Floating check
    const floating = findFloating();
    if (floating.length > 0) {{
      const dropPts = Math.floor(floating.length * 20 * mult);
      currentScore += dropPts;
      playSound('BOUNCE');
      const dp = gridToWorld(floating[0][0], floating[0][1]);
      popups.push({{ x: dp.x, y: dp.y + 20, text: `DROP +${{dropPts}}`, color: '#2ECCDE', alpha: 1, vy: 90 }});
      floating.forEach(([fr, fc]) => {{
        const fb = grid[fr][fc];
        if (fb) {{ emitPop(gridToWorld(fr, fc), fb.color); grid[fr][fc] = null; }}
      }});
    }}
  }} else {{
    currentCombo = 0;
  }}

  updateHUD();
  checkEnd();
}}

function findMatches(sr, sc) {{
  const start = grid[sr][sc];
  if (!start || start.special === 4 || start.special === 5) return [];
  let col = start.color;
  if (start.special === 2) {{
    for (const [nr, nc] of getNeighbors(sr, sc)) {{
      if (grid[nr][nc] && grid[nr][nc].color >= 0) {{ col = grid[nr][nc].color; break; }}
    }}
  }}

  const matched = [], visited = new Set(), q = [[sr, sc]];
  visited.add(`${{sr}},${{sc}}`);

  while (q.length > 0) {{
    const [cr, cc] = q.shift();
    matched.push([cr, cc]);
    for (const [nr, nc] of getNeighbors(cr, cc)) {{
      const k = `${{nr}},${{nc}}`;
      if (visited.has(k)) continue;
      const nb = grid[nr][nc];
      if (!nb || nb.special === 4 || nb.special === 5) continue;
      if (nb.color === col || nb.special === 2) {{ visited.add(k); q.push([nr, nc]); }}
    }}
  }}
  return matched.length >= 3 ? matched : [];
}}

function findFloating() {{
  const anchored = new Set(), q = [];
  for (let c = 0; c < getCols(0); c++) {{
    if (grid[0][c]) {{ q.push([0, c]); anchored.add(`0,${{c}}`); }}
  }}
  while (q.length > 0) {{
    const [cr, cc] = q.shift();
    for (const [nr, nc] of getNeighbors(cr, cc)) {{
      if (grid[nr][nc] && !anchored.has(`${{nr}},${{nc}}`)) {{ anchored.add(`${{nr}},${{nc}}`); q.push([nr, nc]); }}
    }}
  }}
  const floating = [];
  for (let r = 0; r < MAX_GRID_ROWS; r++) {{
    for (let c = 0; c < getCols(r); c++) {{
      if (grid[r][c] && !anchored.has(`${{r}},${{c}}`)) floating.push([r, c]);
    }}
  }}
  return floating;
}}

function emitPop(pos, colId) {{
  if (reducedEffects) return;
  const col = COLOR_MAP[colId] || '#FFFFFF';
  for (let i = 0; i < 8; i++) {{
    const a = Math.random() * Math.PI * 2, s = 60 + Math.random() * 120;
    particles.push({{ x: pos.x, y: pos.y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, color: col, radius: 3, life: 0.35, maxLife: 0.35 }});
  }}
}}

function checkEnd() {{
  const ldata = LEVELS[currentLevelIdx] || LEVELS[0];
  let remaining = 0, lowRow = -1;
  for (let r = 0; r < MAX_GRID_ROWS; r++) {{
    for (let c = 0; c < getCols(r); c++) {{
      if (grid[r][c]) {{ remaining++; if (r > lowRow) lowRow = r; }}
    }}
  }}

  const danger = ldata.danger_row || DEFAULT_DANGER_ROW;
  if (remaining === 0) {{
    gameState = 'WIN'; playSound('WIN'); lumiState = 'WIN';
    const lvlId = ldata.level_id || (currentLevelIdx + 1);
    let earn = 1;
    if (currentScore >= (ldata.target_score || 300)) earn = 2;
    if (currentScore >= (ldata.target_score || 300) * 1.5) earn = 3;

    starsEarned[lvlId] = Math.max(earn, starsEarned[lvlId] || 0);
    highScores[lvlId] = Math.max(currentScore, highScores[lvlId] || 0);
    if (!unlockedLevels.includes(lvlId + 1)) unlockedLevels.push(lvlId + 1);
    saveState();

    document.getElementById('txtWinScore').innerText = currentScore;
    document.getElementById('txtWinStars').innerText = earn === 3 ? '★ ★ ★' : earn === 2 ? '★ ★ ☆' : '★ ☆ ☆';
    document.getElementById('modalWin').classList.remove('hidden');
    return;
  }}

  if (lowRow >= danger) {{
    gameState = 'LOSE'; lumiState = 'LOSE';
    document.getElementById('txtLoseReason').innerText = "Bubbles reached the danger line!";
    document.getElementById('txtLoseScore').innerText = currentScore;
    document.getElementById('modalLose').classList.remove('hidden');
    return;
  }}

  if (shotsLeft <= 0 && !activeProj) {{
    gameState = 'LOSE'; lumiState = 'LOSE';
    document.getElementById('txtLoseReason').innerText = "Out of shots!";
    document.getElementById('txtLoseScore').innerText = currentScore;
    document.getElementById('modalLose').classList.remove('hidden');
    return;
  }}

  gameState = 'PLAYING';
  curColor = nextColor;
  nextColor = pickColor(ldata.allowed_colors || [0, 1]);
}}

function drawGame(dt) {{
  ctx.save();
  ctx.clearRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);

  if (trauma > 0 && !reducedEffects) {{
    const s = Math.pow(trauma, 2) * 12;
    ctx.translate((Math.random() - 0.5) * s, (Math.random() - 0.5) * s);
  }}

  // Background
  const grad = ctx.createLinearGradient(0, 0, 0, SCREEN_HEIGHT);
  grad.addColorStop(0, '#0F1E19'); grad.addColorStop(0.5, '#162D24'); grad.addColorStop(1, '#0C1613');
  ctx.fillStyle = grad; ctx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);

  // Bounds & Danger Line
  ctx.strokeStyle = 'rgba(100, 200, 150, 0.25)'; ctx.lineWidth = 3; ctx.setLineDash([8, 8]);
  ctx.beginPath();
  ctx.moveTo(LEFT_WALL_X, GRID_START_Y); ctx.lineTo(LEFT_WALL_X, 1050);
  ctx.moveTo(RIGHT_WALL_X, GRID_START_Y); ctx.lineTo(RIGHT_WALL_X, 1050);
  ctx.stroke(); ctx.setLineDash([]);

  const dangerY = GRID_START_Y + (LEVELS[currentLevelIdx].danger_row || DEFAULT_DANGER_ROW) * ROW_SPACING;
  ctx.strokeStyle = 'rgba(235, 64, 64, 0.55)'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(LEFT_WALL_X, dangerY); ctx.lineTo(RIGHT_WALL_X, dangerY); ctx.stroke();

  // Aim Guide
  if (isAiming && gameState === 'PLAYING') {{
    ctx.strokeStyle = COLOR_MAP[curColor] || '#FFF'; ctx.lineWidth = 4; ctx.setLineDash([8, 8]);
    ctx.beginPath();
    ctx.moveTo(SHOOTER_POS.x, SHOOTER_POS.y);
    ctx.lineTo(SHOOTER_POS.x + Math.cos(aimAngle) * 400, SHOOTER_POS.y + Math.sin(aimAngle) * 400);
    ctx.stroke(); ctx.setLineDash([]);
  }}

  // Grid
  for (let r = 0; r < MAX_GRID_ROWS; r++) {{
    for (let c = 0; c < getCols(r); c++) {{
      if (grid[r][c]) {{
        const p = gridToWorld(r, c);
        drawBubble(p.x, p.y, grid[r][c].color, grid[r][c].special, BUBBLE_RADIUS);
      }}
    }}
  }}

  // Projectile
  if (activeProj) drawBubble(activeProj.x, activeProj.y, activeProj.color, activeProj.special, BUBBLE_RADIUS);

  // Shooter & Next
  ctx.fillStyle = 'rgba(255, 255, 255, 0.08)'; ctx.beginPath(); ctx.arc(NEXT_POS.x, NEXT_POS.y, 36, 0, Math.PI * 2); ctx.fill();
  drawBubble(NEXT_POS.x, NEXT_POS.y, nextColor, 0, 26);

  ctx.fillStyle = 'rgba(255, 255, 255, 0.12)'; ctx.beginPath(); ctx.arc(SHOOTER_POS.x, SHOOTER_POS.y, 44, 0, Math.PI * 2); ctx.fill();
  if (gameState === 'PLAYING') drawBubble(SHOOTER_POS.x, SHOOTER_POS.y, curColor, 0, BUBBLE_RADIUS);

  // Lumi Companion
  drawLumi(LUMI_POS.x, LUMI_POS.y, lumiState);

  // Particles
  particles.forEach(p => {{
    ctx.fillStyle = p.color; ctx.globalAlpha = p.alpha;
    ctx.beginPath(); ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2); ctx.fill();
    ctx.globalAlpha = 1;
  }});

  // Popups
  popups.forEach(pop => {{
    ctx.font = 'bold 24px sans-serif'; ctx.fillStyle = pop.color; ctx.globalAlpha = pop.alpha;
    ctx.textAlign = 'center'; ctx.fillText(pop.text, pop.x, pop.y); ctx.globalAlpha = 1;
  }});

  ctx.restore();
}}

function drawBubble(x, y, colId, spec, r) {{
  ctx.save();
  ctx.translate(x, y);

  const base = COLOR_MAP[colId] || '#999';
  const g = ctx.createRadialGradient(-r * 0.3, -r * 0.35, r * 0.1, 0, 0, r);
  if (spec === 1) {{ g.addColorStop(0, '#FFA500'); g.addColorStop(1, '#8B0000'); }}
  else if (spec === 2) {{ g.addColorStop(0, '#FFF'); g.addColorStop(0.5, '#FF69B4'); g.addColorStop(1, '#9370DB'); }}
  else if (spec === 3) {{ g.addColorStop(0, '#FFFFE0'); g.addColorStop(1, '#B8860B'); }}
  else if (spec === 4) {{ g.addColorStop(0, '#A9A9A9'); g.addColorStop(1, '#2F4F4F'); }}
  else {{ g.addColorStop(0, '#FFF'); g.addColorStop(0.35, base); g.addColorStop(1, base); }}

  ctx.fillStyle = g; ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.fill();

  if (spec === 5) {{
    ctx.fillStyle = 'rgba(200, 240, 255, 0.55)'; ctx.beginPath(); ctx.arc(0, 0, r + 2, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#E0F7FA'; ctx.lineWidth = 2; ctx.stroke();
  }}

  // Specular
  ctx.fillStyle = 'rgba(255, 255, 255, 0.6)'; ctx.beginPath(); ctx.arc(-r * 0.35, -r * 0.38, r * 0.3, 0, Math.PI * 2); ctx.fill();

  // Runes/Icons
  ctx.font = `bold ${{Math.floor(r * 0.75)}}px sans-serif`; ctx.fillStyle = '#FFF'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  if (spec === 1) ctx.fillText('💣', 0, 2);
  else if (spec === 2) ctx.fillText('🌈', 0, 2);
  else if (spec === 3) ctx.fillText('⚡', 0, 2);
  else if (spec === 4) ctx.fillText('🪨', 0, 2);
  else if (spec === 5) ctx.fillText('🔒', 0, 2);
  else if (showRunes && RUNES[colId]) ctx.fillText(RUNES[colId], 0, 2);

  ctx.restore();
}}

function drawLumi(x, y, st) {{
  ctx.save();
  ctx.translate(x, y + Math.sin(performance.now() * 0.004) * 4);
  const glow = ctx.createRadialGradient(0, 0, 5, 0, 0, 36);
  glow.addColorStop(0, 'rgba(255, 240, 160, 0.6)'); glow.addColorStop(1, 'rgba(255, 240, 160, 0)');
  ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(0, 0, 36, 0, Math.PI * 2); ctx.fill();

  ctx.fillStyle = '#FFF8DC'; ctx.beginPath(); ctx.arc(0, 0, 24, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#2C1B00';
  if (st === 'WIN' || st === 'LARGE_COMBO') {{
    ctx.strokeStyle = '#2C1B00'; ctx.lineWidth = 2.5;
    ctx.beginPath(); ctx.arc(-7, -2, 4, Math.PI, 0); ctx.arc(7, -2, 4, Math.PI, 0); ctx.stroke();
  }} else {{
    ctx.beginPath(); ctx.arc(-7, -2, 3.5, 0, Math.PI * 2); ctx.arc(7, -2, 3.5, 0, Math.PI * 2); ctx.fill();
  }}
  ctx.fillStyle = 'rgba(255, 105, 180, 0.45)';
  ctx.beginPath(); ctx.arc(-12, 4, 4, 0, Math.PI * 2); ctx.arc(12, 4, 4, 0, Math.PI * 2); ctx.fill();
  ctx.restore();
}}

// Input Handlers
function handleAim(e) {{
  if (gameState !== 'PLAYING') return;
  const rect = canvas.getBoundingClientRect();
  const scaleX = SCREEN_WIDTH / rect.width, scaleY = SCREEN_HEIGHT / rect.height;
  const tx = (e.clientX - rect.left) * scaleX, ty = (e.clientY - rect.top) * scaleY;

  const dx = tx - SHOOTER_POS.x, dy = ty - SHOOTER_POS.y;
  let a = Math.atan2(dy, dx);
  const minA = (-165) * Math.PI / 180, maxA = (-15) * Math.PI / 180;
  aimAngle = a > 0 ? (dx < 0 ? minA : maxA) : Math.max(minA, Math.min(maxA, a));
}}

canvas.addEventListener('pointerdown', e => {{ isAiming = true; handleAim(e); }});
canvas.addEventListener('pointermove', e => {{ if (isAiming) handleAim(e); }});
canvas.addEventListener('pointerup', () => {{
  if (isAiming && gameState === 'PLAYING') {{
    isAiming = false;
    if (!activeProj && shotsLeft > 0) {{
      gameState = 'SHOOTING'; shotsLeft--;
      activeProj = {{ x: SHOOTER_POS.x, y: SHOOTER_POS.y, vx: Math.cos(aimAngle), vy: Math.sin(aimAngle), color: curColor, special: 0 }};
      updateHUD();
    }}
  }}
}});

// UI Event Wireups
document.getElementById('btnMenuPlay').onclick = () => {{
  playSound('BOUNCE');
  loadLevel(unlockedLevels[unlockedLevels.length - 1] - 1);
  showScreen('GAMEPLAY');
}};
document.getElementById('btnMenuMap').onclick = () => {{ playSound('BOUNCE'); showScreen('WORLD_MAP'); }};
document.getElementById('btnMenuSettings').onclick = () => {{ playSound('BOUNCE'); showScreen('SETTINGS'); }};

document.getElementById('btnMapBack').onclick = () => {{ playSound('BOUNCE'); showScreen('MENU'); }};
document.getElementById('tabWorld1').onclick = () => {{ activeWorldTab = 1; renderWorldMap(); }};
document.getElementById('tabWorld2').onclick = () => {{ activeWorldTab = 2; renderWorldMap(); }};
document.getElementById('tabWorld3').onclick = () => {{ activeWorldTab = 3; renderWorldMap(); }};

document.getElementById('btnSettingsBack').onclick = () => {{ playSound('BOUNCE'); showScreen('MENU'); }};
document.getElementById('chkSound').onchange = (e) => soundEnabled = e.target.checked;
document.getElementById('chkRunes').onchange = (e) => showRunes = e.target.checked;
document.getElementById('chkReduced').onchange = (e) => reducedEffects = e.target.checked;
document.getElementById('btnResetData').onclick = () => {{
  if (confirm("Reset all game data?")) {{
    localStorage.clear();
    starsEarned = {{ "1": 0 }}; unlockedLevels = [1]; highScores = {{}}; seenTutorials = [];
    alert("Reset successful!");
    showScreen('MENU');
  }}
}};

document.getElementById('btnHudMap').onclick = () => {{ playSound('BOUNCE'); showScreen('WORLD_MAP'); }};
document.getElementById('btnPause').onclick = () => {{
  playSound('BOUNCE');
  gameState = 'PAUSED';
  document.getElementById('modalPause').classList.remove('hidden');
}};
document.getElementById('btnResume').onclick = () => {{
  playSound('BOUNCE');
  gameState = 'PLAYING';
  document.getElementById('modalPause').classList.add('hidden');
}};
document.getElementById('btnRestart').onclick = () => {{
  document.getElementById('modalPause').classList.add('hidden');
  loadLevel(currentLevelIdx);
}};
document.getElementById('btnPauseMap').onclick = () => {{
  document.getElementById('modalPause').classList.add('hidden');
  showScreen('WORLD_MAP');
}};

document.getElementById('btnSwap').onclick = () => {{
  if (gameState !== 'PLAYING') return;
  const tmp = curColor; curColor = nextColor; nextColor = tmp;
}};

document.getElementById('btnTutOk').onclick = () => {{
  playSound('BOUNCE');
  document.getElementById('modalTutorial').classList.add('hidden');
  gameState = 'PLAYING';
}};

document.getElementById('btnWinNext').onclick = () => {{
  document.getElementById('modalWin').classList.add('hidden');
  loadLevel((currentLevelIdx + 1) % LEVELS.length);
}};
document.getElementById('btnWinReplay').onclick = () => {{
  document.getElementById('modalWin').classList.add('hidden');
  loadLevel(currentLevelIdx);
}};
document.getElementById('btnWinMap').onclick = () => {{
  document.getElementById('modalWin').classList.add('hidden');
  showScreen('WORLD_MAP');
}};

document.getElementById('btnLoseRetry').onclick = () => {{
  document.getElementById('modalLose').classList.add('hidden');
  loadLevel(currentLevelIdx);
}};
document.getElementById('btnLoseMap').onclick = () => {{
  document.getElementById('modalLose').classList.add('hidden');
  showScreen('WORLD_MAP');
}};

// Startup
loadLevel(0);
showScreen('MENU');
requestAnimationFrame(gameLoop);
</script>
</body>
</html>
"""

os.makedirs(os.path.join(kamand_dir, "builds/web"), exist_ok=True)
with open(os.path.join(kamand_dir, "builds/web/lumi-standalone.html"), "w") as f:
    f.write(html_content)
with open(os.path.join(kamand_dir, "builds/web/index.html"), "w") as f:
    f.write(html_content)

print("Generated standalone builds/web/lumi-standalone.html and builds/web/index.html successfully!")
