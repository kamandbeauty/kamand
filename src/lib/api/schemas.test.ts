import { describe, it, expect } from 'vitest';
import { DMResponseSchema, computeTokenStatus, MAX_DM_RESPONSES } from '@/lib/api/schemas';

describe('computeTokenStatus', () => {
  it('null expiry = ok with unknown days', () => {
    expect(computeTokenStatus(null)).toEqual({ status: 'ok', daysRemaining: null });
  });

  it('far-future expiry = ok', () => {
    const far = new Date(Date.now() + 40 * 86400_000).toISOString();
    expect(computeTokenStatus(far).status).toBe('ok');
  });

  it('expiry within the 10-day warning window = expiring', () => {
    const soon = new Date(Date.now() + 5 * 86400_000 + 3600_000).toISOString();
    const { status, daysRemaining } = computeTokenStatus(soon);
    expect(status).toBe('expiring');
    expect(daysRemaining).toBe(5);
  });

  it('past expiry = expired, zero days', () => {
    const past = new Date(Date.now() - 60_000).toISOString();
    expect(computeTokenStatus(past)).toEqual({ status: 'expired', daysRemaining: 0 });
  });
});

describe('DMResponseSchema', () => {
  const validText = { id: 'r1', type: 'text', content: 'سلام' };

  it('accepts a text response', () => {
    expect(DMResponseSchema.safeParse(validText).success).toBe(true);
  });

  it('accepts a card response with buttons', () => {
    const card = {
      id: 'r2',
      type: 'card',
      content: '',
      cardTitle: 'عنوان',
      cardButtons: [{ id: 'b1', title: 'دکمه', link: 'https://example.com' }],
    };
    expect(DMResponseSchema.safeParse(card).success).toBe(true);
  });

  it('rejects the removed lead_form type', () => {
    expect(DMResponseSchema.safeParse({ ...validText, type: 'lead_form' }).success).toBe(false);
  });

  it('rejects the removed ask_follow type', () => {
    expect(DMResponseSchema.safeParse({ ...validText, type: 'ask_follow' }).success).toBe(false);
  });

  it('rejects unknown types', () => {
    expect(DMResponseSchema.safeParse({ ...validText, type: 'hologram' }).success).toBe(false);
  });

  it('caps responses at MAX_DM_RESPONSES', () => {
    expect(MAX_DM_RESPONSES).toBe(5);
  });
});
