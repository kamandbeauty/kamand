<?php
/**
 * Admin asset loading.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Admin;

if (! defined('ABSPATH')) {
    exit;
}

final class Assets {
    /**
     * Registers hooks.
     */
    public function hooks(): void {
        add_action('admin_enqueue_scripts', array($this, 'admin_assets'));
    }

    /**
     * Enqueues admin assets.
     *
     * @param string $hook Hook suffix.
     */
    public function admin_assets(string $hook): void {
        $screen = function_exists('get_current_screen') ? get_current_screen() : null;
        $is_plugin_page = str_contains($hook, AdminMenu::SLUG);
        $is_product_edit = $screen && 'product' === $screen->post_type && in_array($screen->base, array('post', 'post-new'), true);

        if ($is_plugin_page) {
            wp_enqueue_style(
                'aiseocs-admin',
                AISEOCS_URL . 'assets/css/admin.css',
                array(),
                AISEOCS_VERSION
            );
            wp_enqueue_script(
                'aiseocs-admin',
                AISEOCS_URL . 'assets/js/admin-app.js',
                array('wp-element', 'wp-i18n'),
                AISEOCS_VERSION,
                true
            );
            wp_set_script_translations('aiseocs-admin', 'aiseo-content-studio', AISEOCS_PATH . 'languages');
        }

        if ($is_product_edit) {
            wp_enqueue_style(
                'aiseocs-product-panel',
                AISEOCS_URL . 'assets/css/product-panel.css',
                array(),
                AISEOCS_VERSION
            );
            wp_enqueue_script(
                'aiseocs-product-panel',
                AISEOCS_URL . 'assets/js/product-panel.js',
                array('wp-element', 'wp-i18n'),
                AISEOCS_VERSION,
                true
            );
            wp_set_script_translations('aiseocs-product-panel', 'aiseo-content-studio', AISEOCS_PATH . 'languages');
        }
    }
}
