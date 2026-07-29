import React, { useEffect, useMemo, useRef, useState } from 'react';
import { groupHits, SEARCH_KIND_ICONS, SEARCH_KIND_LABELS } from '@javid/core';
import { searchAll, type DB } from './store';
import { JDate, Money } from './ui';

/**
 * جستجوی سراسری.
 *
 * پیش‌تر هر صفحه جستجوی خودش را داشت و کاربر باید حدس می‌زد چیزی
 * که دنبالش است کجاست. این پنجره از همه‌جا با Ctrl+K باز می‌شود.
 *
 * پیمایش کامل با صفحه‌کلید است — مغازه‌دار وسط فروش نباید دستش
 * را از کیبورد بردارد.
 */
export function GlobalSearch({ db, open, onClose, onNavigate }: {
  db: DB;
  open: boolean;
  onClose: () => void;
  onNavigate: (page: string) => void;
}) {
  const [q, setQ] = useState('');
  const [active, setActive] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  const hits = useMemo(() => (open ? searchAll(db, q) : []), [db, q, open]);
  const groups = useMemo(() => groupHits(hits), [hits]);

  // نتایج مسطح، به همان ترتیبی که نمایش داده می‌شوند
  const flat = useMemo(() => groups.flatMap((g) => g.items), [groups]);

  useEffect(() => {
    if (open) {
      setQ('');
      setActive(0);
      // تأخیر کوتاه تا پنجره در DOM بنشیند
      setTimeout(() => inputRef.current?.focus(), 30);
    }
  }, [open]);

  useEffect(() => setActive(0), [q]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { onClose(); return; }
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        setActive((i) => Math.min(i + 1, flat.length - 1));
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        setActive((i) => Math.max(i - 1, 0));
      } else if (e.key === 'Enter' && flat[active]) {
        e.preventDefault();
        onNavigate(flat[active]!.page);
        onClose();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, flat, active, onClose, onNavigate]);

  if (!open) return null;

  let index = -1;

  return (
    <div
      className="modal-backdrop"
      onMouseDown={(e) => e.target === e.currentTarget && onClose()}
      style={{ alignItems: 'flex-start', paddingTop: '10vh' }}
    >
      <div className="modal" style={{ maxWidth: 620 }}>
        <div style={{ padding: 14, borderBottom: '1px solid var(--line)' }}>
          <input
            ref={inputRef}
            className="input"
            style={{ fontSize: 15 }}
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="جستجوی فاکتور، شخص، کالا یا چک…"
            aria-label="جستجوی سراسری"
          />
        </div>

        <div className="modal-body" style={{ padding: 0, maxHeight: '55vh' }}>
          {q.trim().length < 2 ? (
            <div className="empty" style={{ padding: 32 }}>
              <span className="ico">🔍</span>
              <p>حداقل دو نویسه بنویسید</p>
              <div className="small muted">
                می‌توانید شمارهٔ فاکتور، نام مشتری، بارکد کالا یا شمارهٔ چک را جستجو کنید.
              </div>
            </div>
          ) : hits.length === 0 ? (
            <div className="empty" style={{ padding: 32 }}>
              <span className="ico">🤷</span>
              <p>چیزی یافت نشد</p>
            </div>
          ) : (
            groups.map((g) => (
              <div key={g.kind}>
                <div className="nav-label" style={{ padding: '10px 16px 4px' }}>
                  {SEARCH_KIND_ICONS[g.kind]} {SEARCH_KIND_LABELS[g.kind]}
                </div>
                {g.items.map((h) => {
                  index += 1;
                  const isActive = index === active;
                  return (
                    <button
                      key={`${h.kind}-${h.id}`}
                      className="nav-item"
                      style={{
                        width: '100%',
                        borderRadius: 0,
                        background: isActive ? 'var(--teal-50)' : undefined,
                        padding: '10px 16px',
                      }}
                      onMouseEnter={() => setActive(flat.indexOf(h))}
                      onClick={() => { onNavigate(h.page); onClose(); }}
                    >
                      <div style={{ flex: 1, textAlign: 'start', minWidth: 0 }}>
                        <div className="strong" style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {h.title}
                        </div>
                        {h.subtitle && <div className="small muted">{h.subtitle}</div>}
                      </div>
                      <div style={{ textAlign: 'end', flexShrink: 0 }}>
                        {h.amount !== undefined && <Money value={h.amount} />}
                        {h.date && <div className="small muted"><JDate value={h.date} /></div>}
                      </div>
                    </button>
                  );
                })}
              </div>
            ))
          )}
        </div>

        <div className="modal-foot" style={{ justifyContent: 'space-between' }}>
          <span className="small muted">
            ↑↓ جابه‌جایی · Enter انتخاب · Esc بستن
          </span>
          <span className="small muted">Ctrl+K</span>
        </div>
      </div>
    </div>
  );
}

/** میانبر Ctrl+K یا Cmd+K برای باز کردن جستجو */
export function useSearchShortcut(onOpen: () => void): void {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        onOpen();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onOpen]);
}
