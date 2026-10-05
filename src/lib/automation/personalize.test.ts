import { describe, it, expect } from 'vitest';
import { renderTemplate } from '@/lib/automation/personalize';

describe('renderTemplate', () => {
  it('passes through text without a placeholder', () => {
    expect(renderTemplate('سلام، خوش آمدی', 'user')).toBe('سلام، خوش آمدی');
  });

  it('replaces {username} with @handle', () => {
    expect(renderTemplate('Hey {username}!', 'sara')).toBe('Hey @sara!');
  });

  it('does not double-prefix an already-@ handle', () => {
    expect(renderTemplate('Hey {username}!', '@sara')).toBe('Hey @sara!');
  });

  it('replaces every occurrence', () => {
    expect(renderTemplate('{username} و {username}', 'ali')).toBe('@ali و @ali');
  });

  it('strips the placeholder and tidies punctuation when username is unknown', () => {
    expect(renderTemplate('Hey {username}!', null)).toBe('Hey!');
    expect(renderTemplate('Hey {username} !', undefined)).toBe('Hey!');
  });

  it('collapses double spaces left behind by removal', () => {
    expect(renderTemplate('سلام {username} عزیز', null)).toBe('سلام عزیز');
  });

  it('trims whitespace around the handle', () => {
    expect(renderTemplate('Hey {username}!', '  sara  ')).toBe('Hey @sara!');
  });
});
