<?php
/**
 * Main plugin coordinator.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio;

use AISEOContentStudio\Admin\AdminMenu;
use AISEOContentStudio\Admin\Assets;
use AISEOContentStudio\Database\Installer;
use AISEOContentStudio\Frontend\Shortcodes;
use AISEOContentStudio\REST\RestServiceProvider;
use AISEOContentStudio\Services\Scheduler;
use AISEOContentStudio\Traits\SingletonTrait;
use AISEOContentStudio\WooCommerce\MetaBox;

if (! defined('ABSPATH')) {
    exit;
}

final class Plugin {
    use SingletonTrait;

    /**
     * Bootstraps plugin services.
     */
    public function boot(): void {
        $this->load_textdomain();
        $this->declare_woocommerce_compatibility();
        Installer::maybe_upgrade();

        (new Assets())->hooks();
        (new AdminMenu())->hooks();
        (new RestServiceProvider())->hooks();
        (new Scheduler())->hooks();
        (new MetaBox())->hooks();
        (new Shortcodes())->hooks();
    }

    /**
     * Loads translations.
     */
    private function load_textdomain(): void {
        load_plugin_textdomain(
            'aiseo-content-studio',
            false,
            dirname(AISEOCS_BASENAME) . '/languages'
        );
    }

    /**
     * Declares WooCommerce HPOS compatibility when WooCommerce is present.
     */
    private function declare_woocommerce_compatibility(): void {
        add_action(
            'before_woocommerce_init',
            static function (): void {
                if (class_exists('Automattic\\WooCommerce\\Utilities\\FeaturesUtil')) {
                    \Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility('custom_order_tables', AISEOCS_FILE, true);
                    \Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility('product_block_editor', AISEOCS_FILE, true);
                }
            }
        );
    }
}
