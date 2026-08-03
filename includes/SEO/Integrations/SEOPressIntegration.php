<?php
/**
 * SEOPress integration.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\SEO\Integrations;

if (! defined('ABSPATH')) {
    exit;
}

final class SEOPressIntegration {
    public function apply(int $post_id, string $title, string $description, string $keywords): void {
        update_post_meta($post_id, '_seopress_titles_title', $title);
        update_post_meta($post_id, '_seopress_titles_desc', $description);
        update_post_meta($post_id, '_seopress_analysis_target_kw', $keywords);
    }
}
