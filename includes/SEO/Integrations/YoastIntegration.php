<?php
/**
 * Yoast SEO integration.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\SEO\Integrations;

if (! defined('ABSPATH')) {
    exit;
}

final class YoastIntegration {
    public function apply(int $post_id, string $title, string $description, string $keywords): void {
        update_post_meta($post_id, '_yoast_wpseo_title', $title);
        update_post_meta($post_id, '_yoast_wpseo_metadesc', $description);
        update_post_meta($post_id, '_yoast_wpseo_focuskw', $keywords);
    }
}
