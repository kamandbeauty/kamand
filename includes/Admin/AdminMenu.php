<?php
/**
 * Admin menu.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Admin;

if (! defined('ABSPATH')) {
    exit;
}

final class AdminMenu {
    public const SLUG = 'aiseo-content-studio';

    /**
     * Registers hooks.
     */
    public function hooks(): void {
        add_action('admin_menu', array($this, 'menu'));
        add_filter('plugin_action_links_' . AISEOCS_BASENAME, array($this, 'links'));
    }

    /**
     * Adds admin menus.
     */
    public function menu(): void {
        add_menu_page(
            __('AI SEO Content Studio', 'aiseo-content-studio'),
            __('AI SEO Studio', 'aiseo-content-studio'),
            'manage_options',
            self::SLUG,
            array($this, 'render'),
            'dashicons-edit-page',
            56
        );

        $tabs = array(
            'generator' => __('Generator', 'aiseo-content-studio'),
            'providers' => __('AI Providers', 'aiseo-content-studio'),
            'prompts'   => __('Prompt Library', 'aiseo-content-studio'),
            'history'   => __('History', 'aiseo-content-studio'),
            'bulk'      => __('Bulk Queue', 'aiseo-content-studio'),
            'chat'      => __('AI Chat', 'aiseo-content-studio'),
            'settings'  => __('Settings', 'aiseo-content-studio'),
        );

        foreach ($tabs as $tab => $label) {
            add_submenu_page(
                self::SLUG,
                $label,
                $label,
                'manage_options',
                self::SLUG . '&tab=' . $tab,
                array($this, 'render')
            );
        }
    }

    /**
     * Renders admin app template.
     */
    public function render(): void {
        if (! current_user_can('manage_options')) {
            wp_die(esc_html__('You do not have permission to access this page.', 'aiseo-content-studio'));
        }

        $tab = isset($_GET['tab']) ? sanitize_key(wp_unslash((string) $_GET['tab'])) : 'generator';
        require AISEOCS_PATH . 'templates/admin-page.php';
    }

    /**
     * Plugin action links.
     *
     * @param array<int,string> $links Links.
     * @return array<int,string>
     */
    public function links(array $links): array {
        $settings = sprintf(
            '<a href="%s">%s</a>',
            esc_url(admin_url('admin.php?page=' . self::SLUG . '&tab=settings')),
            esc_html__('Settings', 'aiseo-content-studio')
        );
        array_unshift($links, $settings);
        return $links;
    }
}
