import { describe, it, expect } from 'vitest';
import { encrypt, decrypt, safeCompare, hmacSha256Hex, randomToken } from '@/lib/crypto';

const KEY = 'a'.repeat(64); // 32 bytes hex
const OTHER_KEY = 'b'.repeat(64);

describe('AES-256-GCM encrypt/decrypt', () => {
  it('round-trips plaintext', () => {
    const enc = encrypt('سلام دنیا hello world', KEY);
    expect(decrypt(enc, KEY)).toBe('سلام دنیا hello world');
  });

  it('produces the iv:ciphertext:authTag format', () => {
    const parts = encrypt('secret', KEY).split(':');
    expect(parts).toHaveLength(3);
    expect(parts[0]).toMatch(/^[0-9a-f]{24}$/); // 12-byte IV
    expect(parts[2]).toMatch(/^[0-9a-f]{32}$/); // 16-byte auth tag
  });

  it('uses a fresh IV per encryption (non-deterministic output)', () => {
    expect(encrypt('same input', KEY)).not.toBe(encrypt('same input', KEY));
  });

  it('rejects keys that are not 32 bytes', () => {
    expect(() => encrypt('x', 'f'.repeat(63))).toThrow();
    expect(() => encrypt('x', 'zz')).toThrow();
  });

  it('fails to decrypt with the wrong key (auth tag mismatch)', () => {
    const enc = encrypt('secret', KEY);
    expect(() => decrypt(enc, OTHER_KEY)).toThrow();
  });

  it('detects tampered ciphertext', () => {
    const enc = encrypt('secret', KEY);
    const [iv, ct, tag] = enc.split(':') as [string, string, string];
    const flipped = (parseInt(ct.slice(0, 2), 16) ^ 0xff).toString(16).padStart(2, '0') + ct.slice(2);
    expect(() => decrypt(`${iv}:${flipped}:${tag}`, KEY)).toThrow();
  });

  it('rejects malformed encrypted strings', () => {
    expect(() => decrypt('not-enough-colons', KEY)).toThrow();
  });
});

describe('safeCompare', () => {
  it('matches identical strings', () => {
    expect(safeCompare('sha256=abc', 'sha256=abc')).toBe(true);
  });

  it('rejects different strings', () => {
    expect(safeCompare('sha256=abc', 'sha256=abd')).toBe(false);
  });

  it('rejects different lengths without throwing', () => {
    expect(safeCompare('short', 'a-much-longer-value')).toBe(false);
  });
});

describe('hmacSha256Hex', () => {
  it('matches a known HMAC-SHA256 test vector', () => {
    // Well-known vector: key "key", message "The quick brown fox jumps over the lazy dog"
    expect(hmacSha256Hex('key', 'The quick brown fox jumps over the lazy dog')).toBe(
      'f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8'
    );
  });
});

describe('randomToken', () => {
  it('returns hex of the requested byte length', () => {
    expect(randomToken(24)).toMatch(/^[0-9a-f]{48}$/);
    expect(randomToken(16)).toMatch(/^[0-9a-f]{32}$/);
  });

  it('is non-deterministic', () => {
    expect(randomToken(16)).not.toBe(randomToken(16));
  });
});
