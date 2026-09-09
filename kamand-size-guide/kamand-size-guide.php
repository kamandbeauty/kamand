<?php
/**
 * Plugin Name:          کمند | راهنمای سایز محصولات
 * Plugin URI:           https://github.com/kamandbeauty/kamand
 * Description:          جدول راهنمای سایز زیبا و واکنش‌گرا دقیقاً زیر دکمهٔ خرید هر محصول ووکامرس؛ با چند راهنما به‌صورت تب، تبدیل سانتی‌متر/اینچ، پنجرهٔ بزرگ‌نمایی و هایلایت خودکار سایز انتخاب‌شده در محصولات متغیر.
 * Version:              1.0.0
 * Requires at least:    5.9
 * Requires PHP:         7.4
 * Author:               کمند
 * Author URI:           https://github.com/kamandbeauty/kamand
 * Text Domain:          kamand-size-guide
 * Domain Path:          /languages
 * License:              GPL-2.0-or-later
 * License URI:          https://www.gnu.org/licenses/gpl-2.0.html
 * WC requires at least: 6.0
 * WC tested up to:      9.9
 *
 * @package KamandSizeGuide
 */

defined( 'ABSPATH' ) || exit;

define( 'KSG_VERSION', '1.0.0' );
define( 'KSG_PLUGIN_FILE', __FILE__ );
define( 'KSG_PLUGIN_DIR', plugin_dir_path( __FILE__ ) );
define( 'KSG_PLUGIN_URL', plugin_dir_url( __FILE__ ) );
define( 'KSG_POST_TYPE', 'ksg_size_guide' );
define( 'KSG_MIN_PHP', '7.4' );

require_once KSG_PLUGIN_DIR . 'includes/class-ksg-guides.php';
require_once KSG_PLUGIN_DIR . 'includes/class-ksg-products.php';
require_once KSG_PLUGIN_DIR . 'includes/class-ksg-settings.php';
require_once KSG_PLUGIN_DIR . 'includes/class-ksg-frontend.php';
require_once KSG_PLUGIN_DIR . 'includes/class-ksg-shortcode.php';
require_once KSG_PLUGIN_DIR . 'includes/class-ksg-plugin.php';

/**
 * راه‌اندازی افزونه پس از بارگذاری کامل وردپرس و ووکامرس.
 */
add_action( 'plugins_loaded', array( 'KSG_Plugin', 'instance' ) );

register_activation_hook( __FILE__, array( 'KSG_Plugin', 'activate' ) );
register_deactivation_hook( __FILE__, array( 'KSG_Plugin', 'deactivate' ) );
