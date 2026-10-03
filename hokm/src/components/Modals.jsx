import React, { useState } from 'react';
import Card from './Card.jsx';
import { SUITS, SUIT_INFO, toPersianDigits } from '../game/cards.js';
import { TEAM_OF } from '../game/engine.js';

export function Modal({ children, onClose, wide, title, closeable = true }) {
  return (
    <div className="overlay" onClick={closeable ? onClose : undefined}>
      <div
        className={`modal ${wide ? 'modal--wide' : ''}`}
        onClick={(e) => e.stopPropagation()}
      >
        {title && (
          <div className="modal-head">
            <h2>{title}</h2>
            {closeable && <button className="icon-btn" onClick={onClose}>✕</button>}
          </div>
        )}
        <div className="modal-body">{children}</div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- منوی اصلی
export function MainMenu({ onNew, onResume, hasSave, onSettings, onRules, settings }) {
  return (
    <div className="menu-screen">
      <div className="menu-card">
        <div className="menu-logo">
          <span className="logo-suit red">♥</span>
          <span className="logo-suit black">♠</span>
          <h1>حکم</h1>
          <span className="logo-suit red">♦</span>
          <span className="logo-suit black">♣</span>
        </div>
        <p className="menu-sub">بازی کلاسیک ورق ایرانی — چهار نفره، دو تیمی</p>
        <div className="menu-actions">
          {hasSave && (
            <button className="btn btn--gold" onClick={onResume}>ادامه‌ی بازی قبلی</button>
          )}
          <button className="btn btn--primary" onClick={onNew}>بازی جدید</button>
          <button className="btn" onClick={onSettings}>تنظیمات</button>
          <button className="btn" onClick={onRules}>قوانین بازی</button>
        </div>
        <div className="menu-foot">
          هدف: {settings.targetMode === 'points'
            ? `اولین تیمی که ${toPersianDigits(settings.targetPoints)} امتیاز بگیرد`
            : `بیشترین امتیاز پس از ${toPersianDigits(settings.targetRounds)} راند`}
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- تنظیمات
const SURFACES = [
  { id: 'carpet-red', fa: 'قالی گل‌سرخ' },
  { id: 'carpet-blue', fa: 'قالی کاشان' },
  { id: 'carpet-cream', fa: 'قالی تبریز' },
  { id: 'carpet-green', fa: 'گلیم سبز' },
  { id: 'wood-table', fa: 'میز چوبی قدیمی' },
  { id: 'parquet', fa: 'پارکت' },
];
const BACKS = [
  { id: 'back-red', fa: 'قرمز' },
  { id: 'back-blue', fa: 'آبی' },
  { id: 'back-green', fa: 'سبز' },
  { id: 'back-dark', fa: 'شب' },
  { id: 'back-gold', fa: 'طلایی' },
];

export function SettingsModal({ settings, onChange, onClose, inGame }) {
  const set = (k, v) => onChange({ ...settings, [k]: v });
  return (
    <Modal title="تنظیمات" onClose={onClose} wide>
      <div className="settings">
        <section>
          <h3>زمین بازی</h3>
          <div className="surface-grid">
            {SURFACES.map((s) => (
              <button
                key={s.id}
                className={`surface-opt ${settings.surface === s.id ? 'is-active' : ''}`}
                onClick={() => set('surface', s.id)}
              >
                <span
                  className="surface-thumb"
                  style={{ backgroundImage: `url(./surfaces/${s.id}.jpg)` }}
                />
                <span>{s.fa}</span>
              </button>
            ))}
          </div>
        </section>

        <section>
          <h3>طرح پشت کارت</h3>
          <div className="back-grid">
            {BACKS.map((b) => (
              <button
                key={b.id}
                className={`back-opt ${settings.cardBack === b.id ? 'is-active' : ''}`}
                onClick={() => set('cardBack', b.id)}
              >
                <Card faceDown back={b.id} size="sm" />
                <span>{b.fa}</span>
              </button>
            ))}
          </div>
        </section>

        <section>
          <h3>بازی</h3>
          <Row label="نام شما">
            <input
              className="text-input"
              value={settings.playerName}
              maxLength={12}
              onChange={(e) => set('playerName', e.target.value)}
            />
          </Row>
          <Row label="سرعت بازی">
            <Segmented
              value={settings.speed}
              onChange={(v) => set('speed', v)}
              options={[['slow', 'آهسته'], ['normal', 'معمولی'], ['fast', 'سریع']]}
            />
          </Row>
          <Row label="سطح حریف">
            <Segmented
              value={settings.difficulty}
              onChange={(v) => set('difficulty', v)}
              options={[['easy', 'آسان'], ['normal', 'متوسط'], ['hard', 'سخت']]}
            />
          </Row>
          <Row label="افکت‌های صوتی">
            <Toggle value={settings.sound} onChange={(v) => set('sound', v)} />
          </Row>
          <Row label="هایلایت کارت‌های مجاز">
            <Toggle value={settings.showHints} onChange={(v) => set('showHints', v)} />
          </Row>
          <Row label="مرتب‌سازی خودکار دست">
            <Toggle value={settings.sortHand} onChange={(v) => set('sortHand', v)} />
          </Row>
        </section>

        <section>
          <h3>قوانین امتیازدهی</h3>
          <Row label="پایان بازی">
            <Segmented
              value={settings.targetMode}
              onChange={(v) => set('targetMode', v)}
              options={[['points', 'تا امتیاز هدف'], ['rounds', 'تعداد راند']]}
              disabled={inGame}
            />
          </Row>
          {settings.targetMode === 'points' ? (
            <Row label="امتیاز هدف">
              <Segmented
                value={String(settings.targetPoints)}
                onChange={(v) => set('targetPoints', +v)}
                options={[['3', '۳'], ['5', '۵'], ['7', '۷'], ['11', '۱۱']]}
                disabled={inGame}
              />
            </Row>
          ) : (
            <Row label="تعداد راند">
              <Segmented
                value={String(settings.targetRounds)}
                onChange={(v) => set('targetRounds', +v)}
                options={[['5', '۵'], ['10', '۱۰'], ['15', '۱۵']]}
                disabled={inGame}
              />
            </Row>
          )}
          <Row label="کت (۷ بر صفر) = ۲ امتیاز">
            <Toggle value={settings.kotEnabled} onChange={(v) => set('kotEnabled', v)} />
          </Row>
          <Row label="کتِ حاکم = ۳ امتیاز">
            <Toggle value={settings.hakemKotEnabled} onChange={(v) => set('hakemKotEnabled', v)} />
          </Row>
        </section>
      </div>
      <div className="modal-actions">
        <button className="btn btn--primary" onClick={onClose}>تأیید</button>
      </div>
    </Modal>
  );
}

function Row({ label, children }) {
  return (
    <div className="setting-row">
      <span className="setting-label">{label}</span>
      <div className="setting-control">{children}</div>
    </div>
  );
}

function Segmented({ value, onChange, options, disabled }) {
  return (
    <div className={`segmented ${disabled ? 'is-disabled' : ''}`}>
      {options.map(([v, l]) => (
        <button
          key={v}
          className={value === v ? 'is-active' : ''}
          disabled={disabled}
          onClick={() => onChange(v)}
        >{l}</button>
      ))}
    </div>
  );
}

function Toggle({ value, onChange }) {
  return (
    <button
      className={`toggle ${value ? 'is-on' : ''}`}
      onClick={() => onChange(!value)}
      aria-pressed={value}
    ><span /></button>
  );
}

// ---------------------------------------------------------------- جدول امتیاز
export function Scoreboard({ state, onClose }) {
  const { history, scores, settings } = state;
  return (
    <Modal title="جدول امتیازها" onClose={onClose} wide>
      <div className="score-summary">
        <div className="score-box team-0">
          <span>تیم ما</span>
          <strong>{toPersianDigits(scores[0])}</strong>
        </div>
        <div className="score-box team-1">
          <span>تیم حریف</span>
          <strong>{toPersianDigits(scores[1])}</strong>
        </div>
      </div>
      <table className="score-table">
        <thead>
          <tr>
            <th>راند</th><th>حاکم</th><th>حکم</th>
            <th>دست‌ها (ما-حریف)</th><th>امتیاز</th><th>مجموع</th>
          </tr>
        </thead>
        <tbody>
          {history.length === 0 && (
            <tr><td colSpan={6} className="empty">هنوز راندی تمام نشده است</td></tr>
          )}
          {history.map((h) => (
            <tr key={h.round}>
              <td>{toPersianDigits(h.round)}</td>
              <td>{state.players[h.hakem].name}</td>
              <td className={SUIT_INFO[h.trump].color}>
                {SUIT_INFO[h.trump].sym} {SUIT_INFO[h.trump].fa}
              </td>
              <td>{toPersianDigits(h.tricks[0])} - {toPersianDigits(h.tricks[1])}</td>
              <td>
                {h.hakemKot ? 'کت حاکم ' : h.kot ? 'کت ' : ''}
                {toPersianDigits(h.points[0] + h.points[1])}
                {' '}({h.points[0] ? 'ما' : 'حریف'})
              </td>
              <td>{toPersianDigits(h.totals[0])} - {toPersianDigits(h.totals[1])}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <p className="hint">
        {settings.targetMode === 'points'
          ? `بازی تا ${toPersianDigits(settings.targetPoints)} امتیاز`
          : `بازی تا ${toPersianDigits(settings.targetRounds)} راند`}
      </p>
    </Modal>
  );
}

// ---------------------------------------------------------------- پایان راند
export function RoundEndModal({ state, onNext }) {
  const r = state.roundResult;
  const weWon = r.winnerTeam === 0;
  const nextH = TEAM_OF[r.hakem] === r.winnerTeam ? r.hakem : (r.hakem + 1) % 4;
  return (
    <Modal title={null} closeable={false}>
      <div className={`round-end ${weWon ? 'win' : 'lose'}`}>
        <div className="round-end-title">
          {r.hakemKot ? (weWon ? 'کتِ حاکم! 🎉' : 'حاکم کت شد!')
            : r.kot ? (weWon ? 'کت کردید! 🎉' : 'کت شدید!')
              : (weWon ? 'این راند را بردید' : 'این راند را باختید')}
        </div>
        <div className="round-end-tricks">
          <div><span>تیم ما</span><strong>{toPersianDigits(r.tricks[0])}</strong></div>
          <span className="vs">دست</span>
          <div><span>تیم حریف</span><strong>{toPersianDigits(r.tricks[1])}</strong></div>
        </div>
        <div className="round-end-points">
          امتیاز این راند: <strong>{toPersianDigits(r.points)}</strong> برای
          {' '}{weWon ? 'تیم ما' : 'تیم حریف'}
        </div>
        <div className="round-end-total">
          مجموع — ما {toPersianDigits(state.scores[0])} : حریف {toPersianDigits(state.scores[1])}
        </div>
        <div className="round-end-next">
          حاکم راند بعد: <strong>{state.players[nextH].name}</strong>
          {nextH === r.hakem ? ' (حاکم حفظ شد)' : ''}
        </div>
        <button className="btn btn--primary" onClick={onNext}>راند بعد</button>
      </div>
    </Modal>
  );
}

// ---------------------------------------------------------------- پایان بازی
export function GameEndModal({ state, onNew, onMenu }) {
  const g = state.gameResult;
  const weWon = g.winnerTeam === 0;
  return (
    <Modal title={null} closeable={false}>
      <div className={`round-end ${weWon ? 'win' : 'lose'}`}>
        <div className="round-end-title big">
          {g.winnerTeam === -1 ? 'بازی مساوی شد!' : weWon ? 'بردید! 🏆' : 'باختید!'}
        </div>
        <div className="round-end-total">
          تیم ما {toPersianDigits(g.scores[0])} — تیم حریف {toPersianDigits(g.scores[1])}
        </div>
        <div className="modal-actions">
          <button className="btn btn--primary" onClick={onNew}>بازی دوباره</button>
          <button className="btn" onClick={onMenu}>منوی اصلی</button>
        </div>
      </div>
    </Modal>
  );
}

// ---------------------------------------------------------------- آخرین دست
export function TrickViewer({ state, onClose }) {
  const tricks = state.roundTricks || [];
  const [idx, setIdx] = useState(Math.max(0, tricks.length - 1));
  if (!tricks.length) {
    return (
      <Modal title="دست‌های قبلی" onClose={onClose}>
        <p className="hint">هنوز دستی بازی نشده است.</p>
      </Modal>
    );
  }
  const t = tricks[idx];
  return (
    <Modal title={`دست ${toPersianDigits(t.index)} از ${toPersianDigits(tricks.length)}`} onClose={onClose} wide>
      <div className="trick-view">
        {t.cards.map((c) => {
          const win = c.player === t.winner;
          return (
            <div key={c.card.id} className={`trick-view-item ${win ? 'is-winner' : ''}`}>
              <Card card={c.card} size="md" isTrump={c.card.s === state.trump} />
              <div className="trick-view-name">
                {state.players[c.player].name}
                {c.player === t.leader ? ' (شروع)' : ''}
              </div>
              {win && <div className="trick-view-badge">برنده</div>}
            </div>
          );
        })}
      </div>
      <div className="trick-nav">
        <button className="btn btn--sm" disabled={idx === 0} onClick={() => setIdx(idx - 1)}>قبلی</button>
        <span>دستِ {toPersianDigits(t.index)}</span>
        <button className="btn btn--sm" disabled={idx >= tricks.length - 1} onClick={() => setIdx(idx + 1)}>بعدی</button>
      </div>
    </Modal>
  );
}

// ---------------------------------------------------------------- انتخاب حکم
export function TrumpChooser({ hand, onChoose, cardBack }) {
  return (
    <div className="trump-chooser">
      <div className="trump-chooser-box">
        <h3>حکم را انتخاب کنید</h3>
        <div className="trump-chooser-hand">
          {hand.map((c) => <Card key={c.id} card={c} size="md" />)}
        </div>
        <div className="trump-suits">
          {SUITS.map((s) => (
            <button
              key={s}
              className={`trump-btn ${SUIT_INFO[s].color}`}
              onClick={() => onChoose(s)}
            >
              <span className="trump-sym">{SUIT_INFO[s].sym}</span>
              <span className="trump-fa">{SUIT_INFO[s].fa}</span>
              <span className="trump-count">
                {toPersianDigits(hand.filter((c) => c.s === s).length)} کارت
              </span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- قوانین
export function RulesModal({ onClose }) {
  return (
    <Modal title="قوانین بازی حکم" onClose={onClose} wide>
      <div className="rules">
        <h3>کلیات</h3>
        <p>
          حکم با یک دسته ورق ۵۲ تایی و توسط چهار بازیکن در قالب دو تیمِ دو نفره بازی می‌شود.
          هر بازیکن روبه‌روی یارِ خود می‌نشیند. در این بازی شما (پایین) با کامران (بالا) هم‌تیم هستید.
        </p>
        <h3>۱) تعیین حاکم</h3>
        <p>
          در شروع بازی ورق‌ها یکی‌یکی و رو بین بازیکنان پخش می‌شود؛ هر کس زودتر آس بیاورد
          حاکم می‌شود و نشان تاج ♔ کنار نامش قرار می‌گیرد.
        </p>
        <h3>۲) تعیین حکم</h3>
        <p>
          پنج کارت اول به حاکم داده می‌شود و او بر اساس آن‌ها خالِ حکم را انتخاب می‌کند.
          سپس بقیه‌ی کارت‌ها در دو دور چهارتایی پخش می‌شود تا هر بازیکن ۱۳ کارت داشته باشد.
          خالِ حکم تا پایان راند بالاتر از همه‌ی خال‌هاست؛ حتی ۲ِ حکم از آسِ خال‌های دیگر قوی‌تر است.
        </p>
        <h3>۳) روش بازی</h3>
        <p>
          دستِ اول را حاکم شروع می‌کند. بقیه به ترتیب باید از همان خالِ زمین کارت بیندازند.
          برنده‌ی دست، بالاترین کارتِ خالِ زمین است، مگر آن‌که کسی حکم بازی کرده باشد.
          برنده‌ی هر دست، دستِ بعد را شروع می‌کند.
        </p>
        <h3>۴) بریدن و رد دادن</h3>
        <p>
          اگر از خالِ زمین کارت نداشته باشید، می‌توانید با یک کارتِ حکم دست را «ببُرید»
          (حتی با ۲ِ حکم) و برنده شوید، یا کارتی از خال دیگر «رد بدهید». اگر چند نفر ببُرند،
          بالاترین حکم برنده است. داشتنِ خالِ زمین، بازی کردن آن را اجباری می‌کند.
        </p>
        <h3>۵) امتیاز</h3>
        <p>
          هر راند ۱۳ دست دارد؛ تیمی که زودتر ۷ دست بگیرد برنده‌ی راند است و ۱ امتیاز می‌گیرد.
          اگر تیم بازنده حتی یک دست هم نگیرد «کت» می‌شود و تیم برنده ۲ امتیاز می‌گیرد.
          اگر تیمِ مقابلِ حاکم، حاکم را ۷ بر ۰ ببرد «کتِ حاکم» است و ۳ امتیاز دارد.
        </p>
        <h3>۶) حاکمِ راند بعد</h3>
        <p>
          اگر تیم حاکم راند را ببرد، حاکم حفظ می‌شود؛ در غیر این صورت حاکمی به نفر بعدی
          (سمت راست حاکم) می‌رسد.
        </p>
        <h3>۷) پایان بازی</h3>
        <p>
          بازی تا رسیدن یک تیم به امتیاز هدف (پیش‌فرض ۷) یا تا تعداد راندِ تعیین‌شده ادامه دارد.
          این موارد در تنظیمات قابل تغییر است.
        </p>
        <h3>نکته‌ها</h3>
        <ul>
          <li>برای دیدن دست‌های قبلی، روی کارت‌های جمع‌شده‌ی کنار زمین بزنید.</li>
          <li>بازی به‌صورت خودکار ذخیره می‌شود؛ هر وقت برگردید می‌توانید ادامه دهید.</li>
          <li>زمین بازی (قالی، میز چوبی، پارکت) و طرح پشت کارت در تنظیمات قابل تغییر است.</li>
        </ul>
      </div>
    </Modal>
  );
}
