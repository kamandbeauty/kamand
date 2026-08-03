<?php
/**
 * Plugin Name: AI SEO Content Studio
 * Plugin URI: https://kamandbeauty.com/
 * Description: Premium AI writing, SEO, WooCommerce product content, prompt library, history, queue, image, and provider studio for WordPress.
 * Version: 1.0.0
 * Requires at least: 6.5
 * Requires PHP: 8.1
 * Author: Kamand Beauty
 * Author URI: https://kamandbeauty.com/
 * Text Domain: aiseo-content-studio
 * Domain Path: /languages
 * WC requires at least: 8.0
 * WC tested up to: 10.0
 * License: GPL-2.0-or-later
 * License URI: https://www.gnu.org/licenses/gpl-2.0.html
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

if (! defined('ABSPATH')) {
    exit;
}

define('AISEOCS_VERSION', '1.0.0');
define('AISEOCS_FILE', __FILE__);
define('AISEOCS_PATH', plugin_dir_path(__FILE__));
define('AISEOCS_URL', plugin_dir_url(__FILE__));
define('AISEOCS_BASENAME', plugin_basename(__FILE__));
define('AISEOCS_TEXT_DOMAIN', 'aiseo-content-studio');

require_once AISEOCS_PATH . 'includes/Autoloader.php';

AISEOContentStudio\Autoloader::register();

register_activation_hook(AISEOCS_FILE, array(AISEOContentStudio\Database\Installer::class, 'activate'));
register_deactivation_hook(AISEOCS_FILE, array(AISEOContentStudio\Database\Installer::class, 'deactivate'));

add_action(
    'plugins_loaded',
    static function (): void {
        AISEOContentStudio\Plugin::instance()->boot();
    }
);
