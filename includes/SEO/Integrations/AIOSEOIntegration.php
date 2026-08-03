<?php
/**
 * All in One SEO integration.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\SEO\Integrations;

if (! defined('ABSPATH')) {
    exit;
}

final class AIOSEOIntegration {
    public function apply(int $post_id, string $title, string $description, string $keywords): void {
        update_post_meta($post_id, '_aioseo_title', $title);
        update_post_meta($post_id, '_aioseo_description', $description);
        update_post_meta($post_id, '_aioseo_keywords', $keywords);
    }
}
