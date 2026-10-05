import { describe, it, expect } from 'vitest';
import { retryBackoffMs } from '@/lib/automation/queue';

describe('retryBackoffMs', () => {
  it('first attempt waits 5 seconds', () => {
    expect(retryBackoffMs(1)).toBe(5000);
  });

  it('scales exponentially (5s → 25s → 125s)', () => {
    expect(retryBackoffMs(2)).toBe(25_000);
    expect(retryBackoffMs(3)).toBe(125_000);
  });

  it('clamps zero/negative attempt counts to the base delay', () => {
    expect(retryBackoffMs(0)).toBe(5000);
    expect(retryBackoffMs(-3)).toBe(5000);
  });
});
