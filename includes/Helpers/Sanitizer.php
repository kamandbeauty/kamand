<?php
/**
 * Sanitization helpers.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Helpers;

if (! defined('ABSPATH')) {
    exit;
}

final class Sanitizer {
    /**
     * Sanitizes recursive data while preserving HTML only for declared keys.
     *
     * @param mixed $value Value to sanitize.
     * @param array<int,string> $html_keys Keys that may contain post HTML.
     * @return mixed
     */
    public static function recursive($value, array $html_keys = array()) {
        if (is_array($value)) {
            $sanitized = array();
            foreach ($value as $key => $item) {
                $clean_key = is_string($key) ? sanitize_key($key) : (int) $key;
                if (is_string($key) && in_array($key, $html_keys, true) && is_string($item)) {
                    $sanitized[$clean_key] = wp_kses_post($item);
                    continue;
                }
                $sanitized[$clean_key] = self::recursive($item, $html_keys);
            }
            return $sanitized;
        }

        if (is_string($value)) {
            return sanitize_textarea_field(wp_unslash($value));
        }

        if (is_bool($value) || is_int($value) || is_float($value) || null === $value) {
            return $value;
        }

        return sanitize_text_field((string) $value);
    }

    /**
     * Sanitizes a model identifier without destroying provider-specific characters.
     *
     * @param string $model Model identifier.
     */
    public static function model(string $model): string {
        $model = wp_unslash($model);
        $model = preg_replace('/[^a-zA-Z0-9_\.\-:\/]/', '', $model);
        return is_string($model) ? substr($model, 0, 191) : '';
    }

    /**
     * Sanitizes a comma or newline separated keyword list.
     *
     * @param mixed $keywords Keywords.
     */
    public static function keywords($keywords): string {
        if (is_array($keywords)) {
            $keywords = implode(', ', array_map('sanitize_text_field', $keywords));
        }

        return sanitize_text_field((string) $keywords);
    }

    /**
     * Sanitizes an integer list.
     *
     * @param mixed $ids IDs.
     * @return array<int,int>
     */
    public static function ids($ids): array {
        if (! is_array($ids)) {
            $ids = preg_split('/[\s,]+/', (string) $ids);
        }

        $ids = array_map('absint', (array) $ids);
        $ids = array_values(array_filter($ids));

        return array_unique($ids);
    }
}
