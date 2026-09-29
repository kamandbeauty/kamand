import React, { useEffect, useRef, useState } from 'react';
import levelsData from './data/levels_bundle.json';

// Exact constants mirroring Godot 4 Constants.gd
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
const SHOOTER_POS = { x: 360, y: 1150 };
const NEXT_BUBBLE_POS = { x: 250, y: 1150 };
const LUMI_POS = { x: 575, y: 1155 };
const SHOT_SPEED = 1400;
const MIN_AIM_ANGLE_DEG = 15;
const MAX_TRAJECTORY_BOUNCES = 3;
const POINTS_PER_MATCH = 10;
const POINTS_PER_DROP = 20;
const POINTS_PER_BOMB = 50;
const POINTS_PER_LIGHTNING = 60;
const POINTS_PER_LOCK_CRACK = 25;
const COMBO_BONUS_MULTIPLIER = 0.25;

const COLOR_MAP = {
  0: '#EB4040', // RED
  1: '#3373F2', // BLUE
  2: '#38D159', // GREEN
  3: '#FAD126', // YELLOW
  4: '#AE47E6', // PURPLE
  5: '#2ECCDE', // CYAN
};

const COLOR_NAMES = {
  0: 'Red',
  1: 'Blue',
  2: 'Green',
  3: 'Yellow',
  4: 'Purple',
  5: 'Cyan'
};

const RUNE_SYMBOLS = {
  0: '▲', // Fire
  1: '💧', // Water
  2: '🌿', // Nature
  3: '★', // Light
  4: '✦', // Magic
  5: '❄', // Frost
};

const CHAR_TO_COLOR = {
  'R': 0, 'B': 1, 'G': 2, 'Y': 3, 'P': 4, 'C': 5, '.': -1
};

const WORLDS = [
  { id: 1, name: "Whispering Woods", icon: "🌲", startLevel: 1, endLevel: 10, requiredStars: 0, desc: "A lush, serene woodland full of gentle magic." },
  { id: 2, name: "Crystal Caverns", icon: "💎", startLevel: 11, endLevel: 20, requiredStars: 10, desc: "Glimmering subterranean grottos charged with arcane energy." },
  { id: 3, name: "Sunken Grove", icon: "🌊", startLevel: 21, endLevel: 30, requiredStars: 25, desc: "Ancient mossy ruins guarded by hardened stone obstacles." }
];

const TUTORIALS = {
  1: { title: "WELCOME TO LUMI!", text: "Aim by dragging or moving your mouse, then release to shoot. Match 3 or more bubbles of the same color to pop them!" },
  4: { title: "COMBOS & DROPS", text: "Match bubbles consecutive times for multiplier combos! Severing bubbles from the ceiling drops them for massive drop points!" },
  11: { title: "BOMB BUBBLES 💣", text: "Bomb bubbles detonate a 3x3 blast radius, clearing all neighboring bubbles instantly!" },
  15: { title: "FROZEN ICE SHELLS ❄", text: "Locked ice bubbles cannot be matched directly. Pop standard bubbles adjacent to them to crack their frozen shell!" },
  21: { title: "STONE BOULDERS 🪨", text: "Stone bubbles are indestructible to normal matches. Drop them by severing their ceiling anchors or detonating nearby bombs!" },
  25: { title: "TRIPLE THREAT", text: "Combine Bombs, Lightning, and Rainbow bubbles to solve advanced puzzle formations!" }
};

export default function App() {
  const canvasRef = useRef(null);

  // App Navigation States: 'MENU' | 'WORLD_MAP' | 'GAMEPLAY' | 'SETTINGS'
  const [currentScreen, setCurrentScreen] = useState('MENU');
  const [activeWorldTab, setActiveWorldTab] = useState(1);
  const [levelIndex, setLevelIndex] = useState(0);

  // Gameplay State
  const [score, setScore] = useState(0);
  const [highScores, setHighScores] = useState(() => {
    try {
      const saved = localStorage.getItem('lumi_highscores_v3');
      return saved ? JSON.parse(saved) : {};
    } catch {
      return {};
    }
  });
  const [starsEarned, setStarsEarned] = useState(() => {
    try {
      const saved = localStorage.getItem('lumi_stars_v3');
      return saved ? JSON.parse(saved) : { 1: 0 };
    } catch {
      return { 1: 0 };
    }
  });
  const [unlockedLevels, setUnlockedLevels] = useState(() => {
    try {
      const saved = localStorage.getItem('lumi_unlocked_v3');
      return saved ? JSON.parse(saved) : [1];
    } catch {
      return [1];
    }
  });
  const [seenTutorials, setSeenTutorials] = useState(() => {
    try {
      const saved = localStorage.getItem('lumi_tutorials_v3');
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });

  const [shotsRemaining, setShotsRemaining] = useState(30);
  const [combo, setCombo] = useState(0);
  const [gameState, setGameState] = useState('PLAYING'); // 'PLAYING' | 'SHOOTING' | 'RESOLVING' | 'WIN' | 'LOSE' | 'PAUSED'
  const [winModalData, setWinModalData] = useState(null);
  const [loseModalData, setLoseModalData] = useState(null);
  const [activeTutorial, setActiveTutorial] = useState(null);

  // Preferences
  const [soundEnabled, setSoundEnabled] = useState(true);
  const [reducedEffects, setReducedEffects] = useState(false);
  const [showRunes, setShowRunes] = useState(true);

  // Runtime Game Engine Refs
  const gridRef = useRef([]); // 14 rows x dynamic cols
  const activeProjectileRef = useRef(null);
  const currentColorRef = useRef(0);
  const nextColorRef = useRef(1);
  const isAimingRef = useRef(false);
  const aimAngleRef = useRef(-Math.PI / 2);
  const aimTargetRef = useRef({ x: 360, y: 800 });
  const particlesRef = useRef([]);
  const scorePopupsRef = useRef([]);
  const screenTraumaRef = useRef(0);
  const lumiStateRef = useRef('IDLE');
  const lumiTimerRef = useRef(0);
  const animFrameRef = useRef(null);
  const audioCtxRef = useRef(null);

  const totalStars = Object.values(starsEarned).reduce((a, b) => a + b, 0);

  // Initialize or resume Web Audio context
  const getAudioContext = () => {
    if (!audioCtxRef.current) {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (AudioCtx) {
        audioCtxRef.current = new AudioCtx();
      }
    }
    if (audioCtxRef.current && audioCtxRef.current.state === 'suspended') {
      audioCtxRef.current.resume();
    }
    return audioCtxRef.current;
  };

  const playSynthSound = (type, param = 1) => {
    if (!soundEnabled) return;
    try {
      const ctx = getAudioContext();
      if (!ctx) return;
      const t = ctx.currentTime;

      if (type === 'POP') {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        const baseFreq = 480 + (param * 65);
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(baseFreq, t);
        osc.frequency.exponentialRampToValueAtTime(baseFreq * 1.8, t + 0.08);
        gain.gain.setValueAtTime(0.3, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.09);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(t);
        osc.stop(t + 0.09);
      } else if (type === 'BOMB') {
        // Low boom + noise
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(150, t);
        osc.frequency.exponentialRampToValueAtTime(30, t + 0.35);
        gain.gain.setValueAtTime(0.6, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.38);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(t);
        osc.stop(t + 0.38);
      } else if (type === 'LIGHTNING') {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'square';
        osc.frequency.setValueAtTime(800, t);
        osc.frequency.linearRampToValueAtTime(200, t + 0.18);
        gain.gain.setValueAtTime(0.4, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.2);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(t);
        osc.stop(t + 0.2);
      } else if (type === 'CRACK') {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(1200, t);
        osc.frequency.exponentialRampToValueAtTime(600, t + 0.07);
        gain.gain.setValueAtTime(0.35, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.08);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(t);
        osc.stop(t + 0.08);
      } else if (type === 'BOUNCE') {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(320, t);
        osc.frequency.exponentialRampToValueAtTime(220, t + 0.05);
        gain.gain.setValueAtTime(0.25, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.05);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(t);
        osc.stop(t + 0.05);
      } else if (type === 'DROP') {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(550, t);
        osc.frequency.linearRampToValueAtTime(350, t + 0.12);
        gain.gain.setValueAtTime(0.3, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.12);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(t);
        osc.stop(t + 0.12);
      } else if (type === 'WIN') {
        [523.25, 659.25, 783.99, 1046.50].forEach((freq, idx) => {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'sine';
          osc.frequency.setValueAtTime(freq, t + idx * 0.09);
          gain.gain.setValueAtTime(0.3, t + idx * 0.09);
          gain.gain.exponentialRampToValueAtTime(0.001, t + idx * 0.09 + 0.22);
          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(t + idx * 0.09);
          osc.stop(t + idx * 0.09 + 0.22);
        });
      } else if (type === 'LOSE') {
        [380, 320, 260].forEach((freq, idx) => {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'sawtooth';
          osc.frequency.setValueAtTime(freq, t + idx * 0.12);
          gain.gain.setValueAtTime(0.3, t + idx * 0.12);
          gain.gain.exponentialRampToValueAtTime(0.001, t + idx * 0.12 + 0.2);
          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(t + idx * 0.12);
          osc.stop(t + idx * 0.12 + 0.2);
        });
      }
    } catch {
      // Audio playback silently ignored if context blocked
    }
  };

  // Save Persistence to localStorage
  const saveUserData = (newHighScores, newStars, newUnlocked, newTutorials) => {
    try {
      localStorage.setItem('lumi_highscores_v3', JSON.stringify(newHighScores));
      localStorage.setItem('lumi_stars_v3', JSON.stringify(newStars));
      localStorage.setItem('lumi_unlocked_v3', JSON.stringify(newUnlocked));
      localStorage.setItem('lumi_tutorials_v3', JSON.stringify(newTutorials));
    } catch (e) {
      console.error(e);
    }
  };

  const getColsForRow = (r) => (r % 2 === 0 ? GRID_COLUMNS_EVEN : GRID_COLUMNS_ODD);
  const getRowOffsetX = (r) => (r % 2 === 0 ? LEFT_WALL_X + BUBBLE_RADIUS : LEFT_WALL_X + BUBBLE_RADIUS + BUBBLE_RADIUS);

  const gridToWorld = (r, c) => ({
    x: getRowOffsetX(r) + c * BUBBLE_DIAMETER,
    y: GRID_START_Y + r * ROW_SPACING
  });

  const getNeighbors = (r, c) => {
    const isEven = r % 2 === 0;
    const offsets = [
      [0, -1], [0, 1],
      [-1, isEven ? -1 : 0], [-1, isEven ? 0 : 1],
      [1, isEven ? -1 : 0], [1, isEven ? 0 : 1]
    ];
    const neighbors = [];
    for (const [dr, dc] of offsets) {
      const nr = r + dr;
      const nc = c + dc;
      if (nr >= 0 && nr < MAX_GRID_ROWS && nc >= 0 && nc < getColsForRow(nr)) {
        neighbors.push([nr, nc]);
      }
    }
    return neighbors;
  };

  // Pick next random color from allowed and currently active colors
  const pickNextColor = (allowedColors) => {
    const activeColors = new Set();
    gridRef.current.forEach(row => {
      row.forEach(cell => {
        if (cell && cell.color >= 0) activeColors.add(cell.color);
      });
    });
    const pool = Array.from(activeColors).filter(c => allowedColors.includes(c));
    const finalPool = pool.length > 0 ? pool : allowedColors;
    return finalPool[Math.floor(Math.random() * finalPool.length)];
  };

  // Load selected level
  const loadLevel = (idx) => {
    const curLevel = levelsData[idx] || levelsData[0];
    setLevelIndex(idx);
    setScore(0);
    setCombo(0);
    setShotsRemaining(curLevel.max_shots || 30);
    setGameState('PLAYING');
    setWinModalData(null);
    setLoseModalData(null);

    // Initialize 2D grid
    const newGrid = [];
    for (let r = 0; r < MAX_GRID_ROWS; r++) {
      const cols = getColsForRow(r);
      const rowArr = [];
      const rowLayout = curLevel.layout_rows ? curLevel.layout_rows[r] : null;
      for (let c = 0; c < cols; c++) {
        let colVal = -1;
        let specVal = 0;
        if (rowLayout && c < rowLayout.length) {
          const ch = rowLayout[c];
          colVal = CHAR_TO_COLOR[ch] !== undefined ? CHAR_TO_COLOR[ch] : -1;
        }
        const key = `${r},${c}`;
        if (curLevel.special_layout && curLevel.special_layout[key]) {
          specVal = curLevel.special_layout[key];
        }
        if (colVal >= 0 || specVal > 0) {
          rowArr.push({ color: colVal, special: specVal, radius: BUBBLE_RADIUS, alpha: 1.0, scale: 1.0 });
        } else {
          rowArr.push(null);
        }
      }
      newGrid.push(rowArr);
    }
    gridRef.current = newGrid;

    // Setup shooter bubbles
    const allowed = curLevel.allowed_colors || [0, 1];
    currentColorRef.current = pickNextColor(allowed);
    nextColorRef.current = pickNextColor(allowed);
    activeProjectileRef.current = null;
    particlesRef.current = [];
    scorePopupsRef.current = [];
    screenTraumaRef.current = 0;
    lumiStateRef.current = 'IDLE';

    // Show tutorial if level has one and hasn't been seen
    const lvlId = curLevel.level_id || (idx + 1);
    if (TUTORIALS[lvlId] && !seenTutorials.includes(lvlId)) {
      setActiveTutorial(TUTORIALS[lvlId]);
      setGameState('PAUSED');
      const updated = [...seenTutorials, lvlId];
      setSeenTutorials(updated);
      saveUserData(highScores, starsEarned, unlockedLevels, updated);
    } else {
      setActiveTutorial(null);
    }
  };

  useEffect(() => {
    loadLevel(0);
  }, []);

  // Main Canvas Rendering & Physics Game Loop
  useEffect(() => {
    let lastTime = performance.now();

    const renderLoop = (currentTime) => {
      const dt = Math.min((currentTime - lastTime) / 1000, 0.05);
      lastTime = currentTime;

      const canvas = canvasRef.current;
      if (canvas && currentScreen === 'GAMEPLAY') {
        const ctx = canvas.getContext('2d');
        updatePhysics(dt);
        drawGame(ctx, dt);
      }

      animFrameRef.current = requestAnimationFrame(renderLoop);
    };

    animFrameRef.current = requestAnimationFrame(renderLoop);
    return () => cancelAnimationFrame(animFrameRef.current);
  }, [currentScreen, gameState, reducedEffects, showRunes]);

  // Projectile Kinematics & Grid Attachment
  const updatePhysics = (dt) => {
    // Screen trauma decay
    if (screenTraumaRef.current > 0) {
      screenTraumaRef.current = Math.max(0, screenTraumaRef.current - dt * 2.5);
    }

    // Lumi timer update
    lumiTimerRef.current += dt;
    if (lumiStateRef.current !== 'IDLE' && lumiTimerRef.current > 1.8) {
      lumiStateRef.current = 'IDLE';
    }

    // Update floating score popups
    for (let i = scorePopupsRef.current.length - 1; i >= 0; i--) {
      const pop = scorePopupsRef.current[i];
      pop.y -= pop.vy * dt;
      pop.alpha -= dt * 1.2;
      if (pop.alpha <= 0) {
        scorePopupsRef.current.splice(i, 1);
      }
    }

    // Update particles
    for (let i = particlesRef.current.length - 1; i >= 0; i--) {
      const p = particlesRef.current[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += (p.gravity || 400) * dt;
      p.life -= dt;
      p.alpha = Math.max(0, p.life / p.maxLife);
      if (p.life <= 0) {
        particlesRef.current.splice(i, 1);
      }
    }

    const proj = activeProjectileRef.current;
    if (!proj || gameState === 'PAUSED') return;

    // Step projectile
    const moveDist = SHOT_SPEED * dt;
    let nextX = proj.x + proj.vx * moveDist;
    let nextY = proj.y + proj.vy * moveDist;

    const leftBound = LEFT_WALL_X + BUBBLE_RADIUS;
    const rightBound = RIGHT_WALL_X - BUBBLE_RADIUS;
    const ceilingBound = GRID_START_Y + BUBBLE_RADIUS;

    // Left wall bounce
    if (nextX <= leftBound) {
      nextX = leftBound + (leftBound - nextX);
      proj.vx = Math.abs(proj.vx);
      playSynthSound('BOUNCE');
      spawnBounceSparks(leftBound, nextY);
    }
    // Right wall bounce
    if (nextX >= rightBound) {
      nextX = rightBound - (nextX - rightBound);
      proj.vx = -Math.abs(proj.vx);
      playSynthSound('BOUNCE');
      spawnBounceSparks(rightBound, nextY);
    }

    proj.x = nextX;
    proj.y = nextY;

    // Check ceiling hit
    if (nextY <= ceilingBound) {
      attachProjectileToGrid(proj);
      return;
    }

    // Check collision with occupied bubbles
    const threshSq = Math.pow(BUBBLE_DIAMETER * 0.94, 2);
    for (let r = 0; r < MAX_GRID_ROWS; r++) {
      for (let c = 0; c < getColsForRow(r); c++) {
        const cell = gridRef.current[r][c];
        if (cell) {
          const cellPos = gridToWorld(r, c);
          const dx = proj.x - cellPos.x;
          const dy = proj.y - cellPos.y;
          if (dx * dx + dy * dy <= threshSq) {
            attachProjectileToGrid(proj);
            return;
          }
        }
      }
    }
  };

  const spawnBounceSparks = (x, y) => {
    if (reducedEffects) return;
    for (let i = 0; i < 6; i++) {
      const angle = Math.random() * Math.PI * 2;
      const spd = 60 + Math.random() * 120;
      particlesRef.current.push({
        x, y,
        vx: Math.cos(angle) * spd,
        vy: Math.sin(angle) * spd,
        color: '#FFFFFF',
        radius: 2 + Math.random() * 2,
        life: 0.25,
        maxLife: 0.25
      });
    }
  };

  // Find nearest empty hexagonal cell for attachment
  const findBestSnapCell = (contactX, contactY) => {
    let bestDistSq = Infinity;
    let bestCoord = { r: 0, c: 0 };

    for (let r = 0; r < MAX_GRID_ROWS; r++) {
      for (let c = 0; c < getColsForRow(r); c++) {
        if (!gridRef.current[r][c]) {
          const pos = gridToWorld(r, c);
          const dSq = Math.pow(contactX - pos.x, 2) + Math.pow(contactY - pos.y, 2);
          if (dSq < bestDistSq) {
            bestDistSq = dSq;
            bestCoord = { r, c };
          }
        }
      }
    }
    return bestCoord;
  };

  const attachProjectileToGrid = (proj) => {
    setGameState('RESOLVING');
    activeProjectileRef.current = null;

    const snap = findBestSnapCell(proj.x, proj.y);
    gridRef.current[snap.r][snap.c] = {
      color: proj.color,
      special: proj.special || 0,
      radius: BUBBLE_RADIUS,
      alpha: 1.0,
      scale: 1.0
    };

    // Trigger resolve after micro snap delay
    setTimeout(() => {
      resolveMatchesAndSpecials(snap);
    }, 80);
  };

  // Match Flood-Fill and Special Bubbles Handler
  const resolveMatchesAndSpecials = (snap) => {
    const curLevel = levelsData[levelIndex] || levelsData[0];
    const placed = gridRef.current[snap.r][snap.c];
    let clearedCoords = [];
    let isSpecialTrigger = false;

    // 1. Bomb Bubble Explosion (Radius 1)
    if (placed && placed.special === 1) {
      isSpecialTrigger = true;
      clearedCoords.push([snap.r, snap.c]);
      getNeighbors(snap.r, snap.c).forEach(([nr, nc]) => {
        if (gridRef.current[nr][nc]) clearedCoords.push([nr, nc]);
      });
      playSynthSound('BOMB');
      screenTraumaRef.current = reducedEffects ? 0 : 0.6;
      lumiStateRef.current = 'LARGE_COMBO';
      lumiTimerRef.current = 0;
      setScore(s => s + POINTS_PER_BOMB);
    }
    // 2. Lightning Bubble Clear (Full Horizontal Row)
    else if (placed && placed.special === 3) {
      isSpecialTrigger = true;
      const cols = getColsForRow(snap.r);
      for (let c = 0; c < cols; c++) {
        if (gridRef.current[snap.r][c]) clearedCoords.push([snap.r, c]);
      }
      playSynthSound('LIGHTNING');
      screenTraumaRef.current = reducedEffects ? 0 : 0.45;
      lumiStateRef.current = 'MATCH_SUCCESS';
      lumiTimerRef.current = 0;
      setScore(s => s + POINTS_PER_LIGHTNING);
    }
    // 3. Standard BFS Matching with Rainbow Wildcard Support
    else {
      clearedCoords = findMatchesWithRainbow(snap.r, snap.c);
    }

    if (clearedCoords.length >= 3 || isSpecialTrigger) {
      const newCombo = combo + 1;
      setCombo(newCombo);
      const isLarge = clearedCoords.length >= 5 || newCombo >= 2;
      const comboMult = 1.0 + (newCombo - 1) * COMBO_BONUS_MULTIPLIER;
      const matchScore = Math.floor(clearedCoords.length * POINTS_PER_MATCH * comboMult);
      setScore(s => s + matchScore);

      if (!isSpecialTrigger) {
        playSynthSound('POP', newCombo);
        lumiStateRef.current = isLarge ? 'LARGE_COMBO' : 'MATCH_SUCCESS';
        lumiTimerRef.current = 0;
      }

      const snapWorld = gridToWorld(snap.r, snap.c);
      scorePopupsRef.current.push({
        x: snapWorld.x,
        y: snapWorld.y,
        text: `+${matchScore}${newCombo > 1 ? ` (x${newCombo}!)` : ''}`,
        color: '#FAD126',
        alpha: 1.0,
        vy: 80
      });

      // Clear matching bubbles & emit particles
      clearedCoords.forEach(([cr, cc]) => {
        const cell = gridRef.current[cr][cc];
        if (cell) {
          const pos = gridToWorld(cr, cc);
          emitPopBurst(pos.x, pos.y, cell.color, isLarge);
          gridRef.current[cr][cc] = null;
        }
      });

      // 4. Crack adjacent locked ice bubbles
      const crackedCount = crackAdjacentLocked(clearedCoords);
      if (crackedCount > 0) {
        setScore(s => s + crackedCount * POINTS_PER_LOCK_CRACK);
        playSynthSound('CRACK');
      }

      // 5. Detect and drop floating bubbles
      const floating = findFloatingClusters();
      if (floating.length > 0) {
        const dropScore = Math.floor(floating.length * POINTS_PER_DROP * comboMult);
        setScore(s => s + dropScore);
        playSynthSound('DROP');

        const dropCenter = gridToWorld(floating[0][0], floating[0][1]);
        scorePopupsRef.current.push({
          x: dropCenter.x,
          y: dropCenter.y + 20,
          text: `DROP +${dropScore}`,
          color: '#2ECCDE',
          alpha: 1.0,
          vy: 90
        });

        floating.forEach(([fr, fc]) => {
          const fCell = gridRef.current[fr][fc];
          if (fCell) {
            const pos = gridToWorld(fr, fc);
            emitPopBurst(pos.x, pos.y, fCell.color, false);
            gridRef.current[fr][fc] = null;
          }
        });
      }
    } else {
      setCombo(0);
    }

    // Check Win/Loss conditions
    checkLevelEnd();
  };

  const findMatchesWithRainbow = (startR, startC) => {
    const startCell = gridRef.current[startR][startC];
    if (!startCell || startCell.special === 4 || startCell.special === 5) return []; // Stone & Locked do not match

    let startColor = startCell.color;
    if (startCell.special === 2) {
      // Rainbow wildcard: match with first colored neighbor
      for (const [nr, nc] of getNeighbors(startR, startC)) {
        const nCell = gridRef.current[nr][nc];
        if (nCell && nCell.color >= 0 && nCell.special !== 4 && nCell.special !== 5) {
          startColor = nCell.color;
          break;
        }
      }
    }

    const matched = [];
    const visited = new Set();
    const queue = [[startR, startC]];
    visited.add(`${startR},${startC}`);

    while (queue.length > 0) {
      const [cr, cc] = queue.shift();
      matched.push([cr, cc]);

      for (const [nr, nc] of getNeighbors(cr, cc)) {
        const key = `${nr},${nc}`;
        if (visited.has(key)) continue;
        const nCell = gridRef.current[nr][nc];
        if (!nCell || nCell.special === 4 || nCell.special === 5) continue;

        if (nCell.color === startColor || nCell.special === 2) {
          visited.add(key);
          queue.push([nr, nc]);
        }
      }
    }

    return matched.length >= 3 ? matched : [];
  };

  const crackAdjacentLocked = (clearedCoords) => {
    let count = 0;
    clearedCoords.forEach(([cr, cc]) => {
      getNeighbors(cr, cc).forEach(([nr, nc]) => {
        const cell = gridRef.current[nr][nc];
        if (cell && cell.special === 5) {
          cell.special = 0; // Unlocked back to standard
          count++;
          const pos = gridToWorld(nr, nc);
          emitPopBurst(pos.x, pos.y, cell.color, false);
        }
      });
    });
    return count;
  };

  const findFloatingClusters = () => {
    const anchored = new Set();
    const queue = [];
    const topCols = getColsForRow(0);

    for (let c = 0; c < topCols; c++) {
      if (gridRef.current[0][c]) {
        queue.push([0, c]);
        anchored.add(`0,${c}`);
      }
    }

    while (queue.length > 0) {
      const [cr, cc] = queue.shift();
      for (const [nr, nc] of getNeighbors(cr, cc)) {
        const key = `${nr},${nc}`;
        if (gridRef.current[nr][nc] && !anchored.has(key)) {
          anchored.add(key);
          queue.push([nr, nc]);
        }
      }
    }

    const floating = [];
    for (let r = 0; r < MAX_GRID_ROWS; r++) {
      for (let c = 0; c < getColsForRow(r); c++) {
        if (gridRef.current[r][c] && !anchored.has(`${r},${c}`)) {
          floating.push([r, c]);
        }
      }
    }
    return floating;
  };

  const emitPopBurst = (x, y, colorId, isLarge) => {
    if (reducedEffects) return;
    const count = isLarge ? 14 : 7;
    const baseColor = COLOR_MAP[colorId] || '#FFFFFF';
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const spd = 70 + Math.random() * 160;
      particlesRef.current.push({
        x, y,
        vx: Math.cos(angle) * spd,
        vy: Math.sin(angle) * spd,
        color: baseColor,
        radius: 3 + Math.random() * 3,
        life: 0.35 + Math.random() * 0.2,
        maxLife: 0.55
      });
    }
  };

  const checkLevelEnd = () => {
    const curLevel = levelsData[levelIndex] || levelsData[0];
    let remainingBubbles = 0;
    let lowestRow = -1;

    for (let r = 0; r < MAX_GRID_ROWS; r++) {
      for (let c = 0; c < getColsForRow(r); c++) {
        if (gridRef.current[r][c]) {
          remainingBubbles++;
          if (r > lowestRow) lowestRow = r;
        }
      }
    }

    const dangerRow = curLevel.danger_row || DEFAULT_DANGER_ROW;

    // Check Win (Clear Board)
    if (remainingBubbles === 0) {
      setGameState('WIN');
      playSynthSound('WIN');
      lumiStateRef.current = 'WIN';
      const curLvlId = curLevel.level_id || (levelIndex + 1);
      const isNewHigh = score > (highScores[curLvlId] || 0);
      const nextHigh = { ...highScores, [curLvlId]: Math.max(score, highScores[curLvlId] || 0) };
      
      let earned = 1;
      if (score >= (curLevel.target_score || 300)) earned = 2;
      if (score >= Math.floor((curLevel.target_score || 300) * 1.5)) earned = 3;
      const nextStars = { ...starsEarned, [curLvlId]: Math.max(earned, starsEarned[curLvlId] || 0) };
      const nextUnlocked = Array.from(new Set([...unlockedLevels, curLvlId + 1]));

      setHighScores(nextHigh);
      setStarsEarned(nextStars);
      setUnlockedLevels(nextUnlocked);
      saveUserData(nextHigh, nextStars, nextUnlocked, seenTutorials);

      setWinModalData({ score, stars: earned, isNewHigh });
      return;
    }

    // Check Loss (Bubbles breached danger row)
    if (lowestRow >= dangerRow) {
      setGameState('LOSE');
      playSynthSound('LOSE');
      lumiStateRef.current = 'LOSE';
      setLoseModalData({ reason: "Bubbles reached the danger line!" });
      return;
    }

    // Check Loss (Out of shots)
    if (shotsRemaining <= 1 && activeProjectileRef.current === null) {
      setGameState('LOSE');
      playSynthSound('LOSE');
      lumiStateRef.current = 'LOSE';
      setLoseModalData({ reason: "Out of shots!" });
      return;
    }

    // Reload shooter
    setGameState('PLAYING');
    currentColorRef.current = nextColorRef.current;
    nextColorRef.current = pickNextColor(curLevel.allowed_colors || [0, 1]);
  };

  // Trajectory Raycast Math with Wall Bounces
  const computeTrajectoryPoints = (startDir) => {
    const points = [{ x: SHOOTER_POS.x, y: SHOOTER_POS.y }];
    let origin = { x: SHOOTER_POS.x, y: SHOOTER_POS.y };
    let dir = { x: startDir.x, y: startDir.y };

    const leftBound = LEFT_WALL_X + BUBBLE_RADIUS;
    const rightBound = RIGHT_WALL_X - BUBBLE_RADIUS;
    const ceilingBound = GRID_START_Y + BUBBLE_RADIUS;
    const collisionThreshSq = Math.pow(BUBBLE_DIAMETER * 0.94, 2);

    for (let bounce = 0; bounce <= MAX_TRAJECTORY_BOUNCES; bounce++) {
      let tMin = Infinity;
      let hitType = 0; // 1: Wall, 2: Ceiling, 3: Bubble
      let nextOrigin = { ...origin };
      let nextDir = { ...dir };

      // Wall left
      if (dir.x < -0.001) {
        const tLeft = (leftBound - origin.x) / dir.x;
        if (tLeft > 0.001 && tLeft < tMin) {
          tMin = tLeft;
          hitType = 1;
          nextOrigin = { x: leftBound, y: origin.y + dir.y * tLeft };
          nextDir = { x: -dir.x, y: dir.y };
        }
      } else if (dir.x > 0.001) {
        const tRight = (rightBound - origin.x) / dir.x;
        if (tRight > 0.001 && tRight < tMin) {
          tMin = tRight;
          hitType = 1;
          nextOrigin = { x: rightBound, y: origin.y + dir.y * tRight };
          nextDir = { x: -dir.x, y: dir.y };
        }
      }

      // Ceiling
      if (dir.y < -0.001) {
        const tCeil = (ceilingBound - origin.y) / dir.y;
        if (tCeil > 0.001 && tCeil < tMin) {
          tMin = tCeil;
          hitType = 2;
          nextOrigin = { x: origin.x + dir.x * tCeil, y: ceilingBound };
        }
      }

      // Bubble raycast circle intersections
      for (let r = 0; r < MAX_GRID_ROWS; r++) {
        for (let c = 0; c < getColsForRow(r); c++) {
          const cell = gridRef.current[r][c];
          if (cell) {
            const bPos = gridToWorld(r, c);
            const dx = origin.x - bPos.x;
            const dy = origin.y - bPos.y;
            const bVal = 2 * (dir.x * dx + dir.y * dy);
            const cVal = dx * dx + dy * dy - collisionThreshSq;
            const disc = bVal * bVal - 4 * cVal;
            if (disc >= 0) {
              const tCand = (-bVal - Math.sqrt(disc)) / 2;
              if (tCand > 0.001 && tCand < tMin) {
                tMin = tCand;
                hitType = 3;
                nextOrigin = { x: origin.x + dir.x * tCand, y: origin.y + dir.y * tCand };
              }
            }
          }
        }
      }

      if (!isFinite(tMin) || tMin <= 0) break;

      const hitPos = { x: origin.x + dir.x * tMin, y: origin.y + dir.y * tMin };
      points.push(hitPos);

      if (hitType === 2 || hitType === 3) break;
      origin = nextOrigin;
      dir = nextDir;
    }

    return points;
  };

  // Canvas Drawing
  const drawGame = (ctx, dt) => {
    ctx.save();
    ctx.clearRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);

    // Camera Trauma Shake
    if (screenTraumaRef.current > 0 && !reducedEffects) {
      const shakeAmt = Math.pow(screenTraumaRef.current, 2) * 14;
      const shakeX = (Math.random() - 0.5) * shakeAmt;
      const shakeY = (Math.random() - 0.5) * shakeAmt;
      ctx.translate(shakeX, shakeY);
    }

    // Forest Background Gradient
    const bgGrad = ctx.createLinearGradient(0, 0, 0, SCREEN_HEIGHT);
    bgGrad.addColorStop(0, '#0F1E19');
    bgGrad.addColorStop(0.5, '#162D24');
    bgGrad.addColorStop(1, '#0C1613');
    ctx.fillStyle = bgGrad;
    ctx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);

    // Forest Canopy & Sunlight Rays
    ctx.fillStyle = 'rgba(70, 180, 130, 0.04)';
    ctx.beginPath();
    ctx.moveTo(100, 0);
    ctx.lineTo(240, SCREEN_HEIGHT);
    ctx.lineTo(380, SCREEN_HEIGHT);
    ctx.lineTo(160, 0);
    ctx.fill();

    // Playfield Lateral Boundaries
    ctx.strokeStyle = 'rgba(100, 200, 150, 0.25)';
    ctx.lineWidth = 3;
    ctx.setLineDash([8, 8]);
    ctx.beginPath();
    ctx.moveTo(LEFT_WALL_X, GRID_START_Y);
    ctx.lineTo(LEFT_WALL_X, 1050);
    ctx.moveTo(RIGHT_WALL_X, GRID_START_Y);
    ctx.lineTo(RIGHT_WALL_X, 1050);
    ctx.stroke();
    ctx.setLineDash([]);

    // Danger Line
    const curLevel = levelsData[levelIndex] || levelsData[0];
    const dangerY = GRID_START_Y + (curLevel.danger_row || DEFAULT_DANGER_ROW) * ROW_SPACING;
    ctx.strokeStyle = 'rgba(235, 64, 64, 0.55)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(LEFT_WALL_X, dangerY);
    ctx.lineTo(RIGHT_WALL_X, dangerY);
    ctx.stroke();

    // Trajectory Aim Guide
    if (isAimingRef.current && gameState === 'PLAYING') {
      const aimDir = { x: Math.cos(aimAngleRef.current), y: Math.sin(aimAngleRef.current) };
      const trajPoints = computeTrajectoryPoints(aimDir);
      const strokeCol = COLOR_MAP[currentColorRef.current] || '#FFFFFF';

      ctx.strokeStyle = strokeCol;
      ctx.lineWidth = 4;
      ctx.setLineDash([10, 10]);
      ctx.beginPath();
      trajPoints.forEach((pt, idx) => {
        if (idx === 0) ctx.moveTo(pt.x, pt.y);
        else ctx.lineTo(pt.x, pt.y);
      });
      ctx.stroke();
      ctx.setLineDash([]);

      // Predicted contact ring
      if (trajPoints.length > 1) {
        const lastPt = trajPoints[trajPoints.length - 1];
        ctx.strokeStyle = strokeCol;
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(lastPt.x, lastPt.y, BUBBLE_RADIUS, 0, Math.PI * 2);
        ctx.stroke();
      }
    }

    // Grid Bubbles
    for (let r = 0; r < MAX_GRID_ROWS; r++) {
      for (let c = 0; c < getColsForRow(r); c++) {
        const cell = gridRef.current[r][c];
        if (cell) {
          const pos = gridToWorld(r, c);
          drawBubble(ctx, pos.x, pos.y, cell.color, cell.special, cell.radius);
        }
      }
    }

    // In-Flight Projectile
    if (activeProjectileRef.current) {
      const p = activeProjectileRef.current;
      drawBubble(ctx, p.x, p.y, p.color, p.special || 0, BUBBLE_RADIUS);
    }

    // Next Bubble Slot & Pedestal
    ctx.fillStyle = 'rgba(255, 255, 255, 0.08)';
    ctx.beginPath();
    ctx.arc(NEXT_BUBBLE_POS.x, NEXT_BUBBLE_POS.y, 38, 0, Math.PI * 2);
    ctx.fill();
    drawBubble(ctx, NEXT_BUBBLE_POS.x, NEXT_BUBBLE_POS.y, nextColorRef.current, 0, 26);

    // Shooter Launcher Base & Loaded Bubble
    ctx.fillStyle = 'rgba(255, 255, 255, 0.12)';
    ctx.beginPath();
    ctx.arc(SHOOTER_POS.x, SHOOTER_POS.y, 44, 0, Math.PI * 2);
    ctx.fill();

    // Launcher Pointer Arrow
    const aimDir = { x: Math.cos(aimAngleRef.current), y: Math.sin(aimAngleRef.current) };
    ctx.strokeStyle = '#FAD126';
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(SHOOTER_POS.x, SHOOTER_POS.y);
    ctx.lineTo(SHOOTER_POS.x + aimDir.x * 55, SHOOTER_POS.y + aimDir.y * 55);
    ctx.stroke();

    if (gameState === 'PLAYING') {
      drawBubble(ctx, SHOOTER_POS.x, SHOOTER_POS.y, currentColorRef.current, 0, BUBBLE_RADIUS);
    }

    // Companion Character: Lumi
    drawLumiCompanion(ctx, LUMI_POS.x, LUMI_POS.y, lumiStateRef.current);

    // Particles
    particlesRef.current.forEach(p => {
      ctx.fillStyle = p.color;
      ctx.globalAlpha = p.alpha;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1.0;
    });

    // Score Popups
    scorePopupsRef.current.forEach(pop => {
      ctx.font = 'bold 26px sans-serif';
      ctx.fillStyle = pop.color;
      ctx.globalAlpha = pop.alpha;
      ctx.textAlign = 'center';
      ctx.fillText(pop.text, pop.x, pop.y);
      ctx.globalAlpha = 1.0;
    });

    ctx.restore();
  };

  // Multi-layer Procedural Glossy Bubble Renderer
  const drawBubble = (ctx, x, y, colorId, specialType, radius) => {
    ctx.save();
    ctx.translate(x, y);

    const baseColor = COLOR_MAP[colorId] || '#999999';

    // 1. Drop Shadow
    ctx.fillStyle = 'rgba(0, 0, 0, 0.28)';
    ctx.beginPath();
    ctx.arc(2, 4, radius, 0, Math.PI * 2);
    ctx.fill();

    // 2. Base Sphere Fill
    const grad = ctx.createRadialGradient(-radius * 0.3, -radius * 0.35, radius * 0.1, 0, 0, radius);
    if (specialType === 1) { // Bomb
      grad.addColorStop(0, '#FFA500');
      grad.addColorStop(0.6, '#FF4500');
      grad.addColorStop(1, '#8B0000');
    } else if (specialType === 2) { // Rainbow
      grad.addColorStop(0, '#FFFFFF');
      grad.addColorStop(0.4, '#FF69B4');
      grad.addColorStop(0.7, '#00FFFF');
      grad.addColorStop(1, '#9370DB');
    } else if (specialType === 3) { // Lightning
      grad.addColorStop(0, '#FFFFE0');
      grad.addColorStop(0.5, '#FFD700');
      grad.addColorStop(1, '#B8860B');
    } else if (specialType === 4) { // Stone
      grad.addColorStop(0, '#A9A9A9');
      grad.addColorStop(0.6, '#696969');
      grad.addColorStop(1, '#2F4F4F');
    } else {
      grad.addColorStop(0, '#FFFFFF');
      grad.addColorStop(0.35, baseColor);
      grad.addColorStop(1, baseColor);
    }
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(0, 0, radius, 0, Math.PI * 2);
    ctx.fill();

    // 3. Locked Ice Shell Overlay
    if (specialType === 5) {
      ctx.fillStyle = 'rgba(200, 240, 255, 0.55)';
      ctx.beginPath();
      ctx.arc(0, 0, radius + 2, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#E0F7FA';
      ctx.lineWidth = 3;
      ctx.stroke();

      // Ice crack lines
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.85)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(-10, -12); ctx.lineTo(-2, 0); ctx.lineTo(12, -4);
      ctx.moveTo(-2, 0); ctx.lineTo(4, 14);
      ctx.stroke();
    }

    // 4. Glossy Specular Highlight Crescent
    ctx.fillStyle = 'rgba(255, 255, 255, 0.65)';
    ctx.beginPath();
    ctx.arc(-radius * 0.35, -radius * 0.38, radius * 0.32, 0, Math.PI * 2);
    ctx.fill();

    // 5. Special Type Icon or Accessibility Rune
    if (specialType === 1) { // Bomb
      ctx.font = `bold ${Math.floor(radius * 0.85)}px sans-serif`;
      ctx.fillStyle = '#FFFFFF';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('💣', 0, 2);
    } else if (specialType === 2) { // Rainbow
      ctx.font = `bold ${Math.floor(radius * 0.85)}px sans-serif`;
      ctx.fillStyle = '#FFFFFF';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('🌈', 0, 2);
    } else if (specialType === 3) { // Lightning
      ctx.font = `bold ${Math.floor(radius * 0.85)}px sans-serif`;
      ctx.fillStyle = '#FFFFFF';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('⚡', 0, 2);
    } else if (specialType === 4) { // Stone
      ctx.font = `bold ${Math.floor(radius * 0.85)}px sans-serif`;
      ctx.fillStyle = '#DCDCDC';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('🪨', 0, 2);
    } else if (specialType === 5) { // Locked
      ctx.font = `bold ${Math.floor(radius * 0.8)}px sans-serif`;
      ctx.fillStyle = '#FFFFFF';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('🔒', 0, 2);
    } else if (showRunes && RUNE_SYMBOLS[colorId]) {
      ctx.font = `bold ${Math.floor(radius * 0.7)}px sans-serif`;
      ctx.fillStyle = 'rgba(255, 255, 255, 0.88)';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(RUNE_SYMBOLS[colorId], 0, 2);
    }

    ctx.restore();
  };

  // Companion Lumi Procedural Visuals
  const drawLumiCompanion = (ctx, x, y, state) => {
    ctx.save();
    ctx.translate(x, y);

    // Body Bobbing Offset
    const bob = Math.sin(performance.now() * 0.004) * 5;
    ctx.translate(0, bob);

    // Glow Halo
    const glowGrad = ctx.createRadialGradient(0, 0, 10, 0, 0, 42);
    glowGrad.addColorStop(0, 'rgba(255, 240, 160, 0.65)');
    glowGrad.addColorStop(1, 'rgba(255, 240, 160, 0)');
    ctx.fillStyle = glowGrad;
    ctx.beginPath();
    ctx.arc(0, 0, 42, 0, Math.PI * 2);
    ctx.fill();

    // Body
    ctx.fillStyle = '#FFF8DC';
    ctx.beginPath();
    ctx.arc(0, 0, 25, 0, Math.PI * 2);
    ctx.fill();

    // Eyes
    ctx.fillStyle = '#2C1B00';
    if (state === 'WIN' || state === 'LARGE_COMBO') {
      // Happy Cheerful Arc Eyes
      ctx.lineWidth = 3;
      ctx.strokeStyle = '#2C1B00';
      ctx.beginPath();
      ctx.arc(-8, -2, 5, Math.PI, 0);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(8, -2, 5, Math.PI, 0);
      ctx.stroke();
    } else if (state === 'LOSE') {
      // Sad Downturned Eyes
      ctx.lineWidth = 3;
      ctx.strokeStyle = '#2C1B00';
      ctx.beginPath();
      ctx.arc(-8, 3, 5, 0, Math.PI);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(8, 3, 5, 0, Math.PI);
      ctx.stroke();
    } else {
      // Wide Curious Eyes
      ctx.beginPath();
      ctx.arc(-8, -2, 4, 0, Math.PI * 2);
      ctx.arc(8, -2, 4, 0, Math.PI * 2);
      ctx.fill();

      // Eye Sparkles
      ctx.fillStyle = '#FFFFFF';
      ctx.beginPath();
      ctx.arc(-9, -4, 1.8, 0, Math.PI * 2);
      ctx.arc(7, -4, 1.8, 0, Math.PI * 2);
      ctx.fill();
    }

    // Rosy Cheeks
    ctx.fillStyle = 'rgba(255, 105, 180, 0.45)';
    ctx.beginPath();
    ctx.arc(-14, 5, 4.5, 0, Math.PI * 2);
    ctx.arc(14, 5, 4.5, 0, Math.PI * 2);
    ctx.fill();

    ctx.restore();
  };

  // Touch & Mouse Input Handlers
  const handlePointerDown = (e) => {
    if (gameState !== 'PLAYING') return;
    updateAimFromEvent(e);
    isAimingRef.current = true;
  };

  const handlePointerMove = (e) => {
    if (isAimingRef.current && gameState === 'PLAYING') {
      updateAimFromEvent(e);
    }
  };

  const handlePointerUp = () => {
    if (isAimingRef.current && gameState === 'PLAYING') {
      isAimingRef.current = false;
      fireBubble();
    }
  };

  const updateAimFromEvent = (e) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const scaleX = SCREEN_WIDTH / rect.width;
    const scaleY = SCREEN_HEIGHT / rect.height;

    const touchX = (e.clientX - rect.left) * scaleX;
    const touchY = (e.clientY - rect.top) * scaleY;
    aimTargetRef.current = { x: touchX, y: touchY };

    let dx = touchX - SHOOTER_POS.x;
    let dy = touchY - SHOOTER_POS.y;

    let angle = Math.atan2(dy, dx);
    const minAngleRad = (-180 + MIN_AIM_ANGLE_DEG) * (Math.PI / 180);
    const maxAngleRad = -MIN_AIM_ANGLE_DEG * (Math.PI / 180);

    if (angle > 0) {
      angle = dx < 0 ? minAngleRad : maxAngleRad;
    } else {
      angle = Math.max(minAngleRad, Math.min(maxAngleRad, angle));
    }
    aimAngleRef.current = angle;
  };

  const fireBubble = () => {
    if (activeProjectileRef.current || shotsRemaining <= 0) return;
    setGameState('SHOOTING');
    setShotsRemaining(s => s - 1);

    const dirX = Math.cos(aimAngleRef.current);
    const dirY = Math.sin(aimAngleRef.current);

    activeProjectileRef.current = {
      x: SHOOTER_POS.x,
      y: SHOOTER_POS.y,
      vx: dirX,
      vy: dirY,
      color: currentColorRef.current,
      special: 0
    };

    lumiStateRef.current = 'AIMING';
    lumiTimerRef.current = 0;
  };

  const swapShooterBubbles = () => {
    if (gameState !== 'PLAYING') return;
    const temp = currentColorRef.current;
    currentColorRef.current = nextColorRef.current;
    nextColorRef.current = temp;
  };

  const restartCurrentLevel = () => {
    loadLevel(levelIndex);
  };

  const nextLevel = () => {
    const nextIdx = (levelIndex + 1) % levelsData.length;
    loadLevel(nextIdx);
  };

  const curLevel = levelsData[levelIndex] || levelsData[0];
  const curLvlId = curLevel.level_id || (levelIndex + 1);
  const targetScore = curLevel.target_score || 300;
  let currentStars = 0;
  if (score >= Math.floor(targetScore * 0.3)) currentStars = 1;
  if (score >= targetScore) currentStars = 2;
  if (score >= Math.floor(targetScore * 1.5)) currentStars = 3;

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-slate-950 text-white font-sans select-none p-2">
      {/* Container matching mobile portrait 720x1280 ratio */}
      <div className="relative w-full max-w-[480px] aspect-[720/1280] bg-slate-900 rounded-2xl overflow-hidden shadow-2xl border border-emerald-900/40 flex flex-col">

        {/* ----------------- SCREEN: MAIN MENU ----------------- */}
        {currentScreen === 'MENU' && (
          <div className="absolute inset-0 z-30 flex flex-col justify-between items-center p-8 bg-gradient-to-b from-emerald-950 via-teal-950 to-slate-950">
            {/* Header / Title */}
            <div className="flex flex-col items-center mt-12 space-y-3">
              <div className="inline-flex items-center px-4 py-1.5 rounded-full bg-emerald-500/20 text-emerald-300 font-bold tracking-wider text-xs border border-emerald-500/40">
                ✨ PROCEDURAL FANTASY ADVENTURE
              </div>
              <h1 className="text-5xl font-black tracking-wider text-transparent bg-clip-text bg-gradient-to-r from-emerald-300 via-amber-200 to-teal-200 drop-shadow-lg">
                LUMI
              </h1>
              <p className="text-emerald-200/70 text-sm font-medium">Bubblewood Chronicle • 30 Levels</p>
            </div>

            {/* Lumi Visual Banner */}
            <div className="relative flex flex-col items-center justify-center my-6">
              <div className="w-40 h-40 rounded-full bg-gradient-to-tr from-amber-400/20 to-emerald-400/20 flex items-center justify-center animate-pulse">
                <div className="w-28 h-28 rounded-full bg-amber-100 flex items-center justify-center shadow-lg shadow-amber-300/30">
                  <span className="text-5xl">✨</span>
                </div>
              </div>
              <p className="mt-4 text-xs font-semibold text-amber-200/90 tracking-wide">
                Total Stars: <span className="text-amber-400 font-bold text-sm">★ {totalStars} / 90</span>
              </p>
            </div>

            {/* Menu Buttons */}
            <div className="w-full flex flex-col space-y-3 mb-6">
              <button
                onClick={() => {
                  playSynthSound('BOUNCE');
                  loadLevel(unlockedLevels[unlockedLevels.length - 1] - 1);
                  setCurrentScreen('GAMEPLAY');
                }}
                className="w-full py-4 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-400 hover:to-teal-400 text-slate-950 font-black text-lg shadow-lg shadow-emerald-500/30 transition transform active:scale-95 cursor-pointer"
              >
                PLAY GAME ▶
              </button>
              <button
                onClick={() => {
                  playSynthSound('BOUNCE');
                  setCurrentScreen('WORLD_MAP');
                }}
                className="w-full py-3.5 rounded-xl bg-emerald-900/40 hover:bg-emerald-800/50 text-emerald-200 font-bold text-base border border-emerald-600/40 transition active:scale-95 cursor-pointer"
              >
                🗺️ WORLD MAP & LEVELS
              </button>
              <button
                onClick={() => {
                  playSynthSound('BOUNCE');
                  setCurrentScreen('SETTINGS');
                }}
                className="w-full py-3.5 rounded-xl bg-slate-800/60 hover:bg-slate-700/60 text-slate-300 font-bold text-base border border-slate-700 transition active:scale-95 cursor-pointer"
              >
                ⚙️ SETTINGS
              </button>
            </div>
          </div>
        )}

        {/* ----------------- SCREEN: WORLD MAP ----------------- */}
        {currentScreen === 'WORLD_MAP' && (
          <div className="absolute inset-0 z-30 flex flex-col p-6 bg-gradient-to-b from-slate-950 via-emerald-950 to-slate-950 overflow-y-auto">
            {/* Top Bar */}
            <div className="flex items-center justify-between pb-4 border-b border-emerald-900/60">
              <button
                onClick={() => {
                  playSynthSound('BOUNCE');
                  setCurrentScreen('MENU');
                }}
                className="px-3 py-1.5 rounded-lg bg-emerald-950 text-emerald-300 text-xs font-bold border border-emerald-800 hover:bg-emerald-900 cursor-pointer"
              >
                ← BACK
              </button>
              <h2 className="text-lg font-black text-amber-300">WORLD PROGRESSION</h2>
              <div className="flex items-center space-x-1 text-amber-400 font-black text-sm">
                <span>★</span>
                <span>{totalStars}/90</span>
              </div>
            </div>

            {/* World Switcher Tabs */}
            <div className="grid grid-cols-3 gap-2 my-4">
              {WORLDS.map(w => {
                const isLocked = totalStars < w.requiredStars;
                return (
                  <button
                    key={w.id}
                    onClick={() => setActiveWorldTab(w.id)}
                    className={`py-2 px-1 rounded-xl text-center text-xs font-bold border transition flex flex-col items-center justify-center space-y-1 cursor-pointer ${
                      activeWorldTab === w.id
                        ? 'bg-emerald-600/30 border-emerald-400 text-emerald-200'
                        : isLocked
                        ? 'bg-slate-900/40 border-slate-800 text-slate-500'
                        : 'bg-slate-800/40 border-slate-700 text-slate-300'
                    }`}
                  >
                    <span className="text-base">{w.icon}</span>
                    <span className="truncate w-full">{w.name.split(' ')[0]}</span>
                    {isLocked && <span className="text-[10px] text-amber-400">🔒 {w.requiredStars}★</span>}
                  </button>
                );
              })}
            </div>

            {/* Active World Banner */}
            {(() => {
              const activeW = WORLDS.find(w => w.id === activeWorldTab) || WORLDS[0];
              const isLocked = totalStars < activeW.requiredStars;
              return (
                <div className="p-3.5 rounded-xl bg-emerald-900/20 border border-emerald-800/40 mb-4">
                  <div className="flex items-center justify-between">
                    <h3 className="font-bold text-emerald-300 text-sm flex items-center space-x-2">
                      <span>{activeW.icon}</span>
                      <span>{activeW.name}</span>
                    </h3>
                    <span className="text-xs text-emerald-400/80">Levels {activeW.startLevel}-{activeW.endLevel}</span>
                  </div>
                  <p className="text-xs text-slate-400 mt-1">{activeW.desc}</p>
                  {isLocked && (
                    <div className="mt-2 text-xs font-bold text-amber-400 bg-amber-950/40 p-2 rounded-lg border border-amber-900/40">
                      🔒 Star Gate Locked: Earn {activeW.requiredStars - totalStars} more stars to unlock!
                    </div>
                  )}
                </div>
              );
            })()}

            {/* Level Grid */}
            <div className="grid grid-cols-5 gap-3 my-2">
              {levelsData
                .filter(l => {
                  const w = WORLDS.find(w => w.id === activeWorldTab);
                  return l.level_id >= w.startLevel && l.level_id <= w.endLevel;
                })
                .map(lvl => {
                  const activeW = WORLDS.find(w => w.id === activeWorldTab);
                  const isWorldLocked = totalStars < activeW.requiredStars;
                  const isLevelUnlocked = unlockedLevels.includes(lvl.level_id) && !isWorldLocked;
                  const stars = starsEarned[lvl.level_id] || 0;

                  return (
                    <button
                      key={lvl.level_id}
                      disabled={!isLevelUnlocked}
                      onClick={() => {
                        playSynthSound('BOUNCE');
                        loadLevel(lvl.level_id - 1);
                        setCurrentScreen('GAMEPLAY');
                      }}
                      className={`aspect-square rounded-2xl flex flex-col items-center justify-center p-1 border transition transform ${
                        isLevelUnlocked
                          ? 'bg-gradient-to-br from-emerald-800/50 to-teal-900/50 border-emerald-500/50 hover:border-emerald-400 active:scale-95 cursor-pointer shadow-md'
                          : 'bg-slate-900/60 border-slate-800/80 opacity-50 cursor-not-allowed'
                      }`}
                    >
                      <span className="font-black text-sm text-white">{lvl.level_id}</span>
                      <div className="flex text-[10px] text-amber-400 mt-0.5">
                        {isLevelUnlocked ? (
                          <>
                            <span>{stars >= 1 ? '★' : '☆'}</span>
                            <span>{stars >= 2 ? '★' : '☆'}</span>
                            <span>{stars >= 3 ? '★' : '☆'}</span>
                          </>
                        ) : (
                          <span>🔒</span>
                        )}
                      </div>
                    </button>
                  );
                })}
            </div>
          </div>
        )}

        {/* ----------------- SCREEN: SETTINGS ----------------- */}
        {currentScreen === 'SETTINGS' && (
          <div className="absolute inset-0 z-30 flex flex-col justify-between p-6 bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950">
            <div>
              <div className="flex items-center justify-between pb-4 border-b border-slate-800">
                <button
                  onClick={() => {
                    playSynthSound('BOUNCE');
                    setCurrentScreen('MENU');
                  }}
                  className="px-3 py-1.5 rounded-lg bg-slate-800 text-slate-300 text-xs font-bold hover:bg-slate-700 cursor-pointer"
                >
                  ← BACK
                </button>
                <h2 className="text-lg font-black text-white">GAME SETTINGS</h2>
                <div className="w-12"></div>
              </div>

              {/* Toggles */}
              <div className="flex flex-col space-y-4 mt-6">
                <div className="flex items-center justify-between p-4 rounded-xl bg-slate-800/50 border border-slate-700">
                  <div>
                    <div className="font-bold text-sm text-white">Sound Effects</div>
                    <div className="text-xs text-slate-400">Procedural audio chimes & pops</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={soundEnabled}
                    onChange={(e) => setSoundEnabled(e.target.checked)}
                    className="w-5 h-5 accent-emerald-500 rounded cursor-pointer"
                  />
                </div>

                <div className="flex items-center justify-between p-4 rounded-xl bg-slate-800/50 border border-slate-700">
                  <div>
                    <div className="font-bold text-sm text-white">Accessibility Runes</div>
                    <div className="text-xs text-slate-400">High-contrast symbols on bubbles</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={showRunes}
                    onChange={(e) => setShowRunes(e.target.checked)}
                    className="w-5 h-5 accent-emerald-500 rounded cursor-pointer"
                  />
                </div>

                <div className="flex items-center justify-between p-4 rounded-xl bg-slate-800/50 border border-slate-700">
                  <div>
                    <div className="font-bold text-sm text-white">Reduced Effects Mode</div>
                    <div className="text-xs text-slate-400">Disable screen shakes & heavy particles</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={reducedEffects}
                    onChange={(e) => setReducedEffects(e.target.checked)}
                    className="w-5 h-5 accent-emerald-500 rounded cursor-pointer"
                  />
                </div>
              </div>
            </div>

            {/* Reset Data Button */}
            <div className="mb-4">
              <button
                onClick={() => {
                  if (window.confirm("Reset all unlocked progress, stars, and high scores?")) {
                    localStorage.clear();
                    setStarsEarned({ 1: 0 });
                    setUnlockedLevels([1]);
                    setHighScores({});
                    setSeenTutorials([]);
                    alert("Progress reset to default!");
                  }
                }}
                className="w-full py-3 rounded-xl bg-red-950/40 hover:bg-red-900/50 text-red-300 font-bold text-xs border border-red-800/40 transition cursor-pointer"
              >
                ⚠️ RESET ALL GAME SAVE DATA
              </button>
            </div>
          </div>
        )}

        {/* ----------------- SCREEN: GAMEPLAY HUD ----------------- */}
        {currentScreen === 'GAMEPLAY' && (
          <>
            {/* Top Header HUD */}
            <div className="absolute top-0 left-0 right-0 z-20 flex flex-col p-3 bg-gradient-to-b from-slate-950 via-slate-950/80 to-transparent">
              <div className="flex items-center justify-between text-xs font-bold">
                <div className="flex items-center space-x-2">
                  <button
                    onClick={() => {
                      playSynthSound('BOUNCE');
                      setCurrentScreen('WORLD_MAP');
                    }}
                    className="px-2 py-1 bg-emerald-950/80 border border-emerald-800/60 rounded text-emerald-300 text-[10px] cursor-pointer"
                  >
                    MAP
                  </button>
                  <span className="text-emerald-300">LVL {curLvlId}: {curLevel.level_name?.split(':')[1] || curLevel.name}</span>
                </div>
                <div className="text-amber-400 tracking-wider">
                  {currentStars === 1 && '★ ☆ ☆'}
                  {currentStars === 2 && '★ ★ ☆'}
                  {currentStars === 3 && '★ ★ ★'}
                  {currentStars === 0 && '☆ ☆ ☆'}
                </div>
                <button
                  onClick={() => {
                    playSynthSound('BOUNCE');
                    setGameState(gameState === 'PAUSED' ? 'PLAYING' : 'PAUSED');
                  }}
                  className="px-2.5 py-1 bg-slate-800/90 rounded border border-slate-700 text-slate-200 cursor-pointer"
                >
                  {gameState === 'PAUSED' ? '▶' : '⏸'}
                </button>
              </div>

              <div className="flex items-center justify-between mt-2 px-1">
                <div className="text-lg font-black text-white">SCORE: {score}</div>
                <div className={`text-sm font-black ${shotsRemaining <= 5 ? 'text-red-400 animate-pulse' : 'text-emerald-400'}`}>
                  SHOTS: {shotsRemaining}
                </div>
              </div>

              {/* Combo Multiplier Banner */}
              {combo > 1 && (
                <div className="self-center mt-1 px-3 py-0.5 rounded-full bg-amber-500/20 text-amber-300 font-black text-xs border border-amber-500/40 animate-bounce">
                  COMBO x{combo}!
                </div>
              )}
            </div>

            {/* Interactive Canvas */}
            <canvas
              ref={canvasRef}
              width={SCREEN_WIDTH}
              height={SCREEN_HEIGHT}
              onPointerDown={handlePointerDown}
              onPointerMove={handlePointerMove}
              onPointerUp={handlePointerUp}
              className="w-full h-full cursor-crosshair touch-none"
            />

            {/* Bottom Controls (Bubble Swap) */}
            <div className="absolute bottom-4 left-6 z-20">
              <button
                onClick={swapShooterBubbles}
                className="px-3 py-2 rounded-xl bg-emerald-950/80 hover:bg-emerald-900 border border-emerald-700/60 text-emerald-200 text-xs font-bold flex items-center space-x-1.5 shadow-lg active:scale-95 cursor-pointer"
              >
                <span>🔄</span>
                <span>SWAP</span>
              </button>
            </div>
          </>
        )}

        {/* ----------------- MODAL: TUTORIAL OVERLAY ----------------- */}
        {activeTutorial && gameState === 'PAUSED' && (
          <div className="absolute inset-0 z-40 bg-black/75 backdrop-blur-sm flex items-center justify-center p-6">
            <div className="w-full max-w-sm rounded-2xl bg-gradient-to-b from-slate-900 to-emerald-950 border border-emerald-500/50 p-6 flex flex-col items-center text-center space-y-4 shadow-2xl">
              <div className="w-16 h-16 rounded-full bg-amber-400/20 flex items-center justify-center text-3xl">
                ✨
              </div>
              <h3 className="text-lg font-black text-amber-300 tracking-wide">{activeTutorial.title}</h3>
              <p className="text-xs text-slate-300 leading-relaxed">{activeTutorial.text}</p>
              <button
                onClick={() => {
                  playSynthSound('BOUNCE');
                  setActiveTutorial(null);
                  setGameState('PLAYING');
                }}
                className="w-full py-3 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-500 text-slate-950 font-black text-sm shadow-lg shadow-emerald-500/20 hover:brightness-110 cursor-pointer"
              >
                GOT IT! 👍
              </button>
            </div>
          </div>
        )}

        {/* ----------------- MODAL: PAUSE ----------------- */}
        {gameState === 'PAUSED' && !activeTutorial && currentScreen === 'GAMEPLAY' && (
          <div className="absolute inset-0 z-40 bg-black/75 backdrop-blur-sm flex items-center justify-center p-6">
            <div className="w-full max-w-xs rounded-2xl bg-slate-900 border border-slate-700 p-6 flex flex-col items-center space-y-3 shadow-2xl">
              <h3 className="text-xl font-black text-white">PAUSED</h3>
              <div className="w-full flex flex-col space-y-2 mt-2">
                <button
                  onClick={() => setGameState('PLAYING')}
                  className="w-full py-3 rounded-xl bg-emerald-500 text-slate-950 font-black text-sm cursor-pointer"
                >
                  RESUME ▶
                </button>
                <button
                  onClick={restartCurrentLevel}
                  className="w-full py-2.5 rounded-xl bg-slate-800 text-slate-200 font-bold text-xs border border-slate-700 cursor-pointer"
                >
                  RESTART LEVEL 🔄
                </button>
                <button
                  onClick={() => setCurrentScreen('WORLD_MAP')}
                  className="w-full py-2.5 rounded-xl bg-slate-800 text-slate-200 font-bold text-xs border border-slate-700 cursor-pointer"
                >
                  WORLD MAP 🗺️
                </button>
              </div>
            </div>
          </div>
        )}

        {/* ----------------- MODAL: LEVEL COMPLETE (WIN) ----------------- */}
        {gameState === 'WIN' && winModalData && (
          <div className="absolute inset-0 z-40 bg-black/80 backdrop-blur-sm flex items-center justify-center p-6 animate-fadeIn">
            <div className="w-full max-w-xs rounded-3xl bg-gradient-to-b from-emerald-900/90 to-slate-950 border-2 border-emerald-400 p-6 flex flex-col items-center text-center space-y-4 shadow-2xl">
              <div className="text-3xl font-black text-amber-300 drop-shadow">★ VICTORY! ★</div>

              {/* Stars Display */}
              <div className="flex text-3xl text-amber-400 space-x-1 my-1">
                <span>{winModalData.stars >= 1 ? '★' : '☆'}</span>
                <span>{winModalData.stars >= 2 ? '★' : '☆'}</span>
                <span>{winModalData.stars >= 3 ? '★' : '☆'}</span>
              </div>

              <div className="text-sm font-bold text-emerald-200">
                Final Score: <span className="text-white text-base font-black">{winModalData.score}</span>
                {winModalData.isNewHigh && <div className="text-xs text-amber-300 mt-1 font-bold">✨ NEW HIGH SCORE! ✨</div>}
              </div>

              <div className="w-full flex flex-col space-y-2 pt-2">
                <button
                  onClick={nextLevel}
                  className="w-full py-3.5 rounded-xl bg-gradient-to-r from-emerald-400 to-teal-400 text-slate-950 font-black text-sm shadow-lg shadow-emerald-500/30 hover:brightness-110 active:scale-95 cursor-pointer"
                >
                  NEXT LEVEL →
                </button>
                <button
                  onClick={restartCurrentLevel}
                  className="w-full py-2.5 rounded-xl bg-emerald-950 text-emerald-300 font-bold text-xs border border-emerald-800 cursor-pointer"
                >
                  PLAY AGAIN 🔄
                </button>
                <button
                  onClick={() => setCurrentScreen('WORLD_MAP')}
                  className="w-full py-2.5 rounded-xl bg-slate-800 text-slate-300 font-bold text-xs border border-slate-700 cursor-pointer"
                >
                  WORLD MAP 🗺️
                </button>
              </div>
            </div>
          </div>
        )}

        {/* ----------------- MODAL: LEVEL FAILED (LOSE) ----------------- */}
        {gameState === 'LOSE' && loseModalData && (
          <div className="absolute inset-0 z-40 bg-black/80 backdrop-blur-sm flex items-center justify-center p-6 animate-fadeIn">
            <div className="w-full max-w-xs rounded-3xl bg-gradient-to-b from-red-950 to-slate-950 border-2 border-red-500/60 p-6 flex flex-col items-center text-center space-y-4 shadow-2xl">
              <div className="text-2xl font-black text-red-400">LEVEL FAILED</div>
              <p className="text-xs text-slate-300 font-medium">{loseModalData.reason}</p>
              <div className="text-xs text-slate-400">Score: {score}</div>

              <div className="w-full flex flex-col space-y-2 pt-2">
                <button
                  onClick={restartCurrentLevel}
                  className="w-full py-3.5 rounded-xl bg-gradient-to-r from-red-500 to-rose-600 text-white font-black text-sm shadow-lg shadow-red-500/30 hover:brightness-110 active:scale-95 cursor-pointer"
                >
                  TRY AGAIN 🔄
                </button>
                <button
                  onClick={() => setCurrentScreen('WORLD_MAP')}
                  className="w-full py-2.5 rounded-xl bg-slate-800 text-slate-300 font-bold text-xs border border-slate-700 cursor-pointer"
                >
                  WORLD MAP 🗺️
                </button>
              </div>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}
