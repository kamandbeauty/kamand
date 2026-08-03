<?php
/**
 * SEO integration manager.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\SEO;

use AISEOContentStudio\SEO\Integrations\AIOSEOIntegration;
use AISEOContentStudio\SEO\Integrations\RankMathIntegration;
use AISEOContentStudio\SEO\Integrations\SEOPressIntegration;
use AISEOContentStudio\SEO\Integrations\YoastIntegration;
use AISEOContentStudio\Services\SettingsService;

if (! defined('ABSPATH')) {
    exit;
}

final class SEOManager {
    /**
     * Applies SEO fields to supported plugins and portable meta.
     *
     * @param int          $post_id Post ID.
     * @param string       $title SEO title.
     * @param string       $description Meta description.
     * @param array|string $keywords Keywords.
     */
    public function apply(int $post_id, string $title, string $description, $keywords): void {
        $settings = new SettingsService();
        if (! $settings->get('auto_fill_seo_plugins', true)) {
            return;
        }

        $keyword_string = $this->keyword_string($keywords);

        update_post_meta($post_id, '_aiseocs_seo_title', $title);
        update_post_meta($post_id, '_aiseocs_meta_description', $description);
        update_post_meta($post_id, '_aiseocs_focus_keywords', $keyword_string);

        foreach ($this->integrations() as $integration) {
            $integration->apply($post_id, $title, $description, $keyword_string);
        }
    }

    /**
     * Returns integrations.
     *
     * @return array<int,object>
     */
    private function integrations(): array {
        return array(
            new YoastIntegration(),
            new RankMathIntegration(),
            new AIOSEOIntegration(),
            new SEOPressIntegration(),
        );
    }

    /**
     * Converts keywords to a string.
     *
     * @param array|string $keywords Keywords.
     */
    private function keyword_string($keywords): string {
        if (is_array($keywords)) {
            $parts = array();
            foreach ($keywords as $value) {
                if (is_array($value)) {
                    foreach ($value as $item) {
                        if (is_scalar($item)) {
                            $parts[] = sanitize_text_field((string) $item);
                        }
                    }
                } elseif (is_scalar($value)) {
                    $parts[] = sanitize_text_field((string) $value);
                }
            }
            return implode(', ', array_values(array_unique(array_filter($parts))));
        }

        return sanitize_text_field((string) $keywords);
    }
}
