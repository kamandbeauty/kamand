/**
 * Lumi: Bubblewood Chronicle — Full HTML5 Engine
 * Authoritative Hexagonal Grid, Kinematic Aiming, BFS Matches, Special Bubbles, Lumi Companion
 */

(() => {
    'use strict';

    // --- 1. CONSTANTS & ENUMS ---
    const V_WIDTH = 720;
    const V_HEIGHT = 1280;
    const BUBBLE_RADIUS = 36;
    const BUBBLE_DIAMETER = 72;
    const ROW_HEIGHT = 62.3538; // 72 * sqrt(3)/2
    const GRID_COLS_EVEN = 8;
    const GRID_COLS_ODD = 7;
    const MAX_ROWS = 14;
    const DANGER_ROW = 10;
    const SHOOTER_Y = 1140;
    const SHOOTER_X = 360;
    const PROJECTILE_SPEED = 1800; // px/sec

    const BubbleColor = {
        NONE: 0,
        RED: 1,
        BLUE: 2,
        GREEN: 3,
        YELLOW: 4,
        PURPLE: 5,
        CYAN: 6
    };

    const SpecialType = {
        NONE: 0,
        BOMB: 1,
        RAINBOW: 2,
        LIGHTNING: 3,
        STONE: 4,
        LOCKED: 5
    };

    const ObjectiveType = {
        CLEAR_ALL: 0,
        CLEAR_COLOR: 1,
        REACH_SCORE: 2,
        CLEAR_SPECIAL: 3
    };

    const COLOR_HEX = {
        [BubbleColor.RED]: '#ff3366',
        [BubbleColor.BLUE]: '#00bbff',
        [BubbleColor.GREEN]: '#22dd66',
        [BubbleColor.YELLOW]: '#ffcc00',
        [BubbleColor.PURPLE]: '#cc44ff',
        [BubbleColor.CYAN]: '#00ffcc'
    };

    const COLOR_NAMES = {
        [BubbleColor.RED]: 'Red',
        [BubbleColor.BLUE]: 'Blue',
        [BubbleColor.GREEN]: 'Green',
        [BubbleColor.YELLOW]: 'Yellow',
        [BubbleColor.PURPLE]: 'Purple',
        [BubbleColor.CYAN]: 'Cyan'
    };

    // --- 2. AUDIO SYNTHESIZER (Web Audio API) ---
    class SoundEngine {
        constructor() {
            this.ctx = null;
            this.enabled = true;
            this.sfxVolume = 0.8;
            this.musicVolume = 0.5;
        }

        init() {
            if (!this.ctx) {
                const AudioCtx = window.AudioContext || window.webkitAudioContext;
                if (AudioCtx) this.ctx = new AudioCtx();
            }
            if (this.ctx && this.ctx.state === 'suspended') {
                this.ctx.resume();
            }
        }

        playShoot() {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(480, now);
            osc.frequency.exponentialRampToValueAtTime(180, now + 0.08);
            gain.gain.setValueAtTime(0.3 * this.sfxVolume, now);
            gain.gain.linearRampToValueAtTime(0.01, now + 0.08);
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            osc.start(now);
            osc.stop(now + 0.08);
        }

        playBounce() {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(650, now);
            gain.gain.setValueAtTime(0.2 * this.sfxVolume, now);
            gain.gain.linearRampToValueAtTime(0.01, now + 0.06);
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            osc.start(now);
            osc.stop(now + 0.06);
        }

        playMatch(combo = 1) {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const notes = [523.25, 659.25, 783.99, 1046.50]; // C, E, G, C
            const freq = notes[Math.min(combo - 1, notes.length - 1)];
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(freq, now);
            gain.gain.setValueAtTime(0.4 * this.sfxVolume, now);
            gain.gain.exponentialRampToValueAtTime(0.01, now + 0.18);
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            osc.start(now);
            osc.stop(now + 0.18);
        }

        playDrop() {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(320, now);
            osc.frequency.exponentialRampToValueAtTime(80, now + 0.22);
            gain.gain.setValueAtTime(0.35 * this.sfxVolume, now);
            gain.gain.linearRampToValueAtTime(0.01, now + 0.22);
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            osc.start(now);
            osc.stop(now + 0.22);
        }

        playWin() {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const chord = [523.25, 659.25, 783.99, 1046.50];
            chord.forEach((f, i) => {
                const osc = this.ctx.createOscillator();
                const gain = this.ctx.createGain();
                osc.type = 'triangle';
                osc.frequency.setValueAtTime(f, now + i * 0.08);
                gain.gain.setValueAtTime(0.3 * this.sfxVolume, now + i * 0.08);
                gain.gain.exponentialRampToValueAtTime(0.01, now + i * 0.08 + 0.5);
                osc.connect(gain);
                gain.connect(this.ctx.destination);
                osc.start(now + i * 0.08);
                osc.stop(now + i * 0.08 + 0.5);
            });
        }

        playLose() {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const notes = [400, 350, 300, 240];
            notes.forEach((f, i) => {
                const osc = this.ctx.createOscillator();
                const gain = this.ctx.createGain();
                osc.type = 'sawtooth';
                osc.frequency.setValueAtTime(f, now + i * 0.1);
                gain.gain.setValueAtTime(0.2 * this.sfxVolume, now + i * 0.1);
                gain.gain.linearRampToValueAtTime(0.01, now + i * 0.1 + 0.25);
                osc.connect(gain);
                gain.connect(this.ctx.destination);
                osc.start(now + i * 0.1);
                osc.stop(now + i * 0.1 + 0.25);
            });
        }

        playClick() {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(800, now);
            gain.gain.setValueAtTime(0.15 * this.sfxVolume, now);
            gain.gain.linearRampToValueAtTime(0.01, now + 0.04);
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            osc.start(now);
            osc.stop(now + 0.04);
        }
    }

    const sound = new SoundEngine();

    // --- 3. SAVE SYSTEM (LocalStorage V3) ---
    class SaveManager {
        constructor() {
            this.STORAGE_KEY = 'lumi_bubblewood_save_v3';
            this.data = {
                version: 3,
                unlocked_level: 1,
                stars: {},
                high_scores: {},
                settings: { sfx_volume: 0.8, music_volume: 0.5, sound_enabled: true }
            };
            this.load();
        }

        load() {
            try {
                const str = localStorage.getItem(this.STORAGE_KEY);
                if (str) {
                    const parsed = JSON.parse(str);
                    if (parsed && typeof parsed === 'object') {
                        this.data = Object.assign(this.data, parsed);
                        sound.enabled = this.data.settings.sound_enabled !== false;
                        sound.sfxVolume = this.data.settings.sfx_volume ?? 0.8;
                    }
                }
            } catch (e) {
                console.error("Save load error:", e);
            }
        }

        save() {
            try {
                localStorage.setItem(this.STORAGE_KEY, JSON.stringify(this.data));
            } catch (e) {
                console.error("Save store error:", e);
            }
        }

        unlockNextLevel(lvl) {
            if (lvl + 1 > this.data.unlocked_level && lvl + 1 <= 30) {
                this.data.unlocked_level = lvl + 1;
            }
            this.save();
        }

        setStars(lvl, starCount, score) {
            const currentStars = this.data.stars[lvl] || 0;
            if (starCount > currentStars) {
                this.data.stars[lvl] = starCount;
            }
            const currentScore = this.data.high_scores[lvl] || 0;
            if (score > currentScore) {
                this.data.high_scores[lvl] = score;
            }
            this.unlockNextLevel(lvl);
        }

        getTotalStars() {
            return Object.values(this.data.stars).reduce((a, b) => a + b, 0);
        }

        resetProgress() {
            this.data.unlocked_level = 1;
            this.data.stars = {};
            this.data.high_scores = {};
            this.save();
        }
    }

    const saveManager = new SaveManager();

    // --- 4. LUMI COMPANION VISUAL SPRITE ---
    class LumiCompanion {
        constructor(x, y) {
            this.x = x;
            this.y = y;
            this.state = 'IDLE'; // IDLE, AIM, HAPPY, SURPRISED
            this.timer = 0;
            this.aimAngle = -Math.PI / 2;
        }

        update(dt) {
            this.timer += dt;
        }

        draw(ctx) {
            ctx.save();
            ctx.translate(this.x, this.y);

            const breathe = Math.sin(this.timer * 3) * 3;
            const bounce = this.state === 'HAPPY' ? Math.abs(Math.sin(this.timer * 12)) * 14 : 0;
            const scaleY = this.state === 'HAPPY' ? 1 + Math.sin(this.timer * 12) * 0.15 : 1;

            ctx.translate(0, -bounce);
            ctx.scale(1, scaleY);

            // Shadow
            ctx.fillStyle = 'rgba(0,0,0,0.25)';
            ctx.beginPath();
            ctx.ellipse(0, 38 + bounce * 0.5, 34, 12, 0, 0, Math.PI * 2);
            ctx.fill();

            // Glow Aura
            const grad = ctx.createRadialGradient(0, 0, 10, 0, 0, 50);
            grad.addColorStop(0, 'rgba(0, 255, 200, 0.4)');
            grad.addColorStop(1, 'rgba(0, 255, 200, 0)');
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.arc(0, 0, 50, 0, Math.PI * 2);
            ctx.fill();

            // Body
            ctx.fillStyle = '#4ae3b5';
            ctx.beginPath();
            ctx.arc(0, breathe * 0.5, 32, 0, Math.PI * 2);
            ctx.fill();

            // Belly Highlight
            ctx.fillStyle = '#a6f7df';
            ctx.beginPath();
            ctx.ellipse(0, 8 + breathe * 0.5, 20, 16, 0, 0, Math.PI * 2);
            ctx.fill();

            // Ears/Antenna
            ctx.fillStyle = '#2bb88d';
            ctx.beginPath();
            ctx.ellipse(-22, -22 + breathe, 8, 16, -Math.PI / 6, 0, Math.PI * 2);
            ctx.ellipse(22, -22 + breathe, 8, 16, Math.PI / 6, 0, Math.PI * 2);
            ctx.fill();

            // Ear tips glowing
            ctx.fillStyle = '#ffec5c';
            ctx.beginPath();
            ctx.arc(-26, -34 + breathe, 5, 0, Math.PI * 2);
            ctx.arc(26, -34 + breathe, 5, 0, Math.PI * 2);
            ctx.fill();

            // Eyes
            const eyeOffset = this.state === 'AIM' ? Math.cos(this.aimAngle) * 4 : 0;
            const eyeOffsetY = this.state === 'AIM' ? Math.sin(this.aimAngle) * 4 : 0;

            if (this.state === 'HAPPY') {
                // Curved closed joyful eyes ^ ^
                ctx.strokeStyle = '#1b3b30';
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(-10, -4, 6, Math.PI, Math.PI * 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(10, -4, 6, Math.PI, Math.PI * 2);
                ctx.stroke();
            } else if (this.state === 'SURPRISED') {
                // Wide open circles
                ctx.fillStyle = '#1b3b30';
                ctx.beginPath();
                ctx.arc(-10, -4, 7, 0, Math.PI * 2);
                ctx.arc(10, -4, 7, 0, Math.PI * 2);
                ctx.fill();
                // Shine
                ctx.fillStyle = '#ffffff';
                ctx.beginPath();
                ctx.arc(-12, -6, 2.5, 0, Math.PI * 2);
                ctx.arc(8, -6, 2.5, 0, Math.PI * 2);
                ctx.fill();
            } else {
                // Normal cute eyes looking around
                ctx.fillStyle = '#1b3b30';
                ctx.beginPath();
                ctx.arc(-10 + eyeOffset, -4 + eyeOffsetY, 5, 0, Math.PI * 2);
                ctx.arc(10 + eyeOffset, -4 + eyeOffsetY, 5, 0, Math.PI * 2);
                ctx.fill();
                // Eye shine
                ctx.fillStyle = '#ffffff';
                ctx.beginPath();
                ctx.arc(-12 + eyeOffset, -6 + eyeOffsetY, 2, 0, Math.PI * 2);
                ctx.arc(8 + eyeOffset, -6 + eyeOffsetY, 2, 0, Math.PI * 2);
                ctx.fill();
            }

            // Cheeks
            ctx.fillStyle = 'rgba(255, 120, 150, 0.5)';
            ctx.beginPath();
            ctx.arc(-18, 5, 5, 0, Math.PI * 2);
            ctx.arc(18, 5, 5, 0, Math.PI * 2);
            ctx.fill();

            // Mouth
            ctx.strokeStyle = '#1b3b30';
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            if (this.state === 'HAPPY') {
                ctx.arc(0, 4, 6, 0, Math.PI);
            } else if (this.state === 'SURPRISED') {
                ctx.arc(0, 8, 4, 0, Math.PI * 2);
            } else {
                ctx.arc(0, 4, 4, 0.2, Math.PI - 0.2);
            }
            ctx.stroke();

            ctx.restore();
        }
    }

    // --- 5. PARTICLE SYSTEM & POPUPS ---
    class ParticleManager {
        constructor() {
            this.particles = [];
            this.popups = [];
        }

        spawnBurst(x, y, colorHex, count = 14) {
            for (let i = 0; i < count; i++) {
                const angle = Math.random() * Math.PI * 2;
                const speed = 120 + Math.random() * 280;
                this.particles.push({
                    x, y,
                    vx: Math.cos(angle) * speed,
                    vy: Math.sin(angle) * speed,
                    radius: 3 + Math.random() * 5,
                    color: colorHex,
                    alpha: 1.0,
                    life: 0.4 + Math.random() * 0.3,
                    maxLife: 0.7
                });
            }
        }

        spawnPopup(text, x, y, color = '#ffffff') {
            this.popups.push({
                text, x, y,
                vy: -80,
                alpha: 1.0,
                life: 1.0
            });
        }

        update(dt) {
            for (let i = this.particles.length - 1; i >= 0; i--) {
                const p = this.particles[i];
                p.x += p.vx * dt;
                p.y += p.vy * dt;
                p.vy += 300 * dt; // gravity
                p.life -= dt;
                p.alpha = Math.max(0, p.life / p.maxLife);
                if (p.life <= 0) this.particles.splice(i, 1);
            }

            for (let i = this.popups.length - 1; i >= 0; i--) {
                const pop = this.popups[i];
                pop.y += pop.vy * dt;
                pop.life -= dt;
                pop.alpha = Math.max(0, pop.life);
                if (pop.life <= 0) this.popups.splice(i, 1);
            }
        }

        draw(ctx) {
            ctx.save();
            for (const p of this.particles) {
                ctx.globalAlpha = p.alpha;
                ctx.fillStyle = p.color;
                ctx.beginPath();
                ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
                ctx.fill();
            }

            for (const pop of this.popups) {
                ctx.globalAlpha = pop.alpha;
                ctx.fillStyle = '#ffd700';
                ctx.font = 'bold 32px sans-serif';
                ctx.textAlign = 'center';
                ctx.shadowColor = 'rgba(0,0,0,0.8)';
                ctx.shadowBlur = 8;
                ctx.fillText(pop.text, pop.x, pop.y);
            }
            ctx.restore();
        }
    }

    // --- 6. HEXAGONAL GRID MATH ---
    function getGridPosition(r, c) {
        const isOdd = r % 2 !== 0;
        const xOffset = isOdd ? BUBBLE_RADIUS * 2 : BUBBLE_RADIUS;
        const x = xOffset + c * BUBBLE_DIAMETER;
        const y = BUBBLE_RADIUS + r * ROW_HEIGHT + 140; // Top margin
        return { x, y };
    }

    function getNeighbors(r, c) {
        const isOdd = r % 2 !== 0;
        const offsets = isOdd
            ? [[0, -1], [0, 1], [-1, 0], [-1, 1], [1, 0], [1, 1]]
            : [[0, -1], [0, 1], [-1, -1], [-1, 0], [1, -1], [1, 0]];

        const result = [];
        for (const [dr, dc] of offsets) {
            const nr = r + dr;
            const nc = c + dc;
            const maxCols = nr % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
            if (nr >= 0 && nr < MAX_ROWS && nc >= 0 && nc < maxCols) {
                result.push({ r: nr, c: nc });
            }
        }
        return result;
    }

    // --- 7. MAIN GAME CONTROLLER & STATE MACHINE ---
    class BubbleShooterGame {
        constructor() {
            this.canvas = document.getElementById('gameCanvas');
            this.ctx = this.canvas.getContext('2d');
            this.particles = new ParticleManager();
            this.lumi = new LumiCompanion(120, SHOOTER_Y - 20);

            this.currentScreen = 'MENU'; // MENU, WORLD_MAP, GAMEPLAY, SETTINGS, TUTORIAL
            this.currentLevelId = 1;
            this.currentWorldId = 1;

            // Grid state: 2D array of { color, special, locked, animY, isDropping, vx, vy }
            this.grid = [];
            this.currentBubble = null;
            this.nextBubble = null;
            this.projectile = null;
            this.droppingBubbles = [];

            this.score = 0;
            this.shotsLeft = 30;
            this.combo = 1;
            this.aimAngle = -Math.PI / 2;
            this.isAiming = false;
            this.aimPath = [];

            // Objective tracking
            this.objectiveMet = false;
            this.objectiveCount = 0;
            this.targetCount = 0;
            this.targetScore = 0;
            this.objectiveType = ObjectiveType.CLEAR_ALL;
            this.objectiveTargetColor = BubbleColor.NONE;

            // Modals
            this.modalState = null; // 'WIN', 'LOSE', 'PAUSE'

            this.lastTime = performance.now();
            this.initEvents();
            this.setupResponsiveCanvas();
            this.loop = this.loop.bind(this);
            requestAnimationFrame(this.loop);
        }

        setupResponsiveCanvas() {
            const resize = () => {
                const container = document.getElementById('game-container');
                const w = container.clientWidth;
                const h = container.clientHeight;
                this.scale = Math.min(w / V_WIDTH, h / V_HEIGHT);
            };
            window.addEventListener('resize', resize);
            resize();
        }

        initEvents() {
            const getCanvasPos = (e) => {
                const rect = this.canvas.getBoundingClientRect();
                const clientX = e.touches ? e.touches[0].clientX : e.clientX;
                const clientY = e.touches ? e.touches[0].clientY : e.clientY;
                const x = (clientX - rect.left) * (V_WIDTH / rect.width);
                const y = (clientY - rect.top) * (V_HEIGHT / rect.height);
                return { x, y };
            };

            const onDown = (e) => {
                sound.init();
                const { x, y } = getCanvasPos(e);
                this.handlePointerDown(x, y);
            };

            const onMove = (e) => {
                const { x, y } = getCanvasPos(e);
                this.handlePointerMove(x, y);
            };

            const onUp = (e) => {
                const { x, y } = getCanvasPos(e);
                this.handlePointerUp(x, y);
            };

            this.canvas.addEventListener('mousedown', onDown);
            this.canvas.addEventListener('mousemove', onMove);
            window.addEventListener('mouseup', onUp);

            this.canvas.addEventListener('touchstart', onDown, { passive: false });
            this.canvas.addEventListener('touchmove', onMove, { passive: false });
            window.addEventListener('touchend', onUp, { passive: false });
        }

        loadLevel(levelId) {
            this.currentLevelId = levelId;
            const lvl = (window.GAME_LEVELS && window.GAME_LEVELS[levelId]) || this.getFallbackLevel(levelId);

            this.currentWorldId = lvl.world_id || 1;
            this.shotsLeft = lvl.max_shots || 25;
            this.score = 0;
            this.combo = 1;
            this.objectiveMet = false;
            this.objectiveCount = 0;
            this.targetCount = lvl.target_count || lvl.objective_target_count || 0;
            this.targetScore = lvl.target_score || 500;
            this.objectiveType = lvl.objective_type || ObjectiveType.CLEAR_ALL;
            this.objectiveTargetColor = lvl.target_color || lvl.objective_target_color || BubbleColor.NONE;
            this.modalState = null;
            this.projectile = null;
            this.droppingBubbles = [];

            // Initialize Grid
            this.grid = [];
            for (let r = 0; r < MAX_ROWS; r++) {
                const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                this.grid[r] = [];
                for (let c = 0; c < cols; c++) {
                    this.grid[r][c] = null;
                }
            }

            // Populate rows from JSON layout
            const rows = lvl.layout_rows || [];
            const allowedColors = lvl.allowed_colors || [BubbleColor.RED, BubbleColor.BLUE, BubbleColor.GREEN];
            const specials = lvl.special_layout || {};

            for (let r = 0; r < rows.length && r < MAX_ROWS; r++) {
                const str = rows[r];
                const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                for (let c = 0; c < str.length && c < cols; c++) {
                    const ch = str[c].toUpperCase();
                    let color = BubbleColor.NONE;
                    if (ch === 'R') color = BubbleColor.RED;
                    else if (ch === 'B') color = BubbleColor.BLUE;
                    else if (ch === 'G') color = BubbleColor.GREEN;
                    else if (ch === 'Y') color = BubbleColor.YELLOW;
                    else if (ch === 'P') color = BubbleColor.PURPLE;
                    else if (ch === 'C') color = BubbleColor.CYAN;

                    if (color !== BubbleColor.NONE) {
                        const key = `${r},${c}`;
                        const special = specials[key] || SpecialType.NONE;
                        this.grid[r][c] = {
                            color,
                            special,
                            locked: special === SpecialType.LOCKED
                        };
                    }
                }
            }

            this.allowedColors = allowedColors;
            this.generateShooterBubbles();
            this.currentScreen = 'GAMEPLAY';
            this.lumi.state = 'IDLE';
        }

        getFallbackLevel(id) {
            return {
                level_id: id,
                world_id: id > 20 ? 3 : (id > 10 ? 2 : 1),
                level_name: `Level ${id}`,
                max_shots: 30,
                target_score: 500,
                objective_type: ObjectiveType.CLEAR_ALL,
                allowed_colors: [BubbleColor.RED, BubbleColor.BLUE, BubbleColor.GREEN],
                layout_rows: [
                    "RRBBGGYY",
                    "RBBGGYY",
                    "RRBBGGYY"
                ]
            };
        }

        generateShooterBubbles() {
            const availableColors = this.getGridColors();
            const colors = availableColors.length > 0 ? availableColors : this.allowedColors;

            const pickColor = () => colors[Math.floor(Math.random() * colors.length)] || BubbleColor.RED;

            if (!this.currentBubble) {
                this.currentBubble = { color: pickColor(), special: SpecialType.NONE };
            }
            this.nextBubble = { color: pickColor(), special: SpecialType.NONE };
        }

        getGridColors() {
            const set = new Set();
            for (let r = 0; r < MAX_ROWS; r++) {
                const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                for (let c = 0; c < cols; c++) {
                    const b = this.grid[r][c];
                    if (b && b.color !== BubbleColor.NONE && b.special !== SpecialType.STONE) {
                        set.add(b.color);
                    }
                }
            }
            return Array.from(set);
        }

        swapShooterBubbles() {
            if (this.projectile || !this.nextBubble) return;
            sound.playClick();
            const temp = this.currentBubble;
            this.currentBubble = this.nextBubble;
            this.nextBubble = temp;
        }

        calculateAimTrajectory() {
            this.aimPath = [];
            let currX = SHOOTER_X;
            let currY = SHOOTER_Y;
            let dirX = Math.cos(this.aimAngle);
            let dirY = Math.sin(this.aimAngle);

            let remainingDist = 950;
            this.aimPath.push({ x: currX, y: currY });

            for (let bounce = 0; bounce < 3 && remainingDist > 0; bounce++) {
                // Wall collisions
                let targetX, targetY, hitWall = false;

                if (dirX < 0) {
                    const distToLeft = (currX - BUBBLE_RADIUS) / -dirX;
                    targetX = BUBBLE_RADIUS;
                    targetY = currY + dirY * distToLeft;
                    if (targetY < 140) {
                        const distToTop = (currY - 140) / -dirY;
                        targetX = currX + dirX * distToTop;
                        targetY = 140;
                    } else {
                        hitWall = true;
                    }
                } else if (dirX > 0) {
                    const distToRight = (V_WIDTH - BUBBLE_RADIUS - currX) / dirX;
                    targetX = V_WIDTH - BUBBLE_RADIUS;
                    targetY = currY + dirY * distToRight;
                    if (targetY < 140) {
                        const distToTop = (currY - 140) / -dirY;
                        targetX = currX + dirX * distToTop;
                        targetY = 140;
                    } else {
                        hitWall = true;
                    }
                } else {
                    targetX = currX;
                    targetY = 140;
                }

                // Check collision with existing bubbles along segment
                const segmentDist = Math.hypot(targetX - currX, targetY - currY);
                const steps = Math.ceil(segmentDist / 12);
                let hitBubble = false;

                for (let s = 1; s <= steps; s++) {
                    const t = s / steps;
                    const testX = currX + (targetX - currX) * t;
                    const testY = currY + (targetY - currY) * t;

                    for (let r = 0; r < MAX_ROWS; r++) {
                        const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                        for (let c = 0; c < cols; c++) {
                            if (this.grid[r][c]) {
                                const pos = getGridPosition(r, c);
                                if (Math.hypot(pos.x - testX, pos.y - testY) <= BUBBLE_DIAMETER * 0.92) {
                                    this.aimPath.push({ x: testX, y: testY });
                                    return;
                                }
                            }
                        }
                    }
                }

                this.aimPath.push({ x: targetX, y: targetY });
                if (hitWall) {
                    dirX = -dirX;
                    currX = targetX;
                    currY = targetY;
                } else {
                    break;
                }
            }
        }

        shootBubble() {
            if (this.projectile || this.shotsLeft <= 0 || this.modalState) return;

            sound.playShoot();
            this.projectile = {
                x: SHOOTER_X,
                y: SHOOTER_Y,
                vx: Math.cos(this.aimAngle) * PROJECTILE_SPEED,
                vy: Math.sin(this.aimAngle) * PROJECTILE_SPEED,
                color: this.currentBubble.color,
                special: this.currentBubble.special
            };

            this.shotsLeft--;
            this.lumi.state = 'AIM';

            // Prepare next
            this.currentBubble = this.nextBubble;
            this.generateShooterBubbles();
        }

        updateProjectile(dt) {
            if (!this.projectile) return;

            const p = this.projectile;
            p.x += p.vx * dt;
            p.y += p.vy * dt;

            // Wall bounces
            if (p.x <= BUBBLE_RADIUS) {
                p.x = BUBBLE_RADIUS;
                p.vx = Math.abs(p.vx);
                sound.playBounce();
            } else if (p.x >= V_WIDTH - BUBBLE_RADIUS) {
                p.x = V_WIDTH - BUBBLE_RADIUS;
                p.vx = -Math.abs(p.vx);
                sound.playBounce();
            }

            // Ceiling snap
            if (p.y <= 140 + BUBBLE_RADIUS) {
                this.snapProjectileToGrid(p);
                return;
            }

            // Grid bubble collisions
            for (let r = 0; r < MAX_ROWS; r++) {
                const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                for (let c = 0; c < cols; c++) {
                    if (this.grid[r][c]) {
                        const pos = getGridPosition(r, c);
                        const dist = Math.hypot(pos.x - p.x, pos.y - p.y);
                        if (dist <= BUBBLE_DIAMETER * 0.88) {
                            this.snapProjectileToGrid(p);
                            return;
                        }
                    }
                }
            }
        }

        snapProjectileToGrid(p) {
            let bestCell = null;
            let minDist = Infinity;

            for (let r = 0; r < MAX_ROWS; r++) {
                const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                for (let c = 0; c < cols; c++) {
                    if (!this.grid[r][c]) {
                        // Must be adjacent to ceiling or adjacent to an existing bubble
                        const hasAnchor = r === 0 || getNeighbors(r, c).some(n => this.grid[n.r][n.c]);
                        if (hasAnchor) {
                            const pos = getGridPosition(r, c);
                            const d = Math.hypot(pos.x - p.x, pos.y - p.y);
                            if (d < minDist) {
                                minDist = d;
                                bestCell = { r, c };
                            }
                        }
                    }
                }
            }

            if (!bestCell) {
                bestCell = { r: 0, c: Math.min(Math.floor(p.x / BUBBLE_DIAMETER), 7) };
            }

            this.grid[bestCell.r][bestCell.c] = {
                color: p.color,
                special: p.special,
                locked: false
            };

            const snapPos = getGridPosition(bestCell.r, bestCell.c);
            this.particles.spawnBurst(snapPos.x, snapPos.y, COLOR_HEX[p.color] || '#ffffff', 8);

            this.projectile = null;
            this.processGridAfterShot(bestCell.r, bestCell.c, p);
        }

        processGridAfterShot(r, c, p) {
            let poppedAny = false;

            // Handle Specials (Bomb, Rainbow, Lightning)
            if (p.special === SpecialType.BOMB) {
                this.executeBomb(r, c);
                poppedAny = true;
            } else if (p.special === SpecialType.LIGHTNING) {
                this.executeLightning(r);
                poppedAny = true;
            } else {
                // BFS Match Detection (3+ connected same color)
                const matches = this.findMatches(r, c);
                if (matches.length >= 3) {
                    poppedAny = true;
                    this.popMatches(matches);
                } else {
                    this.combo = 1;
                }
            }

            // Detect & drop floating bubbles
            const floaters = this.detectFloatingBubbles();
            if (floaters.length > 0) {
                this.dropFloatingBubbles(floaters);
            }

            // Unlock adjacent ice bubbles
            this.unlockAdjacentLocked(r, c);

            // Check Win/Loss conditions
            this.checkGameOutcome();
        }

        findMatches(startR, startC) {
            const startBubble = this.grid[startR][startC];
            if (!startBubble || startBubble.special === SpecialType.STONE) return [];

            const targetColor = startBubble.color;
            const visited = new Set();
            const queue = [{ r: startR, c: startC }];
            visited.add(`${startR},${startC}`);
            const matches = [];

            while (queue.length > 0) {
                const curr = queue.shift();
                matches.push(curr);

                for (const n of getNeighbors(curr.r, curr.c)) {
                    const key = `${n.r},${n.c}`;
                    if (!visited.has(key)) {
                        const nb = this.grid[n.r][n.c];
                        if (nb && !nb.locked && nb.special !== SpecialType.STONE) {
                            if (nb.color === targetColor || nb.special === SpecialType.RAINBOW) {
                                visited.add(key);
                                queue.push(n);
                            }
                        }
                    }
                }
            }
            return matches;
        }

        popMatches(matches) {
            const pts = matches.length * 10 * this.combo;
            this.score += pts;
            sound.playMatch(this.combo);

            let lastPos = { x: SHOOTER_X, y: 300 };
            for (const m of matches) {
                const b = this.grid[m.r][m.c];
                if (b) {
                    const pos = getGridPosition(m.r, m.c);
                    lastPos = pos;
                    this.particles.spawnBurst(pos.x, pos.y, COLOR_HEX[b.color] || '#ffffff', 16);
                    if (this.objectiveType === ObjectiveType.CLEAR_COLOR && b.color === this.objectiveTargetColor) {
                        this.objectiveCount++;
                    }
                    this.grid[m.r][m.c] = null;
                }
            }

            this.particles.spawnPopup(`+${pts}` + (this.combo > 1 ? ` (x${this.combo})` : ''), lastPos.x, lastPos.y);
            this.combo++;
            this.lumi.state = 'HAPPY';
            setTimeout(() => { if (this.lumi.state === 'HAPPY') this.lumi.state = 'IDLE'; }, 1200);
        }

        executeBomb(r, c) {
            sound.playMatch(3);
            const targets = [{ r, c }, ...getNeighbors(r, c)];
            let pts = 0;
            for (const t of targets) {
                const b = this.grid[t.r][t.c];
                if (b) {
                    const pos = getGridPosition(t.r, t.c);
                    this.particles.spawnBurst(pos.x, pos.y, '#ff4400', 20);
                    this.grid[t.r][t.c] = null;
                    pts += 15;
                    if (this.objectiveType === ObjectiveType.CLEAR_SPECIAL) this.objectiveCount++;
                }
            }
            this.score += pts;
            const pos = getGridPosition(r, c);
            this.particles.spawnPopup(`BOOM! +${pts}`, pos.x, pos.y);
        }

        executeLightning(row) {
            sound.playMatch(4);
            const cols = row % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
            let pts = 0;
            for (let c = 0; c < cols; c++) {
                const b = this.grid[row][c];
                if (b) {
                    const pos = getGridPosition(row, c);
                    this.particles.spawnBurst(pos.x, pos.y, '#00e5ff', 18);
                    this.grid[row][c] = null;
                    pts += 20;
                }
            }
            this.score += pts;
            this.particles.spawnPopup(`LIGHTNING! +${pts}`, V_WIDTH / 2, getGridPosition(row, 0).y);
        }

        unlockAdjacentLocked(r, c) {
            for (const n of getNeighbors(r, c)) {
                const b = this.grid[n.r][n.c];
                if (b && b.locked) {
                    b.locked = false;
                    b.special = SpecialType.NONE;
                    const pos = getGridPosition(n.r, n.c);
                    this.particles.spawnBurst(pos.x, pos.y, '#a6f7df', 12);
                    this.particles.spawnPopup('UNLOCKED!', pos.x, pos.y);
                }
            }
        }

        detectFloatingBubbles() {
            const visited = new Set();
            const queue = [];

            // Anchor: all row 0 bubbles
            for (let c = 0; c < GRID_COLS_EVEN; c++) {
                if (this.grid[0][c]) {
                    visited.add(`0,${c}`);
                    queue.push({ r: 0, c });
                }
            }

            while (queue.length > 0) {
                const curr = queue.shift();
                for (const n of getNeighbors(curr.r, curr.c)) {
                    const key = `${n.r},${n.c}`;
                    if (!visited.has(key) && this.grid[n.r][n.c]) {
                        visited.add(key);
                        queue.push(n);
                    }
                }
            }

            // Unvisited bubbles are floating!
            const floaters = [];
            for (let r = 0; r < MAX_ROWS; r++) {
                const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                for (let c = 0; c < cols; c++) {
                    if (this.grid[r][c] && !visited.has(`${r},${c}`)) {
                        floaters.push({ r, c, bubble: this.grid[r][c] });
                        this.grid[r][c] = null;
                    }
                }
            }
            return floaters;
        }

        dropFloatingBubbles(floaters) {
            sound.playDrop();
            const pts = floaters.length * 20;
            this.score += pts;

            for (const f of floaters) {
                const pos = getGridPosition(f.r, f.c);
                this.droppingBubbles.push({
                    x: pos.x,
                    y: pos.y,
                    vx: (Math.random() - 0.5) * 120,
                    vy: -50 - Math.random() * 80,
                    color: f.bubble.color,
                    special: f.bubble.special
                });
            }

            this.particles.spawnPopup(`DROP! +${pts}`, V_WIDTH / 2, 400);
        }

        updateDroppingBubbles(dt) {
            for (let i = this.droppingBubbles.length - 1; i >= 0; i--) {
                const d = this.droppingBubbles[i];
                d.x += d.vx * dt;
                d.y += d.vy * dt;
                d.vy += 1200 * dt; // gravity
                if (d.y > V_HEIGHT + 100) {
                    this.droppingBubbles.splice(i, 1);
                }
            }
        }

        checkGameOutcome() {
            // Check Win
            let isWon = false;
            const remainingBubbles = this.getGridColors().length;

            if (this.objectiveType === ObjectiveType.CLEAR_ALL) {
                isWon = remainingBubbles === 0;
            } else if (this.objectiveType === ObjectiveType.CLEAR_COLOR) {
                isWon = this.objectiveCount >= this.targetCount;
            } else if (this.objectiveType === ObjectiveType.REACH_SCORE) {
                isWon = this.score >= this.targetScore;
            } else if (this.objectiveType === ObjectiveType.CLEAR_SPECIAL) {
                isWon = this.objectiveCount >= this.targetCount;
            }

            if (isWon) {
                this.handleWin();
                return;
            }

            // Check Loss: Danger line crossed
            for (let c = 0; c < (DANGER_ROW % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD); c++) {
                if (this.grid[DANGER_ROW][c]) {
                    this.handleLoss("Bubbles reached the danger line!");
                    return;
                }
            }

            // Check Loss: Shots depleted
            if (this.shotsLeft <= 0 && !this.projectile) {
                this.handleLoss("Out of shots!");
            }
        }

        handleWin() {
            sound.playWin();
            this.modalState = 'WIN';
            const stars = this.score >= this.targetScore * 1.5 ? 3 : (this.score >= this.targetScore ? 2 : 1);
            saveManager.setStars(this.currentLevelId, stars, this.score);
            this.lumi.state = 'HAPPY';
        }

        handleLoss(reason) {
            sound.playLose();
            this.modalState = 'LOSE';
            this.lossReason = reason;
            this.lumi.state = 'SURPRISED';
        }

        // --- 8. INPUT HANDLING ---
        handlePointerDown(x, y) {
            if (this.modalState) {
                this.handleModalClick(x, y);
                return;
            }

            if (this.currentScreen === 'MENU') {
                this.handleMenuClick(x, y);
                return;
            }

            if (this.currentScreen === 'WORLD_MAP') {
                this.handleMapClick(x, y);
                return;
            }

            if (this.currentScreen === 'SETTINGS') {
                this.handleSettingsClick(x, y);
                return;
            }

            if (this.currentScreen === 'TUTORIAL') {
                this.currentScreen = 'GAMEPLAY';
                return;
            }

            if (this.currentScreen === 'GAMEPLAY') {
                // Pause button
                if (x >= V_WIDTH - 90 && x <= V_WIDTH - 20 && y >= 20 && y <= 80) {
                    sound.playClick();
                    this.modalState = 'PAUSE';
                    return;
                }

                // Swap bubbles button (bottom shooter area)
                if (Math.hypot(x - (SHOOTER_X + 110), y - SHOOTER_Y) <= 45) {
                    this.swapShooterBubbles();
                    return;
                }

                // Aim & shoot
                if (y < SHOOTER_Y - 20) {
                    this.isAiming = true;
                    this.updateAim(x, y);
                }
            }
        }

        handlePointerMove(x, y) {
            if (this.isAiming && this.currentScreen === 'GAMEPLAY' && !this.modalState) {
                this.updateAim(x, y);
            }
        }

        handlePointerUp(x, y) {
            if (this.isAiming && this.currentScreen === 'GAMEPLAY' && !this.modalState) {
                this.isAiming = false;
                this.shootBubble();
            }
        }

        updateAim(x, y) {
            const angle = Math.atan2(y - SHOOTER_Y, x - SHOOTER_X);
            // Clamp between -165 deg and -15 deg
            this.aimAngle = Math.max(-Math.PI * 0.92, Math.min(-Math.PI * 0.08, angle));
            this.lumi.aimAngle = this.aimAngle;
            this.calculateAimTrajectory();
        }

        handleMenuClick(x, y) {
            // Play Button
            if (x >= 200 && x <= 520 && y >= 640 && y <= 730) {
                sound.playClick();
                this.currentScreen = 'WORLD_MAP';
            }
            // Tutorial Button
            else if (x >= 200 && x <= 520 && y >= 760 && y <= 840) {
                sound.playClick();
                this.currentScreen = 'TUTORIAL';
            }
            // Settings Button
            else if (x >= 200 && x <= 520 && y >= 870 && y <= 950) {
                sound.playClick();
                this.currentScreen = 'SETTINGS';
            }
        }

        handleMapClick(x, y) {
            // Back button
            if (x >= 30 && x <= 120 && y >= 30 && y <= 90) {
                sound.playClick();
                this.currentScreen = 'MENU';
                return;
            }

            // World tabs
            if (y >= 120 && y <= 180) {
                if (x >= 40 && x <= 240) { sound.playClick(); this.currentWorldId = 1; }
                else if (x >= 260 && x <= 460) {
                    if (saveManager.getTotalStars() >= 10) { sound.playClick(); this.currentWorldId = 2; }
                    else { sound.playBounce(); }
                }
                else if (x >= 480 && x <= 680) {
                    if (saveManager.getTotalStars() >= 25) { sound.playClick(); this.currentWorldId = 3; }
                    else { sound.playBounce(); }
                }
                return;
            }

            // 10 Level Nodes per world
            const startId = (this.currentWorldId - 1) * 10 + 1;
            for (let i = 0; i < 10; i++) {
                const lvlId = startId + i;
                const col = i % 2;
                const row = Math.floor(i / 2);
                const nodeX = col === 0 ? 240 : 480;
                const nodeY = 280 + row * 160;

                if (Math.hypot(x - nodeX, y - nodeY) <= 50) {
                    if (lvlId <= saveManager.data.unlocked_level) {
                        sound.playClick();
                        this.loadLevel(lvlId);
                    } else {
                        sound.playBounce();
                    }
                    return;
                }
            }
        }

        handleSettingsClick(x, y) {
            // Back button
            if (x >= 30 && x <= 120 && y >= 30 && y <= 90) {
                sound.playClick();
                this.currentScreen = 'MENU';
                return;
            }

            // Sound Toggle
            if (x >= 200 && x <= 520 && y >= 450 && y <= 530) {
                sound.enabled = !sound.enabled;
                saveManager.data.settings.sound_enabled = sound.enabled;
                saveManager.save();
                sound.playClick();
            }

            // Reset Progress
            if (x >= 200 && x <= 520 && y >= 580 && y <= 660) {
                if (confirm("Are you sure you want to reset all game progress?")) {
                    saveManager.resetProgress();
                    sound.playClick();
                }
            }
        }

        handleModalClick(x, y) {
            if (this.modalState === 'WIN') {
                // Next Level
                if (x >= 220 && x <= 500 && y >= 720 && y <= 800) {
                    sound.playClick();
                    if (this.currentLevelId < 30) this.loadLevel(this.currentLevelId + 1);
                    else this.currentScreen = 'WORLD_MAP';
                }
                // Map
                else if (x >= 220 && x <= 500 && y >= 820 && y <= 890) {
                    sound.playClick();
                    this.currentScreen = 'WORLD_MAP';
                }
            } else if (this.modalState === 'LOSE') {
                // Retry
                if (x >= 220 && x <= 500 && y >= 720 && y <= 800) {
                    sound.playClick();
                    this.loadLevel(this.currentLevelId);
                }
                // Map
                else if (x >= 220 && x <= 500 && y >= 820 && y <= 890) {
                    sound.playClick();
                    this.currentScreen = 'WORLD_MAP';
                }
            } else if (this.modalState === 'PAUSE') {
                // Resume
                if (x >= 220 && x <= 500 && y >= 540 && y <= 620) {
                    sound.playClick();
                    this.modalState = null;
                }
                // Restart
                else if (x >= 220 && x <= 500 && y >= 640 && y <= 720) {
                    sound.playClick();
                    this.loadLevel(this.currentLevelId);
                }
                // Map
                else if (x >= 220 && x <= 500 && y >= 740 && y <= 820) {
                    sound.playClick();
                    this.modalState = null;
                    this.currentScreen = 'WORLD_MAP';
                }
            }
        }

        // --- 9. RENDER PIPELINE ---
        drawBubble(x, y, color, special = SpecialType.NONE, locked = false) {
            const ctx = this.ctx;
            ctx.save();
            ctx.translate(x, y);

            // Shadow
            ctx.fillStyle = 'rgba(0,0,0,0.28)';
            ctx.beginPath();
            ctx.arc(2, 4, BUBBLE_RADIUS, 0, Math.PI * 2);
            ctx.fill();

            // Bubble Base Color
            const baseHex = COLOR_HEX[color] || '#aaaaaa';
            const grad = ctx.createRadialGradient(-10, -10, 4, 0, 0, BUBBLE_RADIUS);
            grad.addColorStop(0, '#ffffff');
            grad.addColorStop(0.3, baseHex);
            grad.addColorStop(1, '#000000');
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.arc(0, 0, BUBBLE_RADIUS, 0, Math.PI * 2);
            ctx.fill();

            // Inner Gloss Specular
            ctx.fillStyle = 'rgba(255,255,255,0.65)';
            ctx.beginPath();
            ctx.ellipse(-12, -14, 12, 6, -Math.PI / 4, 0, Math.PI * 2);
            ctx.fill();

            // Specials Overlays
            if (special === SpecialType.BOMB) {
                ctx.fillStyle = '#ff3300';
                ctx.font = 'bold 28px sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillText('💣', 0, 2);
            } else if (special === SpecialType.RAINBOW) {
                ctx.strokeStyle = '#ffffff';
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(0, 0, 18, 0, Math.PI * 2);
                ctx.stroke();
                ctx.fillStyle = '#ffd700';
                ctx.font = 'bold 24px sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillText('🌈', 0, 2);
            } else if (special === SpecialType.LIGHTNING) {
                ctx.fillStyle = '#ffff00';
                ctx.font = 'bold 28px sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillText('⚡', 0, 2);
            } else if (special === SpecialType.STONE) {
                ctx.fillStyle = '#555566';
                ctx.beginPath();
                ctx.arc(0, 0, BUBBLE_RADIUS - 2, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = '#333344';
                ctx.lineWidth = 4;
                ctx.stroke();
            }

            // Locked Ice Shell
            if (locked) {
                ctx.fillStyle = 'rgba(180, 240, 255, 0.45)';
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.8)';
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.rect(-BUBBLE_RADIUS + 4, -BUBBLE_RADIUS + 4, BUBBLE_DIAMETER - 8, BUBBLE_DIAMETER - 8);
                ctx.fill();
                ctx.stroke();
                // Ice crack line
                ctx.beginPath();
                ctx.moveTo(-16, -16);
                ctx.lineTo(0, 4);
                ctx.lineTo(16, -8);
                ctx.stroke();
            }

            ctx.restore();
        }

        drawBackground() {
            const ctx = this.ctx;
            const grad = ctx.createLinearGradient(0, 0, 0, V_HEIGHT);
            if (this.currentWorldId === 1) {
                grad.addColorStop(0, '#0c1b18');
                grad.addColorStop(0.6, '#14332a');
                grad.addColorStop(1, '#081714');
            } else if (this.currentWorldId === 2) {
                grad.addColorStop(0, '#100c24');
                grad.addColorStop(0.6, '#261a4d');
                grad.addColorStop(1, '#0b0818');
            } else {
                grad.addColorStop(0, '#0a1d28');
                grad.addColorStop(0.6, '#133e54');
                grad.addColorStop(1, '#07161f');
            }
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, V_WIDTH, V_HEIGHT);

            // Subtle background stars / fireflies
            ctx.fillStyle = 'rgba(255, 255, 200, 0.2)';
            for (let i = 0; i < 18; i++) {
                const sx = ((i * 137) % V_WIDTH);
                const sy = ((i * 223 + performance.now() * 0.02) % (V_HEIGHT - 200));
                ctx.beginPath();
                ctx.arc(sx, sy, (i % 3) + 1.5, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        drawGameplay() {
            const ctx = this.ctx;
            this.drawBackground();

            // Danger Row Line
            const dangerY = getGridPosition(DANGER_ROW, 0).y - BUBBLE_RADIUS;
            ctx.strokeStyle = 'rgba(255, 50, 50, 0.4)';
            ctx.setLineDash([12, 8]);
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.moveTo(0, dangerY);
            ctx.lineTo(V_WIDTH, dangerY);
            ctx.stroke();
            ctx.setLineDash([]);

            // Grid Bubbles
            for (let r = 0; r < MAX_ROWS; r++) {
                const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                for (let c = 0; c < cols; c++) {
                    const b = this.grid[r][c];
                    if (b) {
                        const pos = getGridPosition(r, c);
                        this.drawBubble(pos.x, pos.y, b.color, b.special, b.locked);
                    }
                }
            }

            // Dropping Bubbles
            for (const d of this.droppingBubbles) {
                this.drawBubble(d.x, d.y, d.color, d.special, false);
            }

            // Aim Guide Dots
            if (this.isAiming && this.aimPath.length > 1) {
                ctx.fillStyle = '#ffffff';
                for (let i = 0; i < this.aimPath.length - 1; i++) {
                    const p1 = this.aimPath[i];
                    const p2 = this.aimPath[i + 1];
                    const dist = Math.hypot(p2.x - p1.x, p2.y - p1.y);
                    const dots = Math.floor(dist / 28);
                    for (let d = 0; d < dots; d++) {
                        const t = d / dots;
                        const dx = p1.x + (p2.x - p1.x) * t;
                        const dy = p1.y + (p2.y - p1.y) * t;
                        ctx.beginPath();
                        ctx.arc(dx, dy, 4.5, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
            }

            // Projectile in flight
            if (this.projectile) {
                this.drawBubble(this.projectile.x, this.projectile.y, this.projectile.color, this.projectile.special);
            }

            // Shooter Area
            // Base pedestal
            ctx.fillStyle = '#1e303d';
            ctx.beginPath();
            ctx.ellipse(SHOOTER_X, SHOOTER_Y + 10, 80, 24, 0, 0, Math.PI * 2);
            ctx.fill();

            // Next bubble queue & Swap button
            ctx.fillStyle = '#17242e';
            ctx.beginPath();
            ctx.arc(SHOOTER_X + 110, SHOOTER_Y, 40, 0, Math.PI * 2);
            ctx.fill();
            if (this.nextBubble) {
                this.drawBubble(SHOOTER_X + 110, SHOOTER_Y, this.nextBubble.color, this.nextBubble.special);
            }
            ctx.fillStyle = '#ffd700';
            ctx.font = 'bold 20px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('⇄', SHOOTER_X + 110, SHOOTER_Y + 54);

            // Current Loaded Bubble
            if (this.currentBubble) {
                this.drawBubble(SHOOTER_X, SHOOTER_Y, this.currentBubble.color, this.currentBubble.special);
            }

            // Companion Lumi
            this.lumi.draw(ctx);

            // Particles
            this.particles.draw(ctx);

            // Top HUD
            this.drawHUD();

            // Modals (Win, Lose, Pause)
            if (this.modalState) {
                this.drawModal();
            }
        }

        drawHUD() {
            const ctx = this.ctx;
            ctx.fillStyle = 'rgba(10, 20, 28, 0.85)';
            ctx.fillRect(0, 0, V_WIDTH, 110);

            // Level Name & World
            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 26px sans-serif';
            ctx.textAlign = 'left';
            ctx.fillText(`Level ${this.currentLevelId}`, 30, 42);

            ctx.fillStyle = '#4ae3b5';
            ctx.font = '18px sans-serif';
            let objText = "Clear All Bubbles";
            if (this.objectiveType === ObjectiveType.CLEAR_COLOR) {
                objText = `Clear ${COLOR_NAMES[this.objectiveTargetColor]} (${this.objectiveCount}/${this.targetCount})`;
            } else if (this.objectiveType === ObjectiveType.REACH_SCORE) {
                objText = `Score: ${this.score}/${this.targetScore}`;
            } else if (this.objectiveType === ObjectiveType.CLEAR_SPECIAL) {
                objText = `Clear Specials (${this.objectiveCount}/${this.targetCount})`;
            }
            ctx.fillText(objText, 30, 78);

            // Shots Left (Center)
            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 36px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText(`${this.shotsLeft}`, V_WIDTH / 2, 54);
            ctx.font = '14px sans-serif';
            ctx.fillStyle = '#aaaaaa';
            ctx.fillText('SHOTS', V_WIDTH / 2, 78);

            // Score & Pause (Right)
            ctx.fillStyle = '#ffd700';
            ctx.font = 'bold 24px sans-serif';
            ctx.textAlign = 'right';
            ctx.fillText(`★ ${this.score}`, V_WIDTH - 100, 54);

            // Pause Button
            ctx.fillStyle = '#22384a';
            ctx.beginPath();
            ctx.roundRect(V_WIDTH - 80, 25, 55, 55, 12);
            ctx.fill();
            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 26px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('❚❚', V_WIDTH - 52, 62);
        }

        drawModal() {
            const ctx = this.ctx;
            ctx.fillStyle = 'rgba(0,0,0,0.75)';
            ctx.fillRect(0, 0, V_WIDTH, V_HEIGHT);

            ctx.save();
            ctx.translate(V_WIDTH / 2, V_HEIGHT / 2);

            // Modal Box
            ctx.fillStyle = '#142533';
            ctx.strokeStyle = '#4ae3b5';
            ctx.lineWidth = 4;
            ctx.beginPath();
            ctx.roundRect(-240, -220, 480, 440, 24);
            ctx.fill();
            ctx.stroke();

            if (this.modalState === 'WIN') {
                ctx.fillStyle = '#ffd700';
                ctx.font = 'bold 44px sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText('VICTORY!', 0, -130);

                // Stars
                const stars = this.score >= this.targetScore * 1.5 ? 3 : (this.score >= this.targetScore ? 2 : 1);
                ctx.font = '54px sans-serif';
                const starStr = (stars >= 1 ? '★' : '☆') + ' ' + (stars >= 2 ? '★' : '☆') + ' ' + (stars >= 3 ? '★' : '☆');
                ctx.fillText(starStr, 0, -50);

                ctx.fillStyle = '#ffffff';
                ctx.font = '28px sans-serif';
                ctx.fillText(`Final Score: ${this.score}`, 0, 20);

                // Next Level Button
                ctx.fillStyle = '#2bb88d';
                ctx.beginPath();
                ctx.roundRect(-140, 70, 280, 60, 16);
                ctx.fill();
                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 26px sans-serif';
                ctx.fillText('NEXT LEVEL', 0, 110);

                // Map Button
                ctx.fillStyle = '#324a5e';
                ctx.beginPath();
                ctx.roundRect(-140, 150, 280, 50, 14);
                ctx.fill();
                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 22px sans-serif';
                ctx.fillText('WORLD MAP', 0, 183);

            } else if (this.modalState === 'LOSE') {
                ctx.fillStyle = '#ff4466';
                ctx.font = 'bold 44px sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText('LEVEL FAILED', 0, -130);

                ctx.fillStyle = '#aaaaaa';
                ctx.font = '24px sans-serif';
                ctx.fillText(this.lossReason || 'Try again!', 0, -60);

                ctx.fillStyle = '#ffffff';
                ctx.font = '28px sans-serif';
                ctx.fillText(`Score: ${this.score}`, 0, 10);

                // Retry Button
                ctx.fillStyle = '#ff4466';
                ctx.beginPath();
                ctx.roundRect(-140, 70, 280, 60, 16);
                ctx.fill();
                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 26px sans-serif';
                ctx.fillText('TRY AGAIN', 0, 110);

                // Map Button
                ctx.fillStyle = '#324a5e';
                ctx.beginPath();
                ctx.roundRect(-140, 150, 280, 50, 14);
                ctx.fill();
                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 22px sans-serif';
                ctx.fillText('WORLD MAP', 0, 183);

            } else if (this.modalState === 'PAUSE') {
                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 40px sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText('PAUSED', 0, -120);

                // Resume
                ctx.fillStyle = '#2bb88d';
                ctx.beginPath();
                ctx.roundRect(-140, -40, 280, 55, 14);
                ctx.fill();
                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 24px sans-serif';
                ctx.fillText('RESUME', 0, -4);

                // Restart
                ctx.fillStyle = '#e67e22';
                ctx.beginPath();
                ctx.roundRect(-140, 35, 280, 55, 14);
                ctx.fill();
                ctx.fillStyle = '#ffffff';
                ctx.fillText('RESTART', 0, 71);

                // Map
                ctx.fillStyle = '#324a5e';
                ctx.beginPath();
                ctx.roundRect(-140, 110, 280, 55, 14);
                ctx.fill();
                ctx.fillStyle = '#ffffff';
                ctx.fillText('WORLD MAP', 0, 146);
            }

            ctx.restore();
        }

        drawMenu() {
            const ctx = this.ctx;
            this.drawBackground();

            // Game Logo / Title
            ctx.fillStyle = '#ffd700';
            ctx.font = 'bold 64px sans-serif';
            ctx.textAlign = 'center';
            ctx.shadowColor = 'rgba(0,0,0,0.8)';
            ctx.shadowBlur = 12;
            ctx.fillText('LUMI', V_WIDTH / 2, 280);

            ctx.fillStyle = '#4ae3b5';
            ctx.font = 'bold 32px sans-serif';
            ctx.fillText('BUBBLEWOOD CHRONICLE', V_WIDTH / 2, 335);
            ctx.shadowBlur = 0;

            // Big Lumi in center
            ctx.save();
            ctx.translate(V_WIDTH / 2, 480);
            ctx.scale(2.2, 2.2);
            this.lumi.draw(ctx);
            ctx.restore();

            // Menu Buttons
            // Play
            ctx.fillStyle = '#2bb88d';
            ctx.beginPath();
            ctx.roundRect(200, 640, 320, 85, 20);
            ctx.fill();
            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 34px sans-serif';
            ctx.fillText('PLAY GAME', V_WIDTH / 2, 695);

            // Tutorial
            ctx.fillStyle = '#264b63';
            ctx.beginPath();
            ctx.roundRect(200, 755, 320, 75, 18);
            ctx.fill();
            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 28px sans-serif';
            ctx.fillText('HOW TO PLAY', V_WIDTH / 2, 803);

            // Settings
            ctx.fillStyle = '#1c3445';
            ctx.beginPath();
            ctx.roundRect(200, 855, 320, 75, 18);
            ctx.fill();
            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 28px sans-serif';
            ctx.fillText('SETTINGS', V_WIDTH / 2, 903);

            // Version info
            ctx.fillStyle = '#667788';
            ctx.font = '16px sans-serif';
            ctx.fillText('v1.0.0 Production Release — 30 Levels', V_WIDTH / 2, 1200);
        }

        drawWorldMap() {
            const ctx = this.ctx;
            this.drawBackground();

            // Header & Back
            ctx.fillStyle = 'rgba(10, 20, 28, 0.85)';
            ctx.fillRect(0, 0, V_WIDTH, 110);

            ctx.fillStyle = '#324a5e';
            ctx.beginPath();
            ctx.roundRect(30, 28, 90, 54, 14);
            ctx.fill();
            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 24px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('◀ BACK', 75, 63);

            ctx.fillStyle = '#ffd700';
            ctx.font = 'bold 30px sans-serif';
            ctx.textAlign = 'right';
            ctx.fillText(`★ ${saveManager.getTotalStars()}`, V_WIDTH - 40, 63);

            // World Tabs
            const worlds = [
                { id: 1, name: 'Whispering Woods', req: 0 },
                { id: 2, name: 'Crystal Caverns', req: 10 },
                { id: 3, name: 'Sunken Grove', req: 25 }
            ];

            worlds.forEach((w, i) => {
                const tabX = 40 + i * 220;
                const isSelected = this.currentWorldId === w.id;
                const isLocked = saveManager.getTotalStars() < w.req;

                ctx.fillStyle = isSelected ? '#2bb88d' : (isLocked ? '#1a2630' : '#264b63');
                ctx.beginPath();
                ctx.roundRect(tabX, 120, 200, 60, 12);
                ctx.fill();

                ctx.fillStyle = isLocked ? '#778899' : '#ffffff';
                ctx.font = 'bold 18px sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText(w.name.split(' ')[0], tabX + 100, 146);
                ctx.font = '12px sans-serif';
                ctx.fillText(isLocked ? `🔒 ${w.req}★` : `World ${w.id}`, tabX + 100, 166);
            });

            // Level Nodes (10 nodes per world)
            const startId = (this.currentWorldId - 1) * 10 + 1;
            for (let i = 0; i < 10; i++) {
                const lvlId = startId + i;
                const col = i % 2;
                const row = Math.floor(i / 2);
                const nodeX = col === 0 ? 240 : 480;
                const nodeY = 280 + row * 160;

                const isUnlocked = lvlId <= saveManager.data.unlocked_level;
                const stars = saveManager.data.stars[lvlId] || 0;

                // Node circle
                ctx.fillStyle = isUnlocked ? '#2bb88d' : '#1f2e3d';
                ctx.beginPath();
                ctx.arc(nodeX, nodeY, 46, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = isUnlocked ? '#a6f7df' : '#334455';
                ctx.lineWidth = 4;
                ctx.stroke();

                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 28px sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillText(isUnlocked ? `${lvlId}` : '🔒', nodeX, nodeY);

                // Star badges below node
                if (isUnlocked) {
                    ctx.font = '16px sans-serif';
                    ctx.fillStyle = '#ffd700';
                    const starStr = (stars >= 1 ? '★' : '☆') + (stars >= 2 ? '★' : '☆') + (stars >= 3 ? '★' : '☆');
                    ctx.fillText(starStr, nodeX, nodeY + 60);
                }
            }
        }

        drawSettings() {
            const ctx = this.ctx;
            this.drawBackground();

            // Header & Back
            ctx.fillStyle = 'rgba(10, 20, 28, 0.85)';
            ctx.fillRect(0, 0, V_WIDTH, 110);

            ctx.fillStyle = '#324a5e';
            ctx.beginPath();
            ctx.roundRect(30, 28, 90, 54, 14);
            ctx.fill();
            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 24px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('◀ BACK', 75, 63);

            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 36px sans-serif';
            ctx.fillText('SETTINGS', V_WIDTH / 2, 65);

            // Sound Toggle Button
            ctx.fillStyle = sound.enabled ? '#2bb88d' : '#445566';
            ctx.beginPath();
            ctx.roundRect(200, 450, 320, 80, 18);
            ctx.fill();
            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 28px sans-serif';
            ctx.fillText(sound.enabled ? '🔊 SOUND: ON' : '🔇 SOUND: OFF', V_WIDTH / 2, 498);

            // Reset Progress Button
            ctx.fillStyle = '#ff4466';
            ctx.beginPath();
            ctx.roundRect(200, 580, 320, 80, 18);
            ctx.fill();
            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 24px sans-serif';
            ctx.fillText('RESET PROGRESS', V_WIDTH / 2, 628);
        }

        drawTutorial() {
            const ctx = this.ctx;
            this.drawBackground();

            ctx.fillStyle = '#ffd700';
            ctx.font = 'bold 44px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('HOW TO PLAY', V_WIDTH / 2, 220);

            const tips = [
                "1. Drag or aim to target bubbles.",
                "2. Match 3 or more same colors to POP!",
                "3. Free floating bubbles to earn DROP bonus.",
                "4. Watch out for Bomb, Lightning & Rainbows!",
                "5. Don't let bubbles cross the danger line!"
            ];

            ctx.fillStyle = '#ffffff';
            ctx.font = '24px sans-serif';
            tips.forEach((t, i) => {
                ctx.fillText(t, V_WIDTH / 2, 360 + i * 80);
            });

            // Tap to continue
            ctx.fillStyle = '#4ae3b5';
            ctx.font = 'bold 30px sans-serif';
            ctx.fillText('TAP ANYWHERE TO PLAY', V_WIDTH / 2, 900);
        }

        loop(time) {
            const dt = Math.min((time - this.lastTime) / 1000, 0.1);
            this.lastTime = time;

            // Update
            this.lumi.update(dt);
            this.particles.update(dt);
            this.updateDroppingBubbles(dt);
            if (this.currentScreen === 'GAMEPLAY' && !this.modalState) {
                this.updateProjectile(dt);
            }

            // Draw
            this.ctx.clearRect(0, 0, V_WIDTH, V_HEIGHT);
            if (this.currentScreen === 'MENU') {
                this.drawMenu();
            } else if (this.currentScreen === 'WORLD_MAP') {
                this.drawWorldMap();
            } else if (this.currentScreen === 'SETTINGS') {
                this.drawSettings();
            } else if (this.currentScreen === 'TUTORIAL') {
                this.drawTutorial();
            } else if (this.currentScreen === 'GAMEPLAY') {
                this.drawGameplay();
            }

            requestAnimationFrame(this.loop);
        }
    }

    window.addEventListener('DOMContentLoaded', () => {
        window.game = new BubbleShooterGame();
    });
})();
