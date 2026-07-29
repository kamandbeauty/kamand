import React, { useEffect, useRef, useState } from 'react';
import { formatJalali, formatMoney, parseJalali, jalaliToDate, toLatinDigits, toPersianDigits } from '@javid/core';

/** اجزای پایهٔ رابط کاربری — فارسی و راست‌به‌چپ */

export function Money({ value, sign = false, unit }: { value: number; sign?: boolean; unit?: string }) {
  const cls = sign ? (value > 0 ? 'money-pos' : value < 0 ? 'money-neg' : '') : '';
  return <span className={`num ${cls}`}>{formatMoney(value, { unit })}</span>;
}

export function JDate({ value, style = 'short' }: { value: string | Date | null | undefined; style?: 'short' | 'long' | 'full' }) {
  if (!value) return <span className="muted">—</span>;
  const d = typeof value === 'string' ? new Date(value) : value;
  if (Number.isNaN(d.getTime())) return <span className="muted">—</span>;
  return <span className="num">{formatJalali(d, style)}</span>;
}

export function Num({ value }: { value: number }) {
  return <span className="num">{toPersianDigits(value.toLocaleString('en-US'))}</span>;
}

// ─────────── ورودی مبلغ ───────────

export function MoneyInput({
  value, onChange, placeholder, disabled,
}: {
  value: number;
  onChange: (v: number) => void;
  placeholder?: string;
  disabled?: boolean;
}) {
  const [text, setText] = useState(value ? value.toLocaleString('en-US') : '');
  const focused = useRef(false);

  useEffect(() => {
    if (!focused.current) setText(value ? value.toLocaleString('en-US') : '');
  }, [value]);

  return (
    <input
      className="input num-input"
      inputMode="numeric"
      disabled={disabled}
      placeholder={placeholder ?? '۰'}
      value={text}
      onFocus={() => (focused.current = true)}
      onBlur={() => {
        focused.current = false;
        setText(value ? value.toLocaleString('en-US') : '');
      }}
      onChange={(e) => {
        const raw = toLatinDigits(e.target.value).replace(/[^\d]/g, '');
        const n = raw ? Number(raw) : 0;
        setText(n ? n.toLocaleString('en-US') : '');
        onChange(n);
      }}
    />
  );
}

export function NumberInput({
  value, onChange, step = 1, disabled,
}: {
  value: number;
  onChange: (v: number) => void;
  step?: number;
  disabled?: boolean;
}) {
  return (
    <input
      className="input num-input"
      inputMode="decimal"
      disabled={disabled}
      value={value === 0 ? '' : String(value)}
      placeholder="۰"
      onChange={(e) => {
        const raw = toLatinDigits(e.target.value).replace(/[^\d.]/g, '');
        onChange(raw ? Number(raw) : 0);
      }}
      step={step}
    />
  );
}

/** ورودی تاریخ شمسی — ذخیره به میلادی، نمایش به شمسی */
export function DateInput({
  value, onChange, disabled,
}: {
  value: string;
  onChange: (iso: string) => void;
  disabled?: boolean;
}) {
  const [text, setText] = useState(() => (value ? formatJalali(new Date(value), 'short', false) : ''));
  const [bad, setBad] = useState(false);

  useEffect(() => {
    setText(value ? formatJalali(new Date(value), 'short', false) : '');
    setBad(false);
  }, [value]);

  return (
    <input
      className="input num-input"
      disabled={disabled}
      placeholder="۱۴۰۵/۰۵/۰۷"
      aria-invalid={bad}
      value={text}
      onChange={(e) => {
        const v = e.target.value;
        setText(v);
        const parsed = parseJalali(v);
        if (parsed) {
          setBad(false);
          onChange(jalaliToDate(parsed).toISOString().slice(0, 10));
        } else {
          setBad(v.length >= 8);
        }
      }}
    />
  );
}

// ─────────── چیدمان ───────────

export function Card({ title, action, children, className = '' }: {
  title?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={`card ${className}`}>
      {title && (
        <div className="card-head">
          <h3>{title}</h3>
          <div style={{ flex: 1 }} />
          {action}
        </div>
      )}
      <div className="card-body">{children}</div>
    </div>
  );
}

export function Stat({ label, value, sub, tone }: {
  label: string;
  value: React.ReactNode;
  sub?: string;
  tone?: 'pos' | 'neg';
}) {
  return (
    <div className={`card stat ${tone ?? ''}`}>
      <div className="label">{label}</div>
      <div className="value">{value}</div>
      {sub && <div className="sub">{sub}</div>}
    </div>
  );
}

export function Field({ label, children, hint }: {
  label: string;
  children: React.ReactNode;
  hint?: string;
}) {
  return (
    <div className="field">
      <label>{label}</label>
      {children}
      {hint && <div className="small muted" style={{ marginTop: 4 }}>{hint}</div>}
    </div>
  );
}

export function Empty({ icon = '📋', text, action }: {
  icon?: string;
  text: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="empty">
      <span className="ico">{icon}</span>
      <p>{text}</p>
      {action}
    </div>
  );
}

export function Modal({ title, onClose, children, footer, wide }: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  footer?: React.ReactNode;
  wide?: boolean;
}) {
  useEffect(() => {
    const h = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', h);
    document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', h);
      document.body.style.overflow = '';
    };
  }, [onClose]);

  return (
    <div className="modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={wide ? { maxWidth: 1000 } : undefined}>
        <div className="modal-head">
          <h3>{title}</h3>
          <button className="btn btn-ghost btn-sm" onClick={onClose} aria-label="بستن">✕</button>
        </div>
        <div className="modal-body">{children}</div>
        {footer && <div className="modal-foot">{footer}</div>}
      </div>
    </div>
  );
}

export function Banner({ tone, title, children, action }: {
  tone: 'info' | 'warning' | 'critical' | 'success';
  title?: string;
  children: React.ReactNode;
  action?: React.ReactNode;
}) {
  const icons = { info: 'ℹ️', warning: '⚠️', critical: '⛔', success: '✅' };
  return (
    <div className={`banner banner-${tone}`}>
      <span className="ico">{icons[tone]}</span>
      <div style={{ flex: 1 }}>
        {title && <strong>{title}</strong>}
        {children}
      </div>
      {action}
    </div>
  );
}

export function Badge({ tone, children }: {
  tone: 'green' | 'red' | 'amber' | 'blue' | 'gray';
  children: React.ReactNode;
}) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}

export function Tabs<T extends string>({ tabs, active, onChange }: {
  tabs: { id: T; label: string }[];
  active: T;
  onChange: (id: T) => void;
}) {
  return (
    <div className="tabs">
      {tabs.map((t) => (
        <button key={t.id} className={`tab ${active === t.id ? 'active' : ''}`} onClick={() => onChange(t.id)}>
          {t.label}
        </button>
      ))}
    </div>
  );
}

export function Search({ value, onChange, placeholder = 'جستجو…' }: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <input
      className="input search"
      type="search"
      value={value}
      placeholder={placeholder}
      onChange={(e) => onChange(e.target.value)}
    />
  );
}

/** دانلود فایل در مرورگر */
export function download(filename: string, content: string, mime = 'text/plain;charset=utf-8') {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
