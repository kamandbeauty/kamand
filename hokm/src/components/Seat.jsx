import React from 'react';
import Card from './Card.jsx';
import { toPersianDigits } from '../game/cards.js';

/** صندلی یک بازیکن (حریف/یار) با دسته‌ی پشت‌کارت‌ها و تابلوی نام */
export default function Seat({
  player, pos, isHakem, isTurn, cardBack, teamTricks, label, thinking,
}) {
  const n = player.hand.length;
  const cards = Array.from({ length: n });
  return (
    <div className={`seat seat--${pos} ${isTurn ? 'seat--turn' : ''}`}>
      <div className={`nameplate ${isTurn ? 'nameplate--turn' : ''} team-${player.team}`}>
        {isHakem && <span className="crown" title="حاکم">♔</span>}
        <span className="nameplate-name">{player.name}</span>
        {label && <span className="nameplate-tag">{label}</span>}
        <span className="nameplate-count">{toPersianDigits(n)}</span>
        {thinking && <span className="thinking"><i /><i /><i /></span>}
      </div>
      <div className={`hand hand--${pos}`}>
        {cards.map((_, i) => (
          <Card
            key={i}
            faceDown
            back={cardBack}
            size="sm"
            className={`hand-card hand-card--${pos}`}
            style={{ '--i': i, '--n': n }}
          />
        ))}
      </div>
    </div>
  );
}
