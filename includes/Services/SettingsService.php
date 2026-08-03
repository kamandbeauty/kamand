<?php
/**
 * Settings service.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Services;

use AISEOContentStudio\Helpers\Sanitizer;

if (! defined('ABSPATH')) {
    exit;
}

final class SettingsService {
    public const OPTION = 'aiseocs_settings';

    /**
     * Returns default settings.
     *
     * @return array<string,mixed>
     */
    public function defaults(): array {
        return array(
            'default_provider'          => 'openai',
            'default_model'             => 'gpt-4o-mini',
            'language'                  => str_starts_with((string) get_locale(), 'fa') ? 'fa_IR' : 'en_US',
            'tone'                      => 'professional',
            'writing_style'             => 'seo_editorial',
            'length'                    => 'long',
            'temperature'               => 0.7,
            'top_p'                     => 1.0,
            'presence_penalty'          => 0.0,
            'frequency_penalty'         => 0.0,
            'max_tokens'                => 4096,
            'cache_enabled'             => true,
            'cache_ttl'                 => DAY_IN_SECONDS,
            'auto_fill_seo_plugins'     => true,
            'auto_apply_product_images' => false,
            'history_retention_days'    => 180,
            'delete_data_on_uninstall'  => false,
            'theme'                     => 'auto',
            'rtl_fonts'                 => true,
            'queue_batch_size'          => 3,
            'cost_markup_percent'       => 0,
        );
    }

    /**
     * Returns all settings.
     *
     * @return array<string,mixed>
     */
    public function all(): array {
        $saved = get_option(self::OPTION, array());
        if (! is_array($saved)) {
            $saved = array();
        }

        return wp_parse_args($saved, $this->defaults());
    }

    /**
     * Gets one setting.
     *
     * @param string $key Setting key.
     * @param mixed  $default Default value.
     * @return mixed
     */
    public function get(string $key, $default = null) {
        $settings = $this->all();
        return array_key_exists($key, $settings) ? $settings[$key] : $default;
    }

    /**
     * Updates settings.
     *
     * @param array<string,mixed> $settings Settings.
     * @return array<string,mixed>
     */
    public function update(array $settings): array {
        $current = $this->all();
        $clean   = $current;

        foreach ($settings as $key => $value) {
            $key = sanitize_key((string) $key);
            if (! array_key_exists($key, $current)) {
                continue;
            }

            switch ($key) {
                case 'temperature':
                    $clean[$key] = (float) min(2, max(0, (float) $value));
                    break;
                case 'top_p':
                    $clean[$key] = (float) min(1, max(0, (float) $value));
                    break;
                case 'presence_penalty':
                case 'frequency_penalty':
                    $clean[$key] = (float) min(2, max(-2, (float) $value));
                    break;
                case 'max_tokens':
                    $clean[$key] = max(256, min(32000, absint($value)));
                    break;
                case 'cache_ttl':
                    $clean[$key] = max(MINUTE_IN_SECONDS, absint($value));
                    break;
                case 'history_retention_days':
                    $clean[$key] = max(1, absint($value));
                    break;
                case 'queue_batch_size':
                    $clean[$key] = max(1, min(20, absint($value)));
                    break;
                case 'cost_markup_percent':
                    $clean[$key] = max(0, min(1000, (float) $value));
                    break;
                case 'cache_enabled':
                case 'auto_fill_seo_plugins':
                case 'auto_apply_product_images':
                case 'delete_data_on_uninstall':
                case 'rtl_fonts':
                    $clean[$key] = ! empty($value);
                    break;
                case 'default_provider':
                    $clean[$key] = sanitize_key((string) $value);
                    break;
                case 'default_model':
                    $clean[$key] = Sanitizer::model((string) $value);
                    break;
                default:
                    $clean[$key] = sanitize_text_field((string) $value);
                    break;
            }
        }

        update_option(self::OPTION, $clean, false);
        return $clean;
    }
}
