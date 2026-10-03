import React from 'react';
import { SUIT_INFO, RANK_LABEL } from '../game/cards.js';

const PIPS = {
  2: [[1, 0], [1, 4]],
  3: [[1, 0], [1, 2], [1, 4]],
  4: [[0, 0], [2, 0], [0, 4], [2, 4]],
  5: [[0, 0], [2, 0], [1, 2], [0, 4], [2, 4]],
  6: [[0, 0], [2, 0], [0, 2], [2, 2], [0, 4], [2, 4]],
  7: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2], [0, 4], [2, 4]],
  8: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2], [1, 3], [0, 4], [2, 4]],
  9: [[0, 0], [2, 0], [0, 1.4], [2, 1.4], [1, 2], [0, 2.6], [2, 2.6], [0, 4], [2, 4]],
  10: [[0, 0], [2, 0], [1, 0.8], [0, 1.4], [2, 1.4], [0, 2.6], [2, 2.6], [1, 3.2], [0, 4], [2, 4]],
};

export default function Card({
  card,
  faceDown = false,
  back = 'back-red',
  onClick,
  playable = false,
  dim = false,
  highlight = false,
  isTrump = false,
  style,
  className = '',
  size = 'md',
}) {
  if (faceDown || !card) {
    return (
      <div
        className={`card card--back ${back} card--${size} ${className}`}
        style={style}
        onClick={onClick}
      >
        <div className="card-back-inner" />
      </div>
    );
  }

  const info = SUIT_INFO[card.s];
  const isFace = card.r >= 11;
  const pips = PIPS[card.r];

  return (
    <div
      className={[
        'card', `card--${size}`, `card--${info.color}`,
        playable ? 'card--playable' : '',
        dim ? 'card--dim' : '',
        highlight ? 'card--highlight' : '',
        isTrump ? 'card--trump' : '',
        className,
      ].filter(Boolean).join(' ')}
      style={style}
      onClick={onClick}
      role={onClick ? 'button' : undefined}
      aria-label={`${RANK_LABEL[card.r]} ${info.fa}`}
    >
      <div className="card-corner card-corner--tl">
        <span className="card-rank">{RANK_LABEL[card.r]}</span>
        <span className="card-suit">{info.sym}</span>
      </div>
      <div className="card-corner card-corner--br">
        <span className="card-rank">{RANK_LABEL[card.r]}</span>
        <span className="card-suit">{info.sym}</span>
      </div>

      {isFace ? (
        <div className="card-face">
          <div className="card-face-letter">{RANK_LABEL[card.r]}</div>
          <div className="card-face-suit">{info.sym}</div>
        </div>
      ) : card.r === 14 ? (
        <div className="card-ace">{info.sym}</div>
      ) : (
        <div className="card-pips">
          {pips.map(([x, y], i) => (
            <span
              key={i}
              className={`pip ${y > 2 ? 'pip--flip' : ''}`}
              style={{ left: `${12 + x * 29}%`, top: `${14 + y * 17}%` }}
            >
              {info.sym}
            </span>
          ))}
        </div>
      )}
      {isTrump && <div className="card-trump-mark">حکم</div>}
    </div>
  );
}
