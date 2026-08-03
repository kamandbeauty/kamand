<?php
/**
 * Rank Math integration.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\SEO\Integrations;

if (! defined('ABSPATH')) {
    exit;
}

final class RankMathIntegration {
    public function apply(int $post_id, string $title, string $description, string $keywords): void {
        update_post_meta($post_id, 'rank_math_title', $title);
        update_post_meta($post_id, 'rank_math_description', $description);
        update_post_meta($post_id, 'rank_math_focus_keyword', $keywords);
    }
}
