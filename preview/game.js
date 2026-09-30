/**
 * LUMI: BUBBLEWOOD CHRONICLE — PREMIUM PRODUCTION ENGINE
 * Complete Visual Design Sheet Compliance: Glassmorphism + Glossy 3D-Look Bubbles + Lumi Character
 */

(() => {
    'use strict';

    // =========================================================================
    // 1. VISUAL DESIGN SYSTEM CONSTANTS & COLOR PHILOSOPHY (Section 3, 15, 41)
    // =========================================================================
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
    const PROJECTILE_SPEED = 1850; // px/sec

    // Enums
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

    // Palette Colors matching Section 3 & 15
    const PALETTE = {
        GLASS_WHITE: '#FFFFFF',
        CRYSTAL_BLUE: '#69D9FF',
        SKY_BLUE: '#55BFFF',
        AQUA: '#48E5D4',
        MINT: '#76E8C7',
        LAVENDER: '#A98BFF',
        PINK: '#FF7BC8',
        CORAL: '#FF7E8B',
        SUNSHINE: '#FFD75A',
        DEEP_PURPLE: '#392C66',
        DEEP_NAVY: '#171A3A',
        BG_BLUE: '#20265C'
    };

    // 8-Layer Bubble Glass Color Palettes [base, light, deep, glow, rim]
    const BUBBLE_THEMES = {
        [BubbleColor.RED]: {
            base: '#ff4d6a',
            light: '#ffa8b8',
            deep: '#8f0e24',
            glow: 'rgba(255, 77, 106, 0.40)',
            rim: 'rgba(255, 210, 220, 0.70)',
            name: 'Red'
        },
        [BubbleColor.BLUE]: {
            base: '#3ba3ff',
            light: '#a6d8ff',
            deep: '#0d3b8f',
            glow: 'rgba(59, 163, 255, 0.40)',
            rim: 'rgba(210, 235, 255, 0.70)',
            name: 'Blue'
        },
        [BubbleColor.GREEN]: {
            base: '#38e085',
            light: '#a8fcd0',
            deep: '#086e38',
            glow: 'rgba(56, 224, 133, 0.40)',
            rim: 'rgba(210, 255, 230, 0.70)',
            name: 'Green'
        },
        [BubbleColor.YELLOW]: {
            base: '#ffd438',
            light: '#fff2a8',
            deep: '#9c6f05',
            glow: 'rgba(255, 212, 56, 0.40)',
            rim: 'rgba(255, 250, 210, 0.70)',
            name: 'Yellow'
        },
        [BubbleColor.PURPLE]: {
            base: '#b866ff',
            light: '#e4b8ff',
            deep: '#54158c',
            glow: 'rgba(184, 102, 255, 0.40)',
            rim: 'rgba(240, 220, 255, 0.70)',
            name: 'Purple'
        },
        [BubbleColor.CYAN]: {
            base: '#2de2e6',
            light: '#aef9fb',
            deep: '#0a646e',
            glow: 'rgba(45, 226, 230, 0.40)',
            rim: 'rgba(220, 255, 255, 0.70)',
            name: 'Cyan'
        }
    };

    const WORLD_DATA = [
        {
            id: 1,
            name: 'Whispering Woods',
            desc: 'Crystal Garden & Ancient Trees',
            bgTop: '#0d1a2d',
            bgMid: '#16383b',
            bgBottom: '#0a1322',
            accent: PALETTE.AQUA,
            glow: 'rgba(72, 229, 212, 0.30)',
            starReq: 0
        },
        {
            id: 2,
            name: 'Crystal Caverns',
            desc: 'Deep Amethyst Grotto & Shimmering Veins',
            bgTop: '#251642',
            bgMid: '#3c2269',
            bgBottom: '#120c24',
            accent: PALETTE.LAVENDER,
            glow: 'rgba(169, 139, 255, 0.30)',
            starReq: 18
        },
        {
            id: 3,
            name: 'Sunken Grove',
            desc: 'Abyssal Ocean Glass & Luminescent Reefs',
            bgTop: '#082035',
            bgMid: '#12485e',
            bgBottom: '#04101e',
            accent: PALETTE.CRYSTAL_BLUE,
            glow: 'rgba(105, 217, 255, 0.30)',
            starReq: 45
        }
    ];

    // =========================================================================
    // 2. AUDIO SYNTHESIZER (Web Audio API)
    // =========================================================================
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
            osc.frequency.setValueAtTime(520, now);
            osc.frequency.exponentialRampToValueAtTime(200, now + 0.09);
            gain.gain.setValueAtTime(0.28 * this.sfxVolume, now);
            gain.gain.linearRampToValueAtTime(0.01, now + 0.09);
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            osc.start(now);
            osc.stop(now + 0.09);
        }

        playBounce() {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(680, now);
            gain.gain.setValueAtTime(0.22 * this.sfxVolume, now);
            gain.gain.linearRampToValueAtTime(0.01, now + 0.06);
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            osc.start(now);
            osc.stop(now + 0.06);
        }

        playMatch(combo = 1) {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
            const baseFreq = notes[Math.min(combo - 1, notes.length - 1)];

            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(baseFreq, now);
            osc.frequency.exponentialRampToValueAtTime(baseFreq * 1.5, now + 0.16);
            gain.gain.setValueAtTime(0.35 * this.sfxVolume, now);
            gain.gain.linearRampToValueAtTime(0.01, now + 0.16);
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            osc.start(now);
            osc.stop(now + 0.16);
        }

        playBomb() {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(140, now);
            osc.frequency.exponentialRampToValueAtTime(35, now + 0.35);
            gain.gain.setValueAtTime(0.45 * this.sfxVolume, now);
            gain.gain.linearRampToValueAtTime(0.01, now + 0.35);
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            osc.start(now);
            osc.stop(now + 0.35);
        }

        playLightning() {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(920, now);
            osc.frequency.linearRampToValueAtTime(240, now + 0.22);
            gain.gain.setValueAtTime(0.35 * this.sfxVolume, now);
            gain.gain.linearRampToValueAtTime(0.01, now + 0.22);
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            osc.start(now);
            osc.stop(now + 0.22);
        }

        playVictory() {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const notes = [523.25, 659.25, 783.99, 1046.50, 1318.51];
            notes.forEach((freq, i) => {
                const osc = this.ctx.createOscillator();
                const gain = this.ctx.createGain();
                osc.type = 'sine';
                osc.frequency.setValueAtTime(freq, now + i * 0.1);
                gain.gain.setValueAtTime(0.25 * this.sfxVolume, now + i * 0.1);
                gain.gain.linearRampToValueAtTime(0.01, now + i * 0.1 + 0.25);
                osc.connect(gain);
                gain.connect(this.ctx.destination);
                osc.start(now + i * 0.1);
                osc.stop(now + i * 0.1 + 0.25);
            });
        }

        playDefeat() {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const notes = [440, 392, 349.23, 293.66];
            notes.forEach((freq, i) => {
                const osc = this.ctx.createOscillator();
                const gain = this.ctx.createGain();
                osc.type = 'triangle';
                osc.frequency.setValueAtTime(freq, now + i * 0.14);
                gain.gain.setValueAtTime(0.25 * this.sfxVolume, now + i * 0.14);
                gain.gain.linearRampToValueAtTime(0.01, now + i * 0.14 + 0.22);
                osc.connect(gain);
                gain.connect(this.ctx.destination);
                osc.start(now + i * 0.14);
                osc.stop(now + i * 0.14 + 0.22);
            });
        }

        playClick() {
            if (!this.enabled || !this.ctx) return;
            const now = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(800, now);
            osc.frequency.exponentialRampToValueAtTime(400, now + 0.04);
            gain.gain.setValueAtTime(0.18 * this.sfxVolume, now);
            gain.gain.linearRampToValueAtTime(0.01, now + 0.04);
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            osc.start(now);
            osc.stop(now + 0.04);
        }
    }

    const sound = new SoundEngine();

    // =========================================================================
    // 3. PARTICLE & VISUAL EFFECTS SYSTEM (Section 39, 22, 25, 26)
    // =========================================================================
    class ParticleSystem {
        constructor() {
            this.particles = [];
            this.scorePopups = [];
            this.comboPopups = [];
        }

        spawnGlassShards(x, y, colorHex, count = 16) {
            for (let i = 0; i < count; i++) {
                const angle = (Math.PI * 2 * i) / count + (Math.random() - 0.5) * 0.4;
                const speed = 160 + Math.random() * 240;
                this.particles.push({
                    x, y,
                    vx: Math.cos(angle) * speed,
                    vy: Math.sin(angle) * speed - 60,
                    size: 3 + Math.random() * 4.5,
                    color: colorHex,
                    alpha: 1.0,
                    life: 0.35 + Math.random() * 0.25,
                    maxLife: 0.55,
                    rot: Math.random() * Math.PI,
                    rotSpeed: (Math.random() - 0.5) * 12,
                    isShard: true
                });
            }
            // Add central specular sparkle
            for (let i = 0; i < 6; i++) {
                const angle = Math.random() * Math.PI * 2;
                const speed = 80 + Math.random() * 120;
                this.particles.push({
                    x, y,
                    vx: Math.cos(angle) * speed,
                    vy: Math.sin(angle) * speed,
                    size: 2 + Math.random() * 3,
                    color: '#ffffff',
                    alpha: 1.0,
                    life: 0.25 + Math.random() * 0.15,
                    maxLife: 0.4,
                    rot: 0,
                    rotSpeed: 0,
                    isShard: false
                });
            }
        }

        spawnSpark(x, y, color = '#ffffff') {
            for (let i = 0; i < 8; i++) {
                const angle = Math.random() * Math.PI * 2;
                const speed = 60 + Math.random() * 120;
                this.particles.push({
                    x, y,
                    vx: Math.cos(angle) * speed,
                    vy: Math.sin(angle) * speed,
                    size: 2.5,
                    color,
                    alpha: 1.0,
                    life: 0.2,
                    maxLife: 0.2,
                    rot: 0,
                    rotSpeed: 0,
                    isShard: false
                });
            }
        }

        spawnScore(x, y, text, color = PALETTE.SUNSHINE) {
            this.scorePopups.push({
                x, y,
                text,
                color,
                alpha: 1.0,
                vy: -75,
                scale: 0.5,
                life: 0.65
            });
        }

        spawnCombo(x, y, comboCount) {
            this.comboPopups.push({
                x, y: y - 30,
                text: `COMBO ×${comboCount}!`,
                alpha: 1.0,
                scale: 0.6,
                targetScale: 1.15,
                vy: -50,
                life: 0.85
            });
        }

        update(dt) {
            for (let i = this.particles.length - 1; i >= 0; i--) {
                const p = this.particles[i];
                p.x += p.vx * dt;
                p.y += p.vy * dt;
                p.vy += 450 * dt; // Gravity
                p.rot += p.rotSpeed * dt;
                p.life -= dt;
                p.alpha = Math.max(0, p.life / p.maxLife);
                if (p.life <= 0) this.particles.splice(i, 1);
            }

            for (let i = this.scorePopups.length - 1; i >= 0; i--) {
                const s = this.scorePopups[i];
                s.y += s.vy * dt;
                s.life -= dt;
                s.scale = Math.min(1.0, s.scale + dt * 4.0);
                s.alpha = Math.max(0, s.life / 0.65);
                if (s.life <= 0) this.scorePopups.splice(i, 1);
            }

            for (let i = this.comboPopups.length - 1; i >= 0; i--) {
                const c = this.comboPopups[i];
                c.y += c.vy * dt;
                c.life -= dt;
                if (c.scale < c.targetScale) c.scale += dt * 3.5;
                c.alpha = Math.max(0, c.life / 0.85);
                if (c.life <= 0) this.comboPopups.splice(i, 1);
            }
        }

        draw(ctx) {
            // Draw particles
            for (const p of this.particles) {
                ctx.save();
                ctx.translate(p.x, p.y);
                ctx.globalAlpha = p.alpha;
                ctx.fillStyle = p.color;
                if (p.isShard) {
                    ctx.rotate(p.rot);
                    ctx.beginPath();
                    ctx.moveTo(-p.size, -p.size);
                    ctx.lineTo(p.size * 1.2, -p.size * 0.4);
                    ctx.lineTo(p.size * 0.4, p.size);
                    ctx.closePath();
                    ctx.fill();
                } else {
                    ctx.beginPath();
                    ctx.arc(0, 0, p.size, 0, Math.PI * 2);
                    ctx.fill();
                }
                ctx.restore();
            }

            // Draw Score Popups (Section 26: White glass text + soft colored glow)
            for (const s of this.scorePopups) {
                ctx.save();
                ctx.translate(s.x, s.y);
                ctx.scale(s.scale, s.scale);
                ctx.globalAlpha = s.alpha;
                ctx.font = 'bold 28px "Segoe UI", Roboto, sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                // Glow
                ctx.shadowColor = s.color;
                ctx.shadowBlur = 10;
                ctx.fillStyle = '#ffffff';
                ctx.fillText(s.text, 0, 0);
                ctx.restore();
            }

            // Draw Combo Popups (Section 25: Glass Capsule + Rainbow Gradient)
            for (const c of this.comboPopups) {
                ctx.save();
                ctx.translate(c.x, c.y);
                ctx.scale(c.scale, c.scale);
                ctx.globalAlpha = c.alpha;

                // Glass Capsule
                const capW = 200;
                const capH = 46;
                const capR = 23;
                ctx.shadowColor = PALETTE.AQUA;
                ctx.shadowBlur = 14;

                ctx.fillStyle = 'rgba(16, 28, 55, 0.75)';
                ctx.beginPath();
                ctx.roundRect(-capW / 2, -capH / 2, capW, capH, capR);
                ctx.fill();

                ctx.strokeStyle = PALETTE.AQUA;
                ctx.lineWidth = 2;
                ctx.stroke();

                // Top highlight line
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.85)';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.roundRect(-capW / 2 + 10, -capH / 2 + 3, capW - 20, 2, 1);
                ctx.stroke();

                // Text
                ctx.shadowBlur = 0;
                ctx.font = 'bold 22px "Segoe UI", Roboto, sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillStyle = '#ffffff';
                ctx.fillText(c.text, 0, 2);

                ctx.restore();
            }
        }
    }

    // =========================================================================
    // 4. SAVE SYSTEM V3 (Section 6, 7, 34)
    // =========================================================================
    class SaveSystem {
        constructor() {
            this.storageKey = 'lumi_save_v3';
            this.data = this.load();
        }

        load() {
            const defaultData = {
                version: 3,
                highScores: {},
                starRatings: {},
                unlockedWorld: 1,
                unlockedLevel: 1,
                totalStars: 0,
                soundEnabled: true,
                musicEnabled: true,
                accessibilityGlyphs: false
            };

            try {
                const raw = localStorage.getItem(this.storageKey);
                if (!raw) return defaultData;
                const parsed = JSON.parse(raw);
                return { ...defaultData, ...parsed };
            } catch (e) {
                console.warn('Save corrupted or unavailable, resetting to defaults.', e);
                return defaultData;
            }
        }

        save() {
            try {
                localStorage.setItem(this.storageKey, JSON.stringify(this.data));
            } catch (e) {
                console.error('LocalStorage write failed:', e);
            }
        }

        saveLevelResult(levelId, score, stars) {
            const prevScore = this.data.highScores[levelId] || 0;
            const prevStars = this.data.starRatings[levelId] || 0;

            if (score > prevScore) this.data.highScores[levelId] = score;
            if (stars > prevStars) this.data.starRatings[levelId] = stars;

            // Recalculate total stars
            let total = 0;
            for (const lvl in this.data.starRatings) {
                total += this.data.starRatings[lvl] || 0;
            }
            this.data.totalStars = total;

            // Unlock next level & world
            if (levelId >= this.data.unlockedLevel && stars > 0) {
                this.data.unlockedLevel = Math.min(30, levelId + 1);
            }

            if (this.data.totalStars >= 45) {
                this.data.unlockedWorld = Math.max(this.data.unlockedWorld, 3);
            } else if (this.data.totalStars >= 18) {
                this.data.unlockedWorld = Math.max(this.data.unlockedWorld, 2);
            }

            this.save();
        }
    }

    const saveSystem = new SaveSystem();

    // =========================================================================
    // 5. HEX GRID & GEOMETRY UTILITIES
    // =========================================================================
    function getGridPosition(r, c) {
        const isOdd = r % 2 !== 0;
        const xOffset = isOdd ? BUBBLE_RADIUS * 2 : BUBBLE_RADIUS;
        const x = 72 + xOffset + c * BUBBLE_DIAMETER;
        const y = 160 + BUBBLE_RADIUS + r * ROW_HEIGHT;
        return { x, y };
    }

    function getNeighbors(r, c) {
        const isOdd = r % 2 !== 0;
        const offsets = isOdd
            ? [
                { r: -1, c: 0 }, { r: -1, c: 1 },
                { r: 0, c: -1 }, { r: 0, c: 1 },
                { r: 1, c: 0 }, { r: 1, c: 1 }
            ]
            : [
                { r: -1, c: -1 }, { r: -1, c: 0 },
                { r: 0, c: -1 }, { r: 0, c: 1 },
                { r: 1, c: -1 }, { r: 1, c: 0 }
            ];

        const neighbors = [];
        for (const off of offsets) {
            const nr = r + off.r;
            const nc = c + off.c;
            if (nr >= 0 && nr < MAX_ROWS) {
                const cols = nr % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                if (nc >= 0 && nc < cols) {
                    neighbors.push({ r: nr, c: nc });
                }
            }
        }
        return neighbors;
    }

    // =========================================================================
    // 6. COMPANION LUMI (Section 36, 37, 38)
    // =========================================================================
    class CompanionLumi {
        constructor() {
            this.x = 590;
            this.y = 1170;
            this.state = 'IDLE'; // IDLE, AIM, CHEER, WIN, LOSE
            this.time = 0;
            this.aimAngle = -Math.PI / 2;
            this.earWiggle = 0;
            this.tailAngle = 0;
            this.blink = 1.0;
            this.bounceY = 0;
        }

        update(dt) {
            this.time += dt;

            switch (this.state) {
                case 'IDLE':
                    this.bounceY = Math.sin(this.time * 2.8) * 3.5;
                    this.tailAngle = Math.sin(this.time * 3.2) * 0.25;
                    this.earWiggle = Math.sin(this.time * 1.6) * 0.08;
                    const blinkPhase = this.time % 4.0;
                    this.blink = (blinkPhase > 3.8 && blinkPhase < 3.95) ? 0.1 : 1.0;
                    break;
                case 'AIM':
                    this.bounceY = Math.sin(this.time * 4.5) * 1.5;
                    this.tailAngle = Math.sin(this.time * 5.0) * 0.15;
                    this.earWiggle = 0.18;
                    this.blink = 1.0;
                    break;
                case 'CHEER':
                    this.bounceY = -Math.abs(Math.sin(this.time * 9.0)) * 16.0;
                    this.tailAngle = Math.sin(this.time * 12.0) * 0.45;
                    this.earWiggle = Math.sin(this.time * 10.0) * 0.25;
                    this.blink = 1.0;
                    if (this.time > 1.2) this.state = 'IDLE';
                    break;
                case 'WIN':
                    this.bounceY = -Math.abs(Math.sin(this.time * 7.0)) * 20.0;
                    this.tailAngle = Math.sin(this.time * 10.0) * 0.5;
                    this.earWiggle = 0.22;
                    this.blink = 1.0;
                    break;
                case 'LOSE':
                    this.bounceY = 4.0;
                    this.earWiggle = -0.35;
                    this.tailAngle = 0.05;
                    this.blink = 0.6;
                    break;
            }
        }

        draw(ctx) {
            ctx.save();
            ctx.translate(this.x, this.y + this.bounceY);

            const baseFur = '#fa9539';
            const shadeFur = '#d16617';
            const creamFur = '#fff6e5';
            const darkFur = '#382014';
            const crystalGem = PALETTE.AQUA;

            // Ground shadow
            ctx.fillStyle = 'rgba(0,0,0,0.22)';
            ctx.beginPath();
            ctx.ellipse(0, 36, 24, 8, 0, 0, Math.PI * 2);
            ctx.fill();

            // 1. Bushy Fluffy Tail with White Tip
            ctx.save();
            ctx.translate(24, 12);
            ctx.rotate(this.tailAngle);
            ctx.fillStyle = shadeFur;
            ctx.beginPath();
            ctx.arc(28, -18, 18, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = baseFur;
            ctx.beginPath();
            ctx.arc(26, -20, 17, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = creamFur;
            ctx.beginPath();
            ctx.arc(38, -30, 11, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();

            // 2. Main Body & Cream Belly
            ctx.fillStyle = shadeFur;
            ctx.beginPath();
            ctx.arc(2, 12, 26, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = baseFur;
            ctx.beginPath();
            ctx.arc(0, 10, 26, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = creamFur;
            ctx.beginPath();
            ctx.arc(-4, 12, 16, 0, Math.PI * 2);
            ctx.fill();

            // 3. Head & Cheeks
            const headY = -16;
            ctx.fillStyle = shadeFur;
            ctx.beginPath();
            ctx.arc(1, headY + 1, 22, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = baseFur;
            ctx.beginPath();
            ctx.arc(0, headY, 22, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = creamFur;
            ctx.beginPath();
            ctx.arc(-12, headY + 6, 11, 0, Math.PI * 2);
            ctx.arc(12, headY + 6, 11, 0, Math.PI * 2);
            ctx.fill();

            // 4. Large Expressive Ears
            // Left Ear
            ctx.save();
            ctx.translate(-14, headY - 14);
            ctx.rotate(-this.earWiggle);
            ctx.fillStyle = baseFur;
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(-8, -26);
            ctx.lineTo(8, -18);
            ctx.closePath();
            ctx.fill();
            ctx.fillStyle = '#ff9ebb';
            ctx.beginPath();
            ctx.arc(-3, -15, 5, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();

            // Right Ear
            ctx.save();
            ctx.translate(14, headY - 14);
            ctx.rotate(this.earWiggle);
            ctx.fillStyle = baseFur;
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(8, -26);
            ctx.lineTo(-8, -18);
            ctx.closePath();
            ctx.fill();
            ctx.fillStyle = '#ff9ebb';
            ctx.beginPath();
            ctx.arc(3, -15, 5, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();

            // 5. Glossy Eyes with Upper-Left Specular Reflections (Section 36, 41)
            let lookX = 0;
            let lookY = 0;
            if (this.state === 'AIM') {
                lookX = Math.cos(this.aimAngle) * 4.0;
                lookY = Math.sin(this.aimAngle) * 4.0;
            }

            const leftEyeX = -8 + lookX;
            const rightEyeX = 8 + lookX;
            const eyeY = headY - 2 + lookY;

            if (this.blink > 0.3) {
                // Eye Spheres
                ctx.fillStyle = darkFur;
                ctx.beginPath();
                ctx.arc(leftEyeX, eyeY, 5.5 * this.blink, 0, Math.PI * 2);
                ctx.arc(rightEyeX, eyeY, 5.5 * this.blink, 0, Math.PI * 2);
                ctx.fill();

                // Upper-Left Primary Specular Highlights
                ctx.fillStyle = 'rgba(255, 255, 255, 0.95)';
                ctx.beginPath();
                ctx.arc(leftEyeX - 2.0, eyeY - 2.0, 2.2 * this.blink, 0, Math.PI * 2);
                ctx.arc(rightEyeX - 2.0, eyeY - 2.0, 2.2 * this.blink, 0, Math.PI * 2);
                ctx.fill();

                // Secondary bottom glint
                ctx.fillStyle = 'rgba(255, 255, 255, 0.70)';
                ctx.beginPath();
                ctx.arc(leftEyeX + 1.5, eyeY + 1.5, 1.0 * this.blink, 0, Math.PI * 2);
                ctx.arc(rightEyeX + 1.5, eyeY + 1.5, 1.0 * this.blink, 0, Math.PI * 2);
                ctx.fill();
            } else {
                ctx.strokeStyle = darkFur;
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(leftEyeX, eyeY, 4, Math.PI, Math.PI * 2);
                ctx.arc(rightEyeX, eyeY, 4, Math.PI, Math.PI * 2);
                ctx.stroke();
            }

            // 6. Cute Nose & Mouth
            ctx.fillStyle = darkFur;
            ctx.beginPath();
            ctx.arc(0, headY + 4, 2.5, 0, Math.PI * 2);
            ctx.fill();

            if (this.state === 'WIN' || this.state === 'CHEER') {
                ctx.strokeStyle = darkFur;
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(0, headY + 6, 4.5, 0, Math.PI);
                ctx.stroke();
            } else {
                ctx.strokeStyle = darkFur;
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.arc(-3, headY + 7, 2.5, 0, Math.PI);
                ctx.arc(3, headY + 7, 2.5, 0, Math.PI);
                ctx.stroke();
            }

            // 7. Radiant Crystal Heart Pendant
            const glowPulse = Math.sin(this.time * 4.0) * 0.25 + 0.75;
            ctx.shadowColor = crystalGem;
            ctx.shadowBlur = 8 * glowPulse;
            ctx.fillStyle = crystalGem;
            ctx.beginPath();
            ctx.arc(0, 14, 5.0, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = '#ffffff';
            ctx.beginPath();
            ctx.arc(-1.5, 12.5, 1.8, 0, Math.PI * 2);
            ctx.fill();
            ctx.shadowBlur = 0;

            ctx.restore();
        }
    }

    // =========================================================================
    // 7. GAME ENGINE & CONTROLLER
    // =========================================================================
    class GameEngine {
        constructor() {
            this.canvas = document.getElementById('gameCanvas');
            this.ctx = this.canvas.getContext('2d');

            this.state = 'SPLASH'; // SPLASH, MENU, MAP, GAMEPLAY, PAUSE, WIN, LOSE, SETTINGS, TUTORIAL
            this.currentWorldId = 1;
            this.currentLevelId = 1;

            this.grid = [];
            this.score = 0;
            this.shotsLeft = 20;
            this.targetScore = 300;
            this.objective = { type: ObjectiveType.CLEAR_ALL, target: 0, current: 0 };

            this.currentBubble = null;
            this.nextBubble = null;
            this.projectile = null;
            this.droppingBubbles = [];
            this.combo = 1;

            this.aimAngle = -Math.PI / 2;
            this.isAiming = false;
            this.canShoot = true;

            this.particles = new ParticleSystem();
            this.lumi = new CompanionLumi();

            this.lastTime = performance.now();
            this.totalTime = 0;

            this.initGrid();
            this.setupInput();
            this.bindEvents();

            requestAnimationFrame(this.loop.bind(this));
        }

        initGrid() {
            this.grid = [];
            for (let r = 0; r < MAX_ROWS; r++) {
                const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                const row = [];
                for (let c = 0; c < cols; c++) {
                    row.push(null);
                }
                this.grid.push(row);
            }
        }

        loadLevel(levelId) {
            this.currentLevelId = levelId;
            this.currentWorldId = Math.ceil(levelId / 10);
            this.score = 0;
            this.combo = 1;
            this.droppingBubbles = [];
            this.projectile = null;
            this.canShoot = true;
            this.lumi.state = 'IDLE';

            const levelData = (window.LEVELS_BUNDLE && window.LEVELS_BUNDLE[levelId]) || this.getFallbackLevel(levelId);

            this.shotsLeft = levelData.shots_limit || 24;
            this.targetScore = levelData.target_score || 350;
            this.objective = {
                type: levelData.objective_type || ObjectiveType.CLEAR_ALL,
                target: levelData.objective_target || 0,
                current: 0,
                color: levelData.target_color || BubbleColor.RED
            };

            this.initGrid();

            // Populate grid layout
            const rows = levelData.grid_layout || [];
            for (let r = 0; r < rows.length; r++) {
                const rowStr = rows[r];
                for (let c = 0; c < rowStr.length; c++) {
                    const char = rowStr[c];
                    if (char !== '.' && char !== ' ') {
                        let col = BubbleColor.RED;
                        let spec = SpecialType.NONE;

                        switch (char) {
                            case 'R': col = BubbleColor.RED; break;
                            case 'B': col = BubbleColor.BLUE; break;
                            case 'G': col = BubbleColor.GREEN; break;
                            case 'Y': col = BubbleColor.YELLOW; break;
                            case 'P': col = BubbleColor.PURPLE; break;
                            case 'C': col = BubbleColor.CYAN; break;
                            case 'X': spec = SpecialType.BOMB; col = BubbleColor.RED; break;
                            case 'W': spec = SpecialType.RAINBOW; col = BubbleColor.BLUE; break;
                            case 'L': spec = SpecialType.LIGHTNING; col = BubbleColor.YELLOW; break;
                            case 'S': spec = SpecialType.STONE; col = BubbleColor.NONE; break;
                            case 'I': spec = SpecialType.LOCKED; col = BubbleColor.CYAN; break;
                        }

                        this.grid[r][c] = {
                            color: col,
                            special: spec,
                            locked: spec === SpecialType.LOCKED
                        };
                    }
                }
            }

            this.generateShooterBubbles();
            this.state = 'GAMEPLAY';
        }

        getFallbackLevel(id) {
            return {
                shots_limit: 22,
                target_score: 400,
                objective_type: ObjectiveType.CLEAR_ALL,
                grid_layout: [
                    'RRBBGGYY',
                    'PPCCRR',
                    'BBRRGGBB',
                    'YYPPCC'
                ]
            };
        }

        generateShooterBubbles() {
            const activeColors = this.getActiveGridColors();
            const pickColor = () => activeColors.length > 0
                ? activeColors[Math.floor(Math.random() * activeColors.length)]
                : (Math.floor(Math.random() * 6) + 1);

            if (!this.currentBubble) {
                this.currentBubble = { color: pickColor(), special: SpecialType.NONE };
            }
            this.nextBubble = { color: pickColor(), special: SpecialType.NONE };
        }

        getActiveGridColors() {
            const set = new Set();
            for (let r = 0; r < MAX_ROWS; r++) {
                const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                for (let c = 0; c < cols; c++) {
                    const b = this.grid[r][c];
                    if (b && b.color !== BubbleColor.NONE) {
                        set.add(b.color);
                    }
                }
            }
            return Array.from(set);
        }

        swapBubbles() {
            if (!this.canShoot || !this.currentBubble || !this.nextBubble) return;
            sound.playClick();
            const temp = this.currentBubble;
            this.currentBubble = this.nextBubble;
            this.nextBubble = temp;
        }

        fireBubble() {
            if (!this.canShoot || !this.currentBubble || this.shotsLeft <= 0) return;

            sound.playShoot();
            this.canShoot = false;
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

            this.currentBubble = this.nextBubble;
            this.generateShooterBubbles();
        }

        updateProjectile(dt) {
            if (!this.projectile) return;

            const p = this.projectile;
            p.x += p.vx * dt;
            p.y += p.vy * dt;

            // Wall bounces with spark
            if (p.x <= 72 + BUBBLE_RADIUS) {
                p.x = 72 + BUBBLE_RADIUS;
                p.vx = Math.abs(p.vx);
                sound.playBounce();
                this.particles.spawnSpark(p.x, p.y, PALETTE.AQUA);
            } else if (p.x >= 648 - BUBBLE_RADIUS) {
                p.x = 648 - BUBBLE_RADIUS;
                p.vx = -Math.abs(p.vx);
                sound.playBounce();
                this.particles.spawnSpark(p.x, p.y, PALETTE.AQUA);
            }

            // Ceiling snap
            if (p.y <= 160 + BUBBLE_RADIUS) {
                this.snapProjectileToGrid(p);
                return;
            }

            // Grid collisions
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
                bestCell = { r: 0, c: Math.min(Math.floor((p.x - 72) / BUBBLE_DIAMETER), 7) };
            }

            this.grid[bestCell.r][bestCell.c] = {
                color: p.color,
                special: p.special,
                locked: false
            };

            const snapPos = getGridPosition(bestCell.r, bestCell.c);
            this.particles.spawnSpark(snapPos.x, snapPos.y, '#ffffff');

            this.projectile = null;
            this.processGridAfterShot(bestCell.r, bestCell.c, p);
        }

        processGridAfterShot(r, c, p) {
            let poppedAny = false;

            if (p.special === SpecialType.BOMB) {
                this.executeBomb(r, c);
                poppedAny = true;
            } else if (p.special === SpecialType.LIGHTNING) {
                this.executeLightning(r);
                poppedAny = true;
            } else {
                const matches = this.findMatches(r, c);
                if (matches.length >= 3) {
                    poppedAny = true;
                    this.popMatches(matches);
                } else {
                    this.combo = 1;
                }
            }

            const floaters = this.detectFloatingBubbles();
            if (floaters.length > 0) {
                this.dropFloatingBubbles(floaters);
            }

            this.unlockAdjacentLocked(r, c);
            this.checkObjectiveProgress();
            this.canShoot = true;
            this.checkGameOutcome();
        }

        findMatches(startR, startC) {
            const targetColor = this.grid[startR][startC].color;
            if (targetColor === BubbleColor.NONE) return [];

            const visited = new Set();
            const matched = [];
            const queue = [{ r: startR, c: startC }];
            visited.add(`${startR},${startC}`);

            while (queue.length > 0) {
                const curr = queue.shift();
                matched.push(curr);

                for (const n of getNeighbors(curr.r, curr.c)) {
                    const key = `${n.r},${n.c}`;
                    if (!visited.has(key)) {
                        const cell = this.grid[n.r][n.c];
                        if (cell && !cell.locked) {
                            if (cell.color === targetColor || cell.special === SpecialType.RAINBOW) {
                                visited.add(key);
                                queue.push(n);
                            }
                        }
                    }
                }
            }
            return matched;
        }

        popMatches(matches) {
            sound.playMatch(this.combo);
            const scorePerBubble = 10 * this.combo;
            let totalGain = 0;

            for (const m of matches) {
                const cell = this.grid[m.r][m.c];
                const pos = getGridPosition(m.r, m.c);
                const theme = BUBBLE_THEMES[cell.color] || BUBBLE_THEMES[BubbleColor.RED];

                this.particles.spawnGlassShards(pos.x, pos.y, theme.base, 14);
                this.grid[m.r][m.c] = null;
                totalGain += scorePerBubble;

                if (this.objective.type === ObjectiveType.CLEAR_COLOR && this.objective.color === cell.color) {
                    this.objective.current++;
                }
            }

            this.score += totalGain;
            const centerPos = getGridPosition(matches[0].r, matches[0].c);
            this.particles.spawnScore(centerPos.x, centerPos.y, `+${totalGain}`);

            if (this.combo >= 2) {
                this.particles.spawnCombo(centerPos.x, centerPos.y, this.combo);
                this.lumi.state = 'CHEER';
            }
            this.combo++;
        }

        executeBomb(centerR, centerC) {
            sound.playBomb();
            const pos = getGridPosition(centerR, centerC);
            this.particles.spawnGlassShards(pos.x, pos.y, '#ff4400', 30);

            const cellsToPop = [{ r: centerR, c: centerC }, ...getNeighbors(centerR, centerC)];
            let gain = 0;

            for (const cell of cellsToPop) {
                if (this.grid[cell.r][cell.c]) {
                    const cPos = getGridPosition(cell.r, cell.c);
                    this.particles.spawnGlassShards(cPos.x, cPos.y, '#ff8800', 10);
                    this.grid[cell.r][cell.c] = null;
                    gain += 30;
                }
            }
            this.score += gain;
            this.particles.spawnScore(pos.x, pos.y, `+${gain}`, PALETTE.CORAL);
            this.lumi.state = 'CHEER';
        }

        executeLightning(row) {
            sound.playLightning();
            const cols = row % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
            let gain = 0;

            for (let c = 0; c < cols; c++) {
                if (this.grid[row][c]) {
                    const pos = getGridPosition(row, c);
                    this.particles.spawnGlassShards(pos.x, pos.y, PALETTE.AQUA, 12);
                    this.grid[row][c] = null;
                    gain += 25;
                }
            }
            this.score += gain;
            this.particles.spawnScore(SHOOTER_X, 160 + row * ROW_HEIGHT, `+${gain}`, PALETTE.AQUA);
            this.lumi.state = 'CHEER';
        }

        detectFloatingBubbles() {
            const visited = new Set();
            const queue = [];

            // Anchor is row 0
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

            const unanchored = [];
            for (let r = 0; r < MAX_ROWS; r++) {
                const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                for (let c = 0; c < cols; c++) {
                    if (this.grid[r][c] && !visited.has(`${r},${c}`)) {
                        unanchored.push({ r, c });
                    }
                }
            }
            return unanchored;
        }

        dropFloatingBubbles(floaters) {
            let dropGain = 0;
            for (const f of floaters) {
                const cell = this.grid[f.r][f.c];
                const pos = getGridPosition(f.r, f.c);
                this.droppingBubbles.push({
                    x: pos.x,
                    y: pos.y,
                    vx: (Math.random() - 0.5) * 120,
                    vy: -100 - Math.random() * 150,
                    rot: 0,
                    rotSpeed: (Math.random() - 0.5) * 6,
                    color: cell.color,
                    special: cell.special
                });
                this.grid[f.r][f.c] = null;
                dropGain += 20;
            }
            this.score += dropGain;
            this.particles.spawnScore(SHOOTER_X, 500, `DROP +${dropGain}!`, PALETTE.MINT);
        }

        unlockAdjacentLocked(hitR, hitC) {
            for (const n of getNeighbors(hitR, hitC)) {
                const cell = this.grid[n.r][n.c];
                if (cell && cell.locked) {
                    cell.locked = false;
                    const pos = getGridPosition(n.r, n.c);
                    this.particles.spawnSpark(pos.x, pos.y, PALETTE.CRYSTAL_BLUE);
                }
            }
        }

        checkObjectiveProgress() {
            if (this.objective.type === ObjectiveType.CLEAR_ALL) {
                let remaining = 0;
                for (let r = 0; r < MAX_ROWS; r++) {
                    const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                    for (let c = 0; c < cols; c++) {
                        if (this.grid[r][c]) remaining++;
                    }
                }
                this.objective.current = remaining === 0 ? 1 : 0;
                this.objective.target = 1;
            }
        }

        checkGameOutcome() {
            let won = false;
            if (this.objective.type === ObjectiveType.CLEAR_ALL) {
                won = this.objective.current >= this.objective.target;
            } else if (this.objective.type === ObjectiveType.CLEAR_COLOR) {
                won = this.objective.current >= this.objective.target;
            } else if (this.objective.type === ObjectiveType.REACH_SCORE) {
                won = this.score >= this.targetScore;
            }

            if (won) {
                this.handleWin();
                return;
            }

            // Check Danger Line Breach (Bubble in row >= 10)
            for (let r = DANGER_ROW; r < MAX_ROWS; r++) {
                const cols = r % 2 === 0 ? GRID_COLS_EVEN : GRID_COLS_ODD;
                for (let c = 0; c < cols; c++) {
                    if (this.grid[r][c]) {
                        this.handleLose('Ceiling Overrun!');
                        return;
                    }
                }
            }

            if (this.shotsLeft <= 0 && !this.projectile && this.droppingBubbles.length === 0) {
                this.handleLose('Out of Ammo!');
            }
        }

        handleWin() {
            sound.playVictory();
            this.state = 'WIN';
            this.lumi.state = 'WIN';

            let stars = 1;
            if (this.score >= this.targetScore) stars = 2;
            if (this.score >= this.targetScore * 1.4) stars = 3;

            saveSystem.saveLevelResult(this.currentLevelId, this.score, stars);
        }

        handleLose(reason) {
            sound.playDefeat();
            this.state = 'LOSE';
            this.lumi.state = 'LOSE';
            this.loseReason = reason;
        }

        // =====================================================================
        // 8. INPUT SYSTEM
        // =====================================================================
        setupInput() {
            const getCanvasCoords = (e) => {
                const rect = this.canvas.getBoundingClientRect();
                const scaleX = V_WIDTH / rect.width;
                const scaleY = V_HEIGHT / rect.height;
                const clientX = e.touches ? e.touches[0].clientX : e.clientX;
                const clientY = e.touches ? e.touches[0].clientY : e.clientY;
                return {
                    x: (clientX - rect.left) * scaleX,
                    y: (clientY - rect.top) * scaleY
                };
            };

            const handlePointerDown = (e) => {
                sound.init();
                const pos = getCanvasCoords(e);
                this.handleClick(pos.x, pos.y);
            };

            const handlePointerMove = (e) => {
                const pos = getCanvasCoords(e);
                if (this.state === 'GAMEPLAY' && pos.y < SHOOTER_Y) {
                    const dx = pos.x - SHOOTER_X;
                    const dy = pos.y - SHOOTER_Y;
                    let angle = Math.atan2(dy, dx);
                    // Constrain aim arc (15 deg to 165 deg upwards)
                    angle = Math.max(-Math.PI + 0.25, Math.min(-0.25, angle));
                    this.aimAngle = angle;
                    this.isAiming = true;
                    this.lumi.aimAngle = angle;
                }
            };

            const handlePointerUp = (e) => {
                if (this.state === 'GAMEPLAY' && this.isAiming) {
                    this.isAiming = false;
                    this.fireBubble();
                }
            };

            this.canvas.addEventListener('mousedown', handlePointerDown);
            window.addEventListener('mousemove', handlePointerMove);
            window.addEventListener('mouseup', handlePointerUp);

            this.canvas.addEventListener('touchstart', handlePointerDown, { passive: false });
            window.addEventListener('touchmove', handlePointerMove, { passive: false });
            window.addEventListener('touchend', handlePointerUp, { passive: false });
        }

        handleClick(x, y) {
            if (this.state === 'SPLASH') {
                sound.playClick();
                this.state = 'MENU';
                return;
            }

            if (this.state === 'MENU') {
                // Play Button (Section 9: Large primary capsule)
                if (x >= 200 && x <= 520 && y >= 640 && y <= 725) {
                    sound.playClick();
                    this.state = 'MAP';
                }
                // Settings Button
                if (x >= 200 && x <= 520 && y >= 750 && y <= 825) {
                    sound.playClick();
                    this.state = 'SETTINGS';
                }
                // Tutorial Button
                if (x >= 200 && x <= 520 && y >= 850 && y <= 925) {
                    sound.playClick();
                    this.state = 'TUTORIAL';
                }
                return;
            }

            if (this.state === 'MAP') {
                // Back to Menu Button
                if (x >= 40 && x <= 140 && y >= 40 && y <= 90) {
                    sound.playClick();
                    this.state = 'MENU';
                    return;
                }

                // World switch tabs
                for (let w = 1; w <= 3; w++) {
                    const tabX = 140 + (w - 1) * 150;
                    if (x >= tabX - 65 && x <= tabX + 65 && y >= 110 && y <= 160) {
                        const requiredStars = WORLD_DATA[w - 1].starReq;
                        if (saveSystem.data.totalStars >= requiredStars) {
                            sound.playClick();
                            this.currentWorldId = w;
                        }
                        return;
                    }
                }

                // Level Nodes Click Detection
                const startLvl = (this.currentWorldId - 1) * 10 + 1;
                for (let i = 0; i < 10; i++) {
                    const lvl = startLvl + i;
                    const nodePos = this.getLevelNodePosition(i);
                    const dist = Math.hypot(nodePos.x - x, nodePos.y - y);
                    if (dist <= 40) {
                        if (lvl <= saveSystem.data.unlockedLevel) {
                            sound.playClick();
                            this.loadLevel(lvl);
                        }
                        return;
                    }
                }
                return;
            }

            if (this.state === 'GAMEPLAY') {
                // Pause Icon Button (Top Right)
                if (x >= 630 && x <= 690 && y >= 30 && y <= 90) {
                    sound.playClick();
                    this.state = 'PAUSE';
                    return;
                }

                // Swap Ammo Button (Click on Next Ammo preview)
                if (x >= SHOOTER_X - 150 && x <= SHOOTER_X - 70 && y >= SHOOTER_Y - 40 && y <= SHOOTER_Y + 40) {
                    this.swapBubbles();
                    return;
                }
                return;
            }

            if (this.state === 'PAUSE') {
                // Resume
                if (x >= 220 && x <= 500 && y >= 520 && y <= 590) {
                    sound.playClick();
                    this.state = 'GAMEPLAY';
                }
                // Restart
                if (x >= 220 && x <= 500 && y >= 610 && y <= 680) {
                    sound.playClick();
                    this.loadLevel(this.currentLevelId);
                }
                // World Map
                if (x >= 220 && x <= 500 && y >= 700 && y <= 770) {
                    sound.playClick();
                    this.state = 'MAP';
                }
                return;
            }

            if (this.state === 'WIN') {
                // Next Level
                if (x >= 220 && x <= 500 && y >= 720 && y <= 795) {
                    sound.playClick();
                    if (this.currentLevelId < 30) {
                        this.loadLevel(this.currentLevelId + 1);
                    } else {
                        this.state = 'MAP';
                    }
                }
                // Map
                if (x >= 220 && x <= 500 && y >= 815 && y <= 885) {
                    sound.playClick();
                    this.state = 'MAP';
                }
                return;
            }

            if (this.state === 'LOSE') {
                // Retry
                if (x >= 220 && x <= 500 && y >= 700 && y <= 775) {
                    sound.playClick();
                    this.loadLevel(this.currentLevelId);
                }
                // Map
                if (x >= 220 && x <= 500 && y >= 795 && y <= 865) {
                    sound.playClick();
                    this.state = 'MAP';
                }
                return;
            }

            if (this.state === 'SETTINGS') {
                // Toggle Sound
                if (x >= 460 && x <= 540 && y >= 450 && y <= 500) {
                    sound.playClick();
                    sound.enabled = !sound.enabled;
                    saveSystem.data.soundEnabled = sound.enabled;
                    saveSystem.save();
                }
                // Toggle Accessibility
                if (x >= 460 && x <= 540 && y >= 530 && y <= 580) {
                    sound.playClick();
                    saveSystem.data.accessibilityGlyphs = !saveSystem.data.accessibilityGlyphs;
                    saveSystem.save();
                }
                // Back
                if (x >= 250 && x <= 470 && y >= 660 && y <= 730) {
                    sound.playClick();
                    this.state = 'MENU';
                }
                return;
            }

            if (this.state === 'TUTORIAL') {
                // Back to Menu
                if (x >= 250 && x <= 470 && y >= 960 && y <= 1030) {
                    sound.playClick();
                    this.state = 'MENU';
                }
                return;
            }
        }

        getLevelNodePosition(index) {
            // S-curve winding path from bottom to top of world map
            const startY = 1050;
            const yStep = 90;
            const y = startY - index * yStep;
            const t = index / 9.0;
            const x = 360 + Math.sin(t * Math.PI * 2.2) * 180;
            return { x, y };
        }

        bindEvents() {
            window.addEventListener('resize', () => {
                // Canvas scales responsively via CSS
            });
        }

        // =====================================================================
        // 9. RENDER PIPELINE & VISUAL DESIGN ENGINE
        // =====================================================================
        loop(timestamp) {
            const dt = Math.min((timestamp - this.lastTime) / 1000, 0.1);
            this.lastTime = timestamp;
            this.totalTime += dt;

            this.update(dt);
            this.render();

            requestAnimationFrame(this.loop.bind(this));
        }

        update(dt) {
            this.particles.update(dt);
            this.lumi.update(dt);

            if (this.state === 'GAMEPLAY') {
                this.updateProjectile(dt);

                // Update falling bubbles
                for (let i = this.droppingBubbles.length - 1; i >= 0; i--) {
                    const b = this.droppingBubbles[i];
                    b.vy += 1200 * dt;
                    b.x += b.vx * dt;
                    b.y += b.vy * dt;
                    b.rot += b.rotSpeed * dt;
                    if (b.y > V_HEIGHT + 100) {
                        this.droppingBubbles.splice(i, 1);
                    }
                }
            }
        }

        render() {
            const ctx = this.ctx;
            ctx.clearRect(0, 0, V_WIDTH, V_HEIGHT);

            this.drawBackground();

            switch (this.state) {
                case 'SPLASH':
                    this.drawSplashView();
                    break;
                case 'MENU':
                    this.drawMenuView();
                    break;
                case 'MAP':
                    this.drawWorldMapView();
                    break;
                case 'GAMEPLAY':
                    this.drawGameplayView();
                    break;
                case 'PAUSE':
                    this.drawGameplayView();
                    this.drawPauseModal();
                    break;
                case 'WIN':
                    this.drawGameplayView();
                    this.drawWinModal();
                    break;
                case 'LOSE':
                    this.drawGameplayView();
                    this.drawLoseModal();
                    break;
                case 'SETTINGS':
                    this.drawSettingsModal();
                    break;
                case 'TUTORIAL':
                    this.drawTutorialModal();
                    break;
            }

            this.particles.draw(ctx);
        }

        // ---------------------------------------------------------------------
        // 8-LAYER COMPOSITE GLASS BUBBLE RENDERING (Section 12-17)
        // ---------------------------------------------------------------------
        drawBubble(x, y, color, special = SpecialType.NONE, locked = false, scale = 1.0) {
            const ctx = this.ctx;
            ctx.save();
            ctx.translate(x, y);
            if (scale !== 1.0) ctx.scale(scale, scale);

            const theme = BUBBLE_THEMES[color] || BUBBLE_THEMES[BubbleColor.RED];

            // Layer 1: Soft Colored Ambient Outer Glow (Section 12.1)
            ctx.shadowColor = theme.glow;
            ctx.shadowBlur = 12;

            // Layer 2: Offset Soft Drop Shadow (Section 17: +3.5px X, +4.5px Y)
            ctx.fillStyle = 'rgba(6, 10, 26, 0.38)';
            ctx.beginPath();
            ctx.arc(3.5, 4.5, BUBBLE_RADIUS * 0.94, 0, Math.PI * 2);
            ctx.fill();

            // Layer 3: Spherical Foundation & Deep Dark Base
            ctx.fillStyle = theme.deep;
            ctx.beginPath();
            ctx.arc(0, 0, BUBBLE_RADIUS, 0, Math.PI * 2);
            ctx.fill();

            // Layer 4: Spherical 3D Light Gradient (Upper-Left to Lower-Right - Section 13)
            const bodyGrad = ctx.createRadialGradient(-10, -10, 3, -4, -4, BUBBLE_RADIUS * 0.95);
            bodyGrad.addColorStop(0, theme.light);
            bodyGrad.addColorStop(0.35, theme.base);
            bodyGrad.addColorStop(1.0, theme.deep);

            ctx.fillStyle = bodyGrad;
            ctx.beginPath();
            ctx.arc(-2, -2, BUBBLE_RADIUS * 0.92, 0, Math.PI * 2);
            ctx.fill();

            // Layer 5: Inner Refraction Core & Soft Lower Ambient Bounce
            const bounceGrad = ctx.createRadialGradient(8, 10, 2, 8, 10, BUBBLE_RADIUS * 0.75);
            bounceGrad.addColorStop(0, theme.light);
            bounceGrad.addColorStop(1, 'rgba(0,0,0,0)');
            ctx.fillStyle = bounceGrad;
            ctx.beginPath();
            ctx.arc(8, 10, BUBBLE_RADIUS * 0.65, 0, Math.PI * 2);
            ctx.fill();

            // Layer 6: Upper-Left Soft Illumination Dome
            ctx.fillStyle = 'rgba(255, 255, 255, 0.35)';
            ctx.beginPath();
            ctx.ellipse(-12, -12, 14, 8, -Math.PI / 4, 0, Math.PI * 2);
            ctx.fill();

            // Layer 7: Primary Specular Highlight (Crisp White Glass Glint - Section 14)
            ctx.fillStyle = 'rgba(255, 255, 255, 0.92)';
            ctx.beginPath();
            ctx.ellipse(-14, -14, 7, 3.5, -Math.PI / 4, 0, Math.PI * 2);
            ctx.fill();

            // Layer 8: Secondary Specular Glint
            ctx.fillStyle = 'rgba(255, 255, 255, 0.75)';
            ctx.beginPath();
            ctx.arc(-6, -20, 2.5, 0, Math.PI * 2);
            ctx.fill();

            // Translucent Glass Rim Stroke (Section 16)
            ctx.strokeStyle = theme.rim;
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.arc(0, 0, BUBBLE_RADIUS - 0.75, 0, Math.PI * 2);
            ctx.stroke();

            ctx.shadowBlur = 0; // Reset shadow

            // Special Bubble Crystal Overlays (Section 12, 48)
            if (special === SpecialType.BOMB) {
                this.drawBombOverlay();
            } else if (special === SpecialType.RAINBOW) {
                this.drawRainbowOverlay();
            } else if (special === SpecialType.LIGHTNING) {
                this.drawLightningOverlay();
            } else if (special === SpecialType.STONE) {
                this.drawStoneOverlay();
            }

            // Locked Frost Ice Crystal Shield (Section 48)
            if (locked) {
                this.drawLockedIceShield();
            }

            // Optional Accessibility Glyph
            if (saveSystem.data.accessibilityGlyphs && special === SpecialType.NONE) {
                ctx.font = 'bold 18px "Segoe UI", sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillStyle = 'rgba(0,0,0,0.6)';
                ctx.fillText(theme.name[0], 1, 1);
                ctx.fillStyle = '#ffffff';
                ctx.fillText(theme.name[0], 0, 0);
            }

            ctx.restore();
        }

        drawBombOverlay() {
            const ctx = this.ctx;
            const pulse = Math.sin(this.totalTime * 6.0) * 0.25 + 0.75;
            ctx.fillStyle = `rgba(255, 100, 20, ${0.4 * pulse})`;
            ctx.beginPath();
            ctx.arc(0, 0, 16, 0, Math.PI * 2);
            ctx.fill();

            ctx.font = 'bold 26px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('💣', 0, 2);
        }

        drawRainbowOverlay() {
            const ctx = this.ctx;
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.85)';
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            ctx.arc(0, 0, 18, 0, Math.PI * 2);
            ctx.stroke();

            ctx.font = 'bold 24px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('🌈', 0, 2);
        }

        drawLightningOverlay() {
            const ctx = this.ctx;
            ctx.fillStyle = '#ffffff';
            ctx.shadowColor = PALETTE.AQUA;
            ctx.shadowBlur = 8;
            ctx.beginPath();
            ctx.moveTo(3, -16);
            ctx.lineTo(-9, 2);
            ctx.lineTo(0, 2);
            ctx.lineTo(-3, 16);
            ctx.lineTo(9, -2);
            ctx.lineTo(0, -2);
            ctx.closePath();
            ctx.fill();
            ctx.shadowBlur = 0;
        }

        drawStoneOverlay() {
            const ctx = this.ctx;
            ctx.fillStyle = '#4c5263';
            ctx.beginPath();
            ctx.arc(0, 0, BUBBLE_RADIUS - 2, 0, Math.PI * 2);
            ctx.fill();

            // Geometric quartz facets
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.45)';
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(-14, -14);
            ctx.lineTo(14, -12);
            ctx.lineTo(18, 14);
            ctx.lineTo(-8, 16);
            ctx.closePath();
            ctx.stroke();
        }

        drawLockedIceShield() {
            const ctx = this.ctx;
            ctx.fillStyle = 'rgba(180, 240, 255, 0.45)';
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.9)';
            ctx.lineWidth = 2.5;

            ctx.beginPath();
            ctx.roundRect(-BUBBLE_RADIUS + 3, -BUBBLE_RADIUS + 3, BUBBLE_DIAMETER - 6, BUBBLE_DIAMETER - 6, 8);
            ctx.fill();
            ctx.stroke();

            // Frost crack line
            ctx.beginPath();
            ctx.moveTo(-16, -16);
            ctx.lineTo(0, 4);
            ctx.lineTo(16, -8);
            ctx.stroke();
        }

        // ---------------------------------------------------------------------
        // GLASS UI COMPONENT LIBRARY (Section 6, 7, 8, 50)
        // ---------------------------------------------------------------------
        drawGlassPanel(x, y, w, h, radius = 24, alpha = 0.35, borderGlint = true) {
            const ctx = this.ctx;
            ctx.save();

            // Outer drop shadow
            ctx.shadowColor = 'rgba(0, 0, 15, 0.45)';
            ctx.shadowBlur = 12;
            ctx.shadowOffsetY = 6;

            // Semi-transparent glass body
            ctx.fillStyle = `rgba(16, 24, 52, ${alpha})`;
            ctx.beginPath();
            ctx.roundRect(x, y, w, h, radius);
            ctx.fill();
            ctx.shadowBlur = 0;
            ctx.shadowOffsetY = 0;

            // Subtle border
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.35)';
            ctx.lineWidth = 1.5;
            ctx.stroke();

            // Top specular highlight edge (Section 6)
            if (borderGlint) {
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.85)';
                ctx.lineWidth = 2.5;
                ctx.beginPath();
                ctx.roundRect(x + 12, y + 2, w - 24, 2, 1);
                ctx.stroke();
            }

            ctx.restore();
        }

        drawGlassButton(x, y, w, h, text, isPrimary = false, radius = 24) {
            const ctx = this.ctx;
            ctx.save();

            if (isPrimary) {
                // Primary Capsule: Aqua -> Blue Gradient (Section 9)
                ctx.shadowColor = PALETTE.AQUA;
                ctx.shadowBlur = 16;
                ctx.shadowOffsetY = 4;

                const grad = ctx.createLinearGradient(x, y, x, y + h);
                grad.addColorStop(0, '#3ddbd9');
                grad.addColorStop(1, '#257ae2');

                ctx.fillStyle = grad;
                ctx.beginPath();
                ctx.roundRect(x, y, w, h, radius);
                ctx.fill();

                ctx.strokeStyle = 'rgba(255, 255, 255, 0.9)';
                ctx.lineWidth = 2.5;
                ctx.stroke();

                // Top highlight glint
                ctx.strokeStyle = '#ffffff';
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.roundRect(x + 16, y + 3, w - 32, 2, 1);
                ctx.stroke();

                ctx.shadowBlur = 0;
                ctx.font = 'bold 26px "Segoe UI", Roboto, sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillStyle = '#ffffff';
                ctx.fillText(text, x + w / 2, y + h / 2 + 1);
            } else {
                // Secondary Glass Button (Section 10)
                this.drawGlassPanel(x, y, w, h, radius, 0.25, true);

                ctx.font = 'bold 22px "Segoe UI", Roboto, sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillStyle = '#ffffff';
                ctx.fillText(text, x + w / 2, y + h / 2 + 1);
            }

            ctx.restore();
        }

        drawCrystalStar(x, y, size = 20, filled = true) {
            const ctx = this.ctx;
            ctx.save();
            ctx.translate(x, y);

            if (filled) {
                ctx.shadowColor = PALETTE.SUNSHINE;
                ctx.shadowBlur = 10;
                ctx.fillStyle = PALETTE.SUNSHINE;
            } else {
                ctx.fillStyle = 'rgba(255, 255, 255, 0.2)';
            }

            // 5-Point Crystal Star
            ctx.beginPath();
            for (let i = 0; i < 5; i++) {
                ctx.lineTo(Math.cos((18 + i * 72) * Math.PI / 180) * size, -Math.sin((18 + i * 72) * Math.PI / 180) * size);
                ctx.lineTo(Math.cos((54 + i * 72) * Math.PI / 180) * (size * 0.45), -Math.sin((54 + i * 72) * Math.PI / 180) * (size * 0.45));
            }
            ctx.closePath();
            ctx.fill();

            if (filled) {
                // Top-Left Glint
                ctx.fillStyle = '#ffffff';
                ctx.beginPath();
                ctx.arc(-size * 0.25, -size * 0.25, size * 0.2, 0, Math.PI * 2);
                ctx.fill();
            }

            ctx.restore();
        }

        // ---------------------------------------------------------------------
        // MULTI-WORLD FANTASY BACKGROUND (Section 4, 5, 49)
        // ---------------------------------------------------------------------
        drawBackground() {
            const ctx = this.ctx;
            const wData = WORLD_DATA[this.currentWorldId - 1] || WORLD_DATA[0];

            // Layer 1: Dark Fantasy Gradient
            const grad = ctx.createLinearGradient(0, 0, 0, V_HEIGHT);
            grad.addColorStop(0, wData.bgTop);
            grad.addColorStop(0.55, wData.bgMid);
            grad.addColorStop(1.0, wData.bgBottom);
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, V_WIDTH, V_HEIGHT);

            // Layer 2: Soft Atmospheric Glow Orbs
            ctx.fillStyle = wData.glow;
            ctx.beginPath();
            ctx.arc(360, 200, 320, 0, Math.PI * 2);
            ctx.fill();

            // Layer 3: Floating Fireflies / Dust
            const time = this.totalTime;
            for (let i = 0; i < 16; i++) {
                const phase = time * 0.8 + i * 1.3;
                const fx = (i * 47 + Math.sin(phase) * 35) % V_WIDTH;
                const fy = (1280 - (time * 25 + i * 80) % 1280);
                const alpha = (Math.sin(phase) * 0.4 + 0.6) * 0.55;

                ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
                ctx.beginPath();
                ctx.arc(fx, fy, 2.0, 0, Math.PI * 2);
                ctx.fill();
            }

            // Layer 4: Playfield Glass Backing
            if (this.state === 'GAMEPLAY' || this.state === 'PAUSE' || this.state === 'WIN' || this.state === 'LOSE') {
                ctx.fillStyle = 'rgba(8, 14, 30, 0.68)';
                ctx.fillRect(72, 160, 576, 1120);

                // Side Crystal Pillars
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.4)';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(72, 160);
                ctx.lineTo(72, 1280);
                ctx.moveTo(648, 160);
                ctx.lineTo(648, 1280);
                ctx.stroke();

                // Danger Line (Row 10)
                const dangerY = 160 + BUBBLE_RADIUS + DANGER_ROW * ROW_HEIGHT;
                const dangerAlpha = Math.sin(time * 4.0) * 0.25 + 0.55;
                ctx.strokeStyle = `rgba(255, 77, 106, ${dangerAlpha})`;
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(80, dangerY);
                ctx.lineTo(640, dangerY);
                ctx.stroke();
            }
        }

        // ---------------------------------------------------------------------
        // VIEW RENDERERS
        // ---------------------------------------------------------------------
        drawSplashView() {
            const ctx = this.ctx;

            // Glass Title Banner
            this.drawGlassPanel(110, 360, 500, 240, 28, 0.45, true);

            ctx.shadowColor = PALETTE.AQUA;
            ctx.shadowBlur = 18;
            ctx.font = 'bold 58px "Segoe UI", Roboto, sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillStyle = '#ffffff';
            ctx.fillText('LUMI', 360, 440);

            ctx.shadowBlur = 0;
            ctx.font = '600 24px "Segoe UI", Roboto, sans-serif';
            ctx.fillStyle = PALETTE.CRYSTAL_BLUE;
            ctx.fillText('BUBBLEWOOD CHRONICLE', 360, 500);

            // Pulsing Tap to Start Glass Capsule
            const pulse = Math.sin(this.totalTime * 4.0) * 0.2 + 0.8;
            ctx.globalAlpha = pulse;
            this.drawGlassButton(200, 780, 320, 68, 'TAP TO START', true, 34);
            ctx.globalAlpha = 1.0;

            this.lumi.draw(ctx);
        }

        drawMenuView() {
            const ctx = this.ctx;

            // Title Header
            ctx.shadowColor = PALETTE.AQUA;
            ctx.shadowBlur = 14;
            ctx.font = 'bold 46px "Segoe UI", Roboto, sans-serif';
            ctx.textAlign = 'center';
            ctx.fillStyle = '#ffffff';
            ctx.fillText('LUMI', 360, 320);
            ctx.font = '600 20px "Segoe UI", Roboto, sans-serif';
            ctx.fillStyle = PALETTE.AQUA;
            ctx.fillText('Crystal Glass Bubblewood', 360, 365);
            ctx.shadowBlur = 0;

            // Total Stars Badge
            this.drawGlassPanel(270, 420, 180, 50, 25, 0.4, true);
            this.drawCrystalStar(305, 445, 14, true);
            ctx.font = 'bold 22px "Segoe UI", Roboto, sans-serif';
            ctx.textAlign = 'center';
            ctx.fillStyle = '#ffffff';
            ctx.fillText(`${saveSystem.data.totalStars} / 90`, 375, 446);

            // Menu Buttons
            this.drawGlassButton(200, 640, 320, 75, 'PLAY GAME', true, 26);
            this.drawGlassButton(200, 750, 320, 68, 'SETTINGS', false, 24);
            this.drawGlassButton(200, 850, 320, 68, 'HOW TO PLAY', false, 24);

            this.lumi.draw(ctx);
        }

        drawWorldMapView() {
            const ctx = this.ctx;

            // Top Header Panel
            this.drawGlassPanel(30, 25, 660, 75, 22, 0.45, true);
            this.drawGlassButton(45, 38, 95, 48, '← BACK', false, 16);

            ctx.font = 'bold 26px "Segoe UI", Roboto, sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillStyle = '#ffffff';
            ctx.fillText('WORLD MAP', 360, 62);

            // Star Counter (Top Right)
            this.drawCrystalStar(575, 62, 14, true);
            ctx.font = 'bold 20px "Segoe UI", Roboto, sans-serif';
            ctx.textAlign = 'left';
            ctx.fillStyle = '#ffffff';
            ctx.fillText(`${saveSystem.data.totalStars}`, 598, 63);

            // World Switch Tabs (Section 5, 34)
            for (let w = 1; w <= 3; w++) {
                const tabX = 140 + (w - 1) * 150;
                const isSelected = this.currentWorldId === w;
                const reqStars = WORLD_DATA[w - 1].starReq;
                const isLocked = saveSystem.data.totalStars < reqStars;

                this.drawGlassPanel(tabX - 65, 115, 130, 45, 14, isSelected ? 0.75 : 0.25, isSelected);

                ctx.font = 'bold 16px "Segoe UI", Roboto, sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillStyle = isSelected ? PALETTE.AQUA : (isLocked ? 'rgba(255,255,255,0.4)' : '#ffffff');
                ctx.fillText(isLocked ? `🔒 ${reqStars}★` : `WORLD ${w}`, tabX, 138);
            }

            // Glowing Crystal Path connecting level nodes (Section 34)
            ctx.save();
            ctx.strokeStyle = 'rgba(72, 229, 212, 0.45)';
            ctx.lineWidth = 6;
            ctx.beginPath();
            for (let i = 0; i < 10; i++) {
                const p = this.getLevelNodePosition(i);
                if (i === 0) ctx.moveTo(p.x, p.y);
                else ctx.lineTo(p.x, p.y);
            }
            ctx.stroke();

            // Animated light flow dash along path
            ctx.strokeStyle = '#ffffff';
            ctx.lineWidth = 2.5;
            ctx.setLineDash([12, 18]);
            ctx.lineDashOffset = -this.totalTime * 35;
            ctx.stroke();
            ctx.restore();

            // Draw Level Nodes (Section 34, 35)
            const startLvl = (this.currentWorldId - 1) * 10 + 1;
            for (let i = 0; i < 10; i++) {
                const lvl = startLvl + i;
                const p = this.getLevelNodePosition(i);
                const isUnlocked = lvl <= saveSystem.data.unlockedLevel;
                const isCurrent = lvl === saveSystem.data.unlockedLevel;
                const stars = saveSystem.data.starRatings[lvl] || 0;

                ctx.save();
                ctx.translate(p.x, p.y);

                if (isCurrent) {
                    // Pulsing Outer Cyan Glow
                    const pulse = Math.sin(this.totalTime * 5.0) * 0.25 + 0.75;
                    ctx.shadowColor = PALETTE.AQUA;
                    ctx.shadowBlur = 18 * pulse;
                }

                // Node Base Crystal Sphere
                ctx.fillStyle = isUnlocked ? (isCurrent ? '#258ae8' : '#14385a') : 'rgba(20, 25, 45, 0.75)';
                ctx.beginPath();
                ctx.arc(0, 0, 32, 0, Math.PI * 2);
                ctx.fill();

                ctx.strokeStyle = isUnlocked ? '#ffffff' : 'rgba(255,255,255,0.25)';
                ctx.lineWidth = 2.5;
                ctx.stroke();

                // Specular Glint
                if (isUnlocked) {
                    ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
                    ctx.beginPath();
                    ctx.arc(-10, -10, 6, 0, Math.PI * 2);
                    ctx.fill();
                }

                ctx.shadowBlur = 0;
                ctx.font = 'bold 22px "Segoe UI", Roboto, sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillStyle = isUnlocked ? '#ffffff' : 'rgba(255,255,255,0.4)';
                ctx.fillText(isUnlocked ? `${lvl}` : '🔒', 0, 1);

                // Stars rating underneath node
                if (isUnlocked && stars > 0) {
                    for (let s = 0; s < 3; s++) {
                        const starX = (s - 1) * 16;
                        this.drawCrystalStar(starX, 42, 6, s < stars);
                    }
                }

                ctx.restore();
            }
        }

        drawGameplayView() {
            const ctx = this.ctx;

            // 1. Top HUD Header (Section 27)
            this.drawGlassPanel(20, 20, 680, 80, 20, 0.40, true);

            // Objective (Left)
            ctx.font = '600 15px "Segoe UI", Roboto, sans-serif';
            ctx.textAlign = 'left';
            ctx.fillStyle = PALETTE.AQUA;
            ctx.fillText(`LVL ${this.currentLevelId}`, 40, 48);

            ctx.font = 'bold 18px "Segoe UI", Roboto, sans-serif';
            ctx.fillStyle = '#ffffff';
            if (this.objective.type === ObjectiveType.CLEAR_COLOR) {
                ctx.fillText(`Target: ${this.objective.current}/${this.objective.target}`, 40, 74);
            } else {
                ctx.fillText(`Clear Grid`, 40, 74);
            }

            // Score & Stars (Center)
            ctx.textAlign = 'center';
            ctx.font = '600 14px "Segoe UI", Roboto, sans-serif';
            ctx.fillStyle = PALETTE.SUNSHINE;
            ctx.fillText('SCORE', 360, 45);

            ctx.font = 'bold 24px "Segoe UI", Roboto, sans-serif';
            ctx.fillStyle = '#ffffff';
            ctx.fillText(`${this.score}`, 360, 74);

            // Shots Ammo Counter (Right)
            ctx.textAlign = 'right';
            ctx.font = '600 14px "Segoe UI", Roboto, sans-serif';
            ctx.fillStyle = this.shotsLeft <= 4 ? PALETTE.CORAL : PALETTE.CRYSTAL_BLUE;
            ctx.fillText('AMMO', 615, 45);

            ctx.font = 'bold 24px "Segoe UI", Roboto, sans-serif';
            ctx.fillStyle = '#ffffff';
            ctx.fillText(`${this.shotsLeft}`, 615, 74);

            // Pause Icon Button
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.8)';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.moveTo(645, 48);
            ctx.lineTo(645, 70);
            ctx.moveTo(655, 48);
            ctx.lineTo(655, 70);
            ctx.stroke();

            // 2. Authoritative Grid Bubbles
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

            // 3. Falling / Dropped Bubbles (Section 24)
            for (const d of this.droppingBubbles) {
                this.drawBubble(d.x, d.y, d.color, d.special, false);
            }

            // 4. Trajectory Aim Guide with Wall Bounces (Section 19, 20)
            if (this.isAiming && this.canShoot) {
                this.drawTrajectory();
            }

            // 5. Active Projectile
            if (this.projectile) {
                this.drawBubble(this.projectile.x, this.projectile.y, this.projectile.color, this.projectile.special);
            }

            // 6. Shooter Launcher & Next Bubble Swap Pedestal (Section 18)
            this.drawShooterLauncher();

            // 7. Companion Lumi
            this.lumi.draw(ctx);
        }

        drawShooterLauncher() {
            const ctx = this.ctx;

            // Shooter Base Glass Pedestal
            ctx.save();
            ctx.translate(SHOOTER_X, SHOOTER_Y);

            // Outer Crystal Ring
            ctx.shadowColor = PALETTE.AQUA;
            ctx.shadowBlur = 12;
            ctx.strokeStyle = PALETTE.AQUA;
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(0, 0, 48, 0, Math.PI * 2);
            ctx.stroke();

            ctx.fillStyle = 'rgba(12, 20, 42, 0.85)';
            ctx.beginPath();
            ctx.arc(0, 0, 46, 0, Math.PI * 2);
            ctx.fill();
            ctx.shadowBlur = 0;

            // Aim Direction Pointer Notch
            ctx.strokeStyle = '#ffffff';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.moveTo(Math.cos(this.aimAngle) * 36, Math.sin(this.aimAngle) * 36);
            ctx.lineTo(Math.cos(this.aimAngle) * 52, Math.sin(this.aimAngle) * 52);
            ctx.stroke();

            ctx.restore();

            // Current Loaded Bubble
            if (this.currentBubble) {
                this.drawBubble(SHOOTER_X, SHOOTER_Y, this.currentBubble.color, this.currentBubble.special);
            }

            // Next Bubble Swap Orb (Left side of shooter)
            const nextX = SHOOTER_X - 110;
            const nextY = SHOOTER_Y;
            this.drawGlassPanel(nextX - 35, nextY - 35, 70, 70, 35, 0.35, true);

            ctx.font = '600 11px "Segoe UI", sans-serif';
            ctx.fillStyle = 'rgba(255,255,255,0.7)';
            ctx.textAlign = 'center';
            ctx.fillText('SWAP', nextX, nextY + 46);

            if (this.nextBubble) {
                this.drawBubble(nextX, nextY, this.nextBubble.color, this.nextBubble.special, false, 0.72);
            }
        }

        drawTrajectory() {
            const ctx = this.ctx;
            let curX = SHOOTER_X;
            let curY = SHOOTER_Y;
            let dirX = Math.cos(this.aimAngle);
            let dirY = Math.sin(this.aimAngle);

            let remainingLen = 1400;
            const step = 22;

            ctx.save();
            while (remainingLen > 0) {
                curX += dirX * step;
                curY += dirY * step;
                remainingLen -= step;

                // Wall reflections (Section 19, 20)
                if (curX <= 72 + BUBBLE_RADIUS) {
                    curX = 72 + BUBBLE_RADIUS;
                    dirX = -dirX;
                    // Wall bounce spark ring
                    ctx.fillStyle = PALETTE.AQUA;
                    ctx.beginPath();
                    ctx.arc(curX, curY, 7, 0, Math.PI * 2);
                    ctx.fill();
                } else if (curX >= 648 - BUBBLE_RADIUS) {
                    curX = 648 - BUBBLE_RADIUS;
                    dirX = -dirX;
                    ctx.fillStyle = PALETTE.AQUA;
                    ctx.beginPath();
                    ctx.arc(curX, curY, 7, 0, Math.PI * 2);
                    ctx.fill();
                }

                if (curY <= 160 + BUBBLE_RADIUS) break;

                // Soft glowing dotted trajectory (Section 19)
                const alpha = Math.max(0.15, remainingLen / 1400.0) * 0.85;
                ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
                ctx.beginPath();
                ctx.arc(curX, curY, 3.5, 0, Math.PI * 2);
                ctx.fill();
            }
            ctx.restore();
        }

        // ---------------------------------------------------------------------
        // MODALS (Pause, Win, Lose, Settings, Tutorial)
        // ---------------------------------------------------------------------
        drawPauseModal() {
            const ctx = this.ctx;
            ctx.fillStyle = 'rgba(4, 8, 20, 0.78)';
            ctx.fillRect(0, 0, V_WIDTH, V_HEIGHT);

            this.drawGlassPanel(160, 420, 400, 420, 28, 0.45, true);

            ctx.font = 'bold 36px "Segoe UI", Roboto, sans-serif';
            ctx.textAlign = 'center';
            ctx.fillStyle = '#ffffff';
            ctx.fillText('PAUSED', 360, 480);

            this.drawGlassButton(220, 520, 280, 68, 'RESUME', true, 24);
            this.drawGlassButton(220, 610, 280, 65, 'RESTART', false, 24);
            this.drawGlassButton(220, 700, 280, 65, 'WORLD MAP', false, 24);
        }

        drawWinModal() {
            const ctx = this.ctx;
            ctx.fillStyle = 'rgba(4, 8, 20, 0.82)';
            ctx.fillRect(0, 0, V_WIDTH, V_HEIGHT);

            this.drawGlassPanel(140, 360, 440, 560, 28, 0.50, true);

            ctx.shadowColor = PALETTE.AQUA;
            ctx.shadowBlur = 18;
            ctx.font = 'bold 42px "Segoe UI", Roboto, sans-serif';
            ctx.textAlign = 'center';
            ctx.fillStyle = '#ffffff';
            ctx.fillText('STAGE CLEAR!', 360, 440);
            ctx.shadowBlur = 0;

            // Star Rating (Section 31, 32)
            let stars = 1;
            if (this.score >= this.targetScore) stars = 2;
            if (this.score >= this.targetScore * 1.4) stars = 3;

            for (let s = 0; s < 3; s++) {
                const starX = 300 + s * 60;
                this.drawCrystalStar(starX, 510, 22, s < stars);
            }

            // Score Display
            ctx.font = '600 20px "Segoe UI", Roboto, sans-serif';
            ctx.fillStyle = PALETTE.SUNSHINE;
            ctx.fillText(`FINAL SCORE: ${this.score}`, 360, 590);

            ctx.font = '16px "Segoe UI", Roboto, sans-serif';
            ctx.fillStyle = 'rgba(255,255,255,0.7)';
            ctx.fillText(`High Score: ${Math.max(this.score, saveSystem.data.highScores[this.currentLevelId] || 0)}`, 360, 630);

            // Action Buttons
            this.drawGlassButton(220, 720, 280, 72, 'NEXT LEVEL', true, 26);
            this.drawGlassButton(220, 815, 280, 65, 'WORLD MAP', false, 24);
        }

        drawLoseModal() {
            const ctx = this.ctx;
            ctx.fillStyle = 'rgba(4, 8, 20, 0.82)';
            ctx.fillRect(0, 0, V_WIDTH, V_HEIGHT);

            this.drawGlassPanel(140, 380, 440, 520, 28, 0.50, true);

            ctx.shadowColor = PALETTE.CORAL;
            ctx.shadowBlur = 16;
            ctx.font = 'bold 38px "Segoe UI", Roboto, sans-serif';
            ctx.textAlign = 'center';
            ctx.fillStyle = '#ffffff';
            ctx.fillText('STAGE FAILED', 360, 460);
            ctx.shadowBlur = 0;

            ctx.font = '600 20px "Segoe UI", Roboto, sans-serif';
            ctx.fillStyle = PALETTE.CORAL;
            ctx.fillText(this.loseReason || 'Try Again!', 360, 520);

            ctx.font = '18px "Segoe UI", Roboto, sans-serif';
            ctx.fillStyle = 'rgba(255,255,255,0.7)';
            ctx.fillText(`Score: ${this.score}`, 360, 580);

            this.drawGlassButton(220, 700, 280, 72, 'RETRY', true, 26);
            this.drawGlassButton(220, 795, 280, 65, 'WORLD MAP', false, 24);
        }

        drawSettingsModal() {
            const ctx = this.ctx;
            this.drawGlassPanel(120, 320, 480, 460, 28, 0.50, true);

            ctx.font = 'bold 36px "Segoe UI", Roboto, sans-serif';
            ctx.textAlign = 'center';
            ctx.fillStyle = '#ffffff';
            ctx.fillText('SETTINGS', 360, 390);

            // Sound Toggle
            ctx.font = 'bold 22px "Segoe UI", Roboto, sans-serif';
            ctx.textAlign = 'left';
            ctx.fillText('Sound Effects', 180, 480);
            this.drawGlassButton(460, 455, 90, 45, sound.enabled ? 'ON' : 'OFF', sound.enabled, 16);

            // Accessibility Glyph Toggle
            ctx.fillText('Color Glyphs', 180, 560);
            this.drawGlassButton(460, 535, 90, 45, saveSystem.data.accessibilityGlyphs ? 'ON' : 'OFF', saveSystem.data.accessibilityGlyphs, 16);

            // Back Button
            this.drawGlassButton(250, 660, 220, 65, 'BACK', true, 24);
        }

        drawTutorialModal() {
            const ctx = this.ctx;
            this.drawGlassPanel(80, 200, 560, 880, 28, 0.55, true);

            ctx.font = 'bold 34px "Segoe UI", Roboto, sans-serif';
            ctx.textAlign = 'center';
            ctx.fillStyle = '#ffffff';
            ctx.fillText('HOW TO PLAY', 360, 270);

            const tips = [
                { icon: '🎯', title: 'Aim & Match', desc: 'Drag to aim, release to shoot. Match 3+ bubbles of the same color to pop them.' },
                { icon: '💧', title: 'Drop Floating Clusters', desc: 'Disconnect clusters from the ceiling to drop them for bonus score.' },
                { icon: '💣', title: 'Power-ups', desc: 'Explode Bombs, clear rows with Lightning, and match wild Rainbows.' },
                { icon: '❄', title: 'Obstacles', desc: 'Pop bubbles adjacent to Ice and Stones to crack them open!' }
            ];

            tips.forEach((t, i) => {
                const cardY = 320 + i * 150;
                this.drawGlassPanel(110, cardY, 500, 130, 18, 0.28, true);

                ctx.font = '32px sans-serif';
                ctx.fillText(t.icon, 155, cardY + 65);

                ctx.font = 'bold 20px "Segoe UI", sans-serif';
                ctx.textAlign = 'left';
                ctx.fillStyle = PALETTE.AQUA;
                ctx.fillText(t.title, 200, cardY + 45);

                ctx.font = '15px "Segoe UI", sans-serif';
                ctx.fillStyle = '#ffffff';
                ctx.fillText(t.desc, 200, cardY + 75, 290);
            });

            this.drawGlassButton(250, 960, 220, 65, 'GOT IT!', true, 24);
        }
    }

    // =========================================================================
    // 10. BOOTSTRAP ENGINE
    // =========================================================================
    window.addEventListener('load', () => {
        new GameEngine();
    });
})();
