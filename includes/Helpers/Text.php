<?php
/**
 * Text helpers.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Helpers;

if (! defined('ABSPATH')) {
    exit;
}

final class Text {
    /**
     * Returns a stable hash for cache and logs.
     *
     * @param mixed $value Value to hash.
     */
    public static function hash($value): string {
        return hash('sha256', wp_json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }

    /**
     * Attempts to extract and decode JSON from model output.
     *
     * @param string $text Text returned by an AI provider.
     * @return array<string,mixed>|null
     */
    public static function extract_json(string $text): ?array {
        $trimmed = trim($text);

        if ('' === $trimmed) {
            return null;
        }

        $trimmed = preg_replace('/^```(?:json)?\s*/i', '', $trimmed);
        $trimmed = preg_replace('/\s*```$/', '', (string) $trimmed);
        $decoded = json_decode((string) $trimmed, true);
        if (is_array($decoded)) {
            return $decoded;
        }

        $start = strpos($text, '{');
        $end   = strrpos($text, '}');
        if (false !== $start && false !== $end && $end > $start) {
            $candidate = substr($text, $start, $end - $start + 1);
            $decoded   = json_decode($candidate, true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }

        return null;
    }

    /**
     * Converts a scalar or list into a compact readable string.
     *
     * @param mixed $value Value.
     */
    public static function readable($value): string {
        if (is_array($value)) {
            return implode(', ', array_map(array(__CLASS__, 'readable'), $value));
        }

        if (is_bool($value)) {
            return $value ? __('Yes', 'aiseo-content-studio') : __('No', 'aiseo-content-studio');
        }

        return trim(wp_strip_all_tags((string) $value));
    }

    /**
     * Truncates text on a word boundary.
     *
     * @param string $text Text.
     * @param int    $length Maximum length.
     */
    public static function excerpt(string $text, int $length = 160): string {
        $plain = trim(preg_replace('/\s+/', ' ', wp_strip_all_tags($text)) ?? '');

        if (function_exists('mb_strlen') && mb_strlen($plain) <= $length) {
            return $plain;
        }

        if (! function_exists('mb_substr')) {
            return substr($plain, 0, $length);
        }

        $cut = mb_substr($plain, 0, $length);
        return rtrim((string) preg_replace('/\s+\S*$/u', '', $cut));
    }
}
