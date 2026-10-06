import clsx from 'clsx';

import { fa } from '../persian.js';

export function GlassCard({ className, children, ...rest }) {
  return (
    <div className={clsx('glass p-4', className)} {...rest}>
      {children}
    </div>
  );
}

export function SectionTitle({ children, action }) {
  return (
    <div className="mb-2.5 flex items-end justify-between px-1">
      <h2 className="text-[13px] font-bold tracking-wide text-slate-100 light:text-slate-800">
        {children}
      </h2>
      {action}
    </div>
  );
}

export function Chip({ children, className }) {
  return <span className={clsx('chip', className)}>{children}</span>;
}

/** Horizontal score bar with label + value (color never sole indicator —
 *  the numeric score is always shown). */
export function ScoreBar({ label, value, max = 100 }) {
  const pct = Math.max(2, Math.min(100, (value / max) * 100));
  return (
    <div className="flex items-center gap-3">
      <span className="w-16 shrink-0 text-[11px] font-medium text-slate-300 light:text-slate-600">
        {label}
      </span>
      <div className="h-2 flex-1 overflow-hidden rounded-full bg-white/10 light:bg-slate-900/10">
        <div
          className="h-full rounded-full transition-all duration-700"
          style={{
            width: `${pct}%`,
            background: 'linear-gradient(90deg, #c9a24b, #e8c77b)',
          }}
        />
      </div>
      <span className="w-8 shrink-0 text-left text-[11px] font-bold text-gold-300 light:text-gold-600">
        {fa(value)}
      </span>
    </div>
  );
}

/** Circular score ring (SVG). */
export function ScoreRing({ value, label, size = 64 }) {
  const r = (size - 8) / 2;
  const c = 2 * Math.PI * r;
  const pct = Math.max(0, Math.min(100, value));
  const phrase = value >= 70 ? 'خوب' : value >= 45 ? 'متوسط' : 'کم';
  return (
    <div className="flex w-16 flex-col items-center gap-1.5" aria-label={`${label} ${fa(value)} از ۱۰۰، ${phrase}`}>
      <div className="relative" style={{ width: size, height: size }}>
        <svg width={size} height={size} className="-rotate-90">
          <circle cx={size / 2} cy={size / 2} r={r} strokeWidth="4" fill="none" className="stroke-white/10 light:stroke-slate-900/10" />
          <circle
            cx={size / 2} cy={size / 2} r={r} strokeWidth="4" fill="none"
            stroke="url(#ringGold)" strokeLinecap="round"
            strokeDasharray={c} strokeDashoffset={c * (1 - pct / 100)}
            style={{ transition: 'stroke-dashoffset 0.8s cubic-bezier(0.22,1,0.36,1)' }}
          />
          <defs>
            <linearGradient id="ringGold" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#f2d9a0" />
              <stop offset="100%" stopColor="#c9a24b" />
            </linearGradient>
          </defs>
        </svg>
        <span className="absolute inset-0 flex items-center justify-center text-sm font-extrabold text-gold-300 light:text-gold-600">
          {fa(value)}
        </span>
      </div>
      <span className="text-[11px] font-semibold text-slate-300 light:text-slate-600">{label}</span>
    </div>
  );
}

/** Fullscreen sheet (mobile bottom-sheet style). */
export function Sheet({ title, onClose, children }) {
  return (
    <div className="absolute inset-0 z-40 flex flex-col justify-end" role="dialog" aria-modal="true" aria-label={title}>
      <button className="sheet-backdrop absolute inset-0 cursor-default" aria-label="بستن" onClick={onClose} />
      <div className="animate-sheet-in relative max-h-[92%] overflow-y-auto rounded-t-[28px] border-t border-white/10 bg-midnight-900/95 p-5 pb-8 backdrop-blur-2xl light:border-slate-900/10 light:bg-[#f5f6fa]">
        <div className="mx-auto mb-4 h-1 w-10 rounded-full bg-white/20 light:bg-slate-900/15" />
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-base font-extrabold text-slate-100 light:text-slate-900">{title}</h2>
          <button
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-sm text-slate-300 transition hover:bg-white/20 light:bg-slate-900/10 light:text-slate-600"
            aria-label="بستن"
          >
            ✕
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
