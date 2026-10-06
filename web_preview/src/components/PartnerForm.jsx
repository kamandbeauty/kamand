import { useState } from 'react';
import content from '../content/appContent.json';
import { fa } from '../persian.js';
import { GlassCard } from './Glass.jsx';

const SIGNS = content.zodiacSigns;

export function PartnerForm({ partner, onSave, onClose, onRemove }) {
  const [name, setName] = useState(partner?.name ?? '');
  const [signId, setSignId] = useState(partner?.signId ?? 'aries');
  const sign = SIGNS.find((s) => s.id === signId);

  return (
    <div className="space-y-4">
      <div>
        <label className="mb-2 block text-[11px] font-bold text-slate-300" htmlFor="partner-name">
          اسم او (اختیاری)
        </label>
        <input
          id="partner-name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="مثلاً ماهی"
          maxLength={30}
          className="glass-soft w-full bg-midnight-800/70 px-4 py-3 text-sm text-slate-100 outline-none placeholder:text-slate-500"
        />
      </div>

      <div>
        <p className="mb-2 text-[11px] font-bold text-slate-300">برج او</p>
        <GlassCard className="grid grid-cols-3 gap-2 p-3">
          {SIGNS.map((s) => (
            <button
              key={s.id}
              onClick={() => setSignId(s.id)}
              aria-pressed={signId === s.id}
              className={`flex flex-col items-center gap-1 rounded-2xl px-2 py-2.5 transition ${
                signId === s.id
                  ? 'bg-gold-400/15 ring-1 ring-gold-400/50'
                  : 'bg-white/[0.04] hover:bg-white/[0.08]'
              }`}
            >
              <span className={`text-xl ${signId === s.id ? 'text-gold-300' : 'text-slate-300'}`}>
                {s.symbol}
              </span>
              <span className={`text-[11px] ${signId === s.id ? 'font-bold text-gold-200' : 'text-slate-300'}`}>
                {s.nameFa}
              </span>
            </button>
          ))}
        </GlassCard>
      </div>

      {sign && (
        <p className="rounded-2xl bg-white/[0.05] p-3 text-[11px] leading-6 text-slate-400">
          {sign.loveStyle}
        </p>
      )}

      <div className="flex gap-2">
        <button
          className="btn-primary flex-1"
          onClick={() => onSave({ name: name.trim() || null, signId })}
        >
          ذخیره شریک
        </button>
        {partner && onRemove && (
          <button
            className="rounded-2xl border border-rose-400/25 bg-rose-400/10 px-4 text-[13px] font-semibold text-rose-300"
            onClick={() => {
              if (window.confirm('شریک عاطفی حذف شود؟')) onRemove();
            }}
          >
            حذف
          </button>
        )}
      </div>
    </div>
  );
}

export function EditProfileSheet({ profile, onSave, onClose }) {
  // Name + birth date editing (mirrors profile_edit_screen.dart).
  const [name, setName] = useState(profile.name ?? '');
  const [y, setY] = useState(profile.y);
  const [m, setM] = useState(profile.m);
  const [d, setD] = useState(profile.d);
  void fa;

  const years = Array.from({ length: 100 }, (_, i) => new Date().getFullYear() - i);

  return (
    <div className="space-y-4">
      <div>
        <label className="mb-2 block text-[11px] font-bold text-slate-300" htmlFor="my-name">اسم من</label>
        <input
          id="my-name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="مثلاً ستاره"
          maxLength={30}
          className="glass-soft w-full bg-midnight-800/70 px-4 py-3 text-sm text-slate-100 outline-none placeholder:text-slate-500"
        />
      </div>
      <div>
        <p className="mb-2 text-[11px] font-bold text-slate-300">تاریخ تولد (شمسی)</p>
        <div className="flex gap-2">
          <NumSelect value={d} onChange={setD} min={1} max={31} label="روز" />
          <NumSelect value={m} onChange={setM} min={1} max={12} label="ماه" />
          <NumSelect value={y} onChange={setY} options={years} label="سال" />
        </div>
      </div>
      <button
        className="btn-primary w-full"
        onClick={() => onSave({ name: name.trim() || null, y, m, d })}
      >
        ذخیره تغییرات
      </button>
    </div>
  );
}

function NumSelect({ value, onChange, min, max, options, label }) {
  const opts = options ?? Array.from({ length: max - min + 1 }, (_, i) => min + i);
  return (
    <select
      value={value}
      onChange={(e) => onChange(Number(e.target.value))}
      aria-label={label}
      className="glass-soft flex-1 appearance-none bg-midnight-800/70 px-3 py-3 text-center text-sm font-semibold text-slate-100 outline-none"
    >
      {opts.map((x) => (
        <option key={x} value={x}>{fa(x)}</option>
      ))}
    </select>
  );
}
