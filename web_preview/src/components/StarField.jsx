import { useEffect, useRef } from 'react';
import { DetRandom } from '../engine.js';

/**
 * Deterministic star field — same layout algorithm as the Flutter
 * StarField (DetRandom(0x51A17E) precomputed stars, twinkle phase).
 * Drawn once per size; a few overlay dots get a subtle CSS twinkle
 * (disabled automatically via prefers-reduced-motion in index.css).
 */
export default function StarField({ density = 1, className = '' }) {
  const ref = useRef(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const parent = canvas.parentElement;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);

    const draw = () => {
      const w = parent.clientWidth;
      const h = parent.clientHeight;
      if (!w || !h) return;
      canvas.width = w * dpr;
      canvas.height = h * dpr;
      canvas.style.width = `${w}px`;
      canvas.style.height = `${h}px`;
      const ctx = canvas.getContext('2d');
      ctx.scale(dpr, dpr);
      ctx.clearRect(0, 0, w, h);

      const rng = new DetRandom(0x51a17e);
      const count = Math.round((w * h) / 2600 * density);
      for (let i = 0; i < count; i++) {
        const x = rng.nextInt(w);
        const y = rng.nextInt(h);
        const r = 0.4 + rng.nextInt(3) * 0.45;
        const alpha = 0.25 + rng.nextInt(60) / 130;
        const gold = rng.nextInt(7) === 0;
        ctx.beginPath();
        ctx.arc(x, y, r, 0, Math.PI * 2);
        ctx.fillStyle = gold
          ? `rgba(232, 199, 123, ${alpha + 0.15})`
          : `rgba(226, 232, 255, ${alpha})`;
        ctx.fill();
      }
      // one soft golden glow
      const gx = rng.nextInt(w);
      const gy = rng.nextInt(h);
      const glow = ctx.createRadialGradient(gx, gy, 0, gx, gy, 90);
      glow.addColorStop(0, 'rgba(232,199,123,0.10)');
      glow.addColorStop(1, 'rgba(232,199,123,0)');
      ctx.fillStyle = glow;
      ctx.fillRect(gx - 90, gy - 90, 180, 180);
    };

    draw();
    const ro = new ResizeObserver(draw);
    ro.observe(parent);
    return () => ro.disconnect();
  }, [density]);

  return <canvas ref={ref} className={`pointer-events-none absolute inset-0 ${className}`} />;
}
