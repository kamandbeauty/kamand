<?php
/**
 * WooCommerce product AI panel metabox.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\WooCommerce;

if (! defined('ABSPATH')) {
    exit;
}

final class MetaBox {
    /**
     * Registers hooks.
     */
    public function hooks(): void {
        add_action('add_meta_boxes_product', array($this, 'add'));
    }

    /**
     * Adds the metabox.
     */
    public function add(): void {
        add_meta_box(
            'aiseocs_product_ai_panel',
            __('AI SEO Content Studio', 'aiseo-content-studio'),
            array($this, 'render'),
            'product',
            'normal',
            'high'
        );
    }

    /**
     * Renders the metabox.
     *
     * @param \WP_Post $post Product post.
     */
    public function render($post): void {
        if (! current_user_can('edit_post', (int) $post->ID)) {
            return;
        }

        $product_id = (int) $post->ID;
        require AISEOCS_PATH . 'templates/product-panel.php';
    }
}
