<?php
/**
 * Frontend shortcodes.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Frontend;

if (! defined('ABSPATH')) {
    exit;
}

final class Shortcodes {
    /**
     * Registers shortcodes.
     */
    public function hooks(): void {
        add_shortcode('aiseocs_schema', array($this, 'schema_shortcode'));
    }

    /**
     * Outputs saved Product JSON-LD schema for the current product or supplied ID.
     *
     * @param array<string,mixed> $atts Attributes.
     */
    public function schema_shortcode(array $atts = array()): string {
        $atts = shortcode_atts(array('id' => get_the_ID()), $atts, 'aiseocs_schema');
        $post_id = absint($atts['id']);
        if (! $post_id) {
            return '';
        }

        $schema = get_post_meta($post_id, '_aiseocs_product_schema', true);
        if (! is_string($schema) || '' === $schema) {
            return '';
        }

        $decoded = json_decode($schema, true);
        if (! is_array($decoded)) {
            return '';
        }

        return '<script type="application/ld+json">' . wp_json_encode($decoded, JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) . '</script>';
    }
}
