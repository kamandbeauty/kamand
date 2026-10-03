// صداهای بازی با Web Audio API (بدون نیاز به فایل صوتی)
let ctx = null;
let enabled = true;

function ac() {
  if (typeof window === 'undefined') return null;
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
  }
  if (ctx.state === 'suspended') ctx.resume();
  return ctx;
}

export function setSoundEnabled(v) { enabled = v; }

function tone({ freq = 440, dur = 0.12, type = 'sine', gain = 0.08, slideTo = null, delay = 0 }) {
  if (!enabled) return;
  const a = ac();
  if (!a) return;
  const t0 = a.currentTime + delay;
  const osc = a.createOscillator();
  const g = a.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t0);
  if (slideTo) osc.frequency.exponentialRampToValueAtTime(slideTo, t0 + dur);
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.exponentialRampToValueAtTime(gain, t0 + 0.01);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.connect(g).connect(a.destination);
  osc.start(t0);
  osc.stop(t0 + dur + 0.02);
}

function noise({ dur = 0.09, gain = 0.07, delay = 0, hp = 1200 }) {
  if (!enabled) return;
  const a = ac();
  if (!a) return;
  const t0 = a.currentTime + delay;
  const len = Math.floor(a.sampleRate * dur);
  const buf = a.createBuffer(1, len, a.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < len; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / len);
  const src = a.createBufferSource();
  src.buffer = buf;
  const filt = a.createBiquadFilter();
  filt.type = 'highpass';
  filt.frequency.value = hp;
  const g = a.createGain();
  g.gain.setValueAtTime(gain, t0);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  src.connect(filt).connect(g).connect(a.destination);
  src.start(t0);
}

export const sfx = {
  deal: () => noise({ dur: 0.07, gain: 0.05, hp: 1800 }),
  play: () => { noise({ dur: 0.08, gain: 0.07, hp: 1400 }); tone({ freq: 320, dur: 0.05, type: 'triangle', gain: 0.03 }); },
  collect: () => { noise({ dur: 0.16, gain: 0.06, hp: 700 }); },
  trickWin: () => { tone({ freq: 660, dur: 0.1, type: 'sine', gain: 0.06 }); tone({ freq: 880, dur: 0.14, type: 'sine', gain: 0.05, delay: 0.09 }); },
  trickLose: () => { tone({ freq: 300, dur: 0.16, type: 'sine', gain: 0.05, slideTo: 180 }); },
  trump: () => { [523, 659, 784].forEach((f, i) => tone({ freq: f, dur: 0.18, type: 'triangle', gain: 0.05, delay: i * 0.08 })); },
  roundWin: () => { [523, 659, 784, 1046].forEach((f, i) => tone({ freq: f, dur: 0.22, type: 'sine', gain: 0.06, delay: i * 0.11 })); },
  roundLose: () => { [392, 330, 262].forEach((f, i) => tone({ freq: f, dur: 0.26, type: 'sine', gain: 0.05, delay: i * 0.13 })); },
  kot: () => { [784, 988, 1175, 1568].forEach((f, i) => tone({ freq: f, dur: 0.2, type: 'square', gain: 0.035, delay: i * 0.09 })); },
  click: () => tone({ freq: 520, dur: 0.05, type: 'square', gain: 0.03 }),
  error: () => tone({ freq: 180, dur: 0.14, type: 'sawtooth', gain: 0.04 }),
};
