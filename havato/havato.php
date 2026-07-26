<?php
/**
 * Plugin Name:         Havato
 * Plugin URI:          https://havato.app
 * Description:         Enterprise-grade WordPress plugin for cafe social networking, event management, smart matching, and WooCommerce-powered ticketing.
 * Version:             1.0.0
 * Author:              Havato
 * Author URI:          https://havato.app
 * License:             GPL-2.0-or-later
 * License URI:         https://www.gnu.org/licenses/gpl-2.0.txt
 * Text Domain:         havato
 * Domain Path:         /Languages
 * Requires at least:   6.4
 * Requires PHP:        8.3
 * WC requires at least: 8.0
 * WC tested up to:     9.0
 *
 * @package Havato
 */

declare(strict_types=1);

namespace Havato;

if (!defined('ABSPATH')) {
    exit;
}

// Composer autoloader
if (file_exists(__DIR__ . '/vendor/autoload.php')) {
    require_once __DIR__ . '/vendor/autoload.php';
} else {
    // Fallback PSR-4 loader if composer not run
    require_once __DIR__ . '/autoload.php';
}

// Define constants
define('HAVATO_VERSION', '1.0.0');
define('HAVATO_PLUGIN_FILE', __FILE__);
define('HAVATO_PLUGIN_DIR', plugin_dir_path(__FILE__));
define('HAVATO_PLUGIN_URL', plugin_dir_url(__FILE__));
define('HAVATO_ASSETS_URL', HAVATO_PLUGIN_URL . 'assets/');

final class Plugin
{
    private static ?self $instance = null;

    public static function getInstance(): self
    {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    private function __construct()
    {
        $this->registerHooks();
    }

    private function registerHooks(): void
    {
        add_action('init', [$this, 'initPlugin']);
        add_action('plugins_loaded', [$this, 'loadTextdomain']);
        add_action('admin_init', [$this, 'maybeRunDatabaseCheck']);
    }

    public function initPlugin(): void
    {
        // Core initializations
        (new Database\DatabaseManager())->ensureTablesExist();
        
        // Register user roles + admin columns
        $roleManager = new Auth\RoleManager();
        $roleManager->registerRoles();

        // Google OAuth settings
        $googleOAuth = new Auth\GoogleOAuth();
        add_action('admin_init', [$googleOAuth, 'registerSettings']);

        // Admin user columns
        add_filter('manage_users_columns', [$roleManager, 'addUserColumns']);
        add_action('manage_users_custom_column', [$roleManager, 'renderUserColumn'], 10, 3);
        add_action('restrict_manage_users', [$roleManager, 'addUserFilters']);
        add_action('pre_get_users', [$roleManager, 'filterUsers']);

        // Load other modules
        if (is_admin()) {
            new Admin\AdminMenu();
        }

        // Frontend shortcode
        add_shortcode('havato_app', [new Frontend\Shortcode(), 'render']);

        // Enqueue frontend assets
        add_action('wp_enqueue_scripts', function() {
            wp_enqueue_style('havato-app', HAVATO_ASSETS_URL . 'css/havato-app.css', [], HAVATO_VERSION);
            wp_enqueue_script('havato-app', HAVATO_ASSETS_URL . 'js/havato-app.js', [], HAVATO_VERSION, true);
        });
        
        // REST API
        $rest = new API\RestController();
        add_action('rest_api_init', [$rest, 'registerRoutes']);

        // WooCommerce hooks
        if (class_exists('WooCommerce')) {
            new WooCommerce\WooIntegration();
        }
    }

    public function loadTextdomain(): void
    {
        load_plugin_textdomain('havato', false, dirname(plugin_basename(HAVATO_PLUGIN_FILE)) . '/Languages');
    }

    public function maybeRunDatabaseCheck(): void
    {
        if (!get_option('havato_db_checked')) {
            (new Database\DatabaseManager())->ensureTablesExist();
            update_option('havato_db_checked', time());
        }
    }

    public static function activate(): void
    {
        (new Database\DatabaseManager())->ensureTablesExist();
        flush_rewrite_rules();
    }

    public static function deactivate(): void
    {
        flush_rewrite_rules();
    }
}

// Activation / Deactivation hooks
register_activation_hook(__FILE__, [Plugin::class, 'activate']);
register_deactivation_hook(__FILE__, [Plugin::class, 'deactivate']);

// Bootstrap
Plugin::getInstance();