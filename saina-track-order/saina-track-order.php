<?php
/**
 * Plugin Name: ساینا | پلاگین پیگیری سفارشات Saina Track Order
 * Plugin URI:  https://saina.dev/track-order
 * Description: پیگیری سفارشات ووکامرس با نوار پیشرفت، کد رهگیری پستی، پیامک، ایمیل، فرم جستجوی مشتری، وضعیت بسته‌بندی و تحویل، و پیگیری پست / چاپار / تیپاکس.
 * Version:     1.0.0
 * Author:      ساینا
 * Author URI:  https://saina.dev
 * Text Domain: saina-track-order
 * Domain Path: /languages
 * Requires at least: 6.0
 * Requires PHP: 7.4
 * WC requires at least: 6.0
 * WC tested up to: 9.3
 * License:     GPL-2.0-or-later
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'SAINA_TO_VERSION', '1.0.0' );
define( 'SAINA_TO_FILE', __FILE__ );
define( 'SAINA_TO_DIR', plugin_dir_path( __FILE__ ) );
define( 'SAINA_TO_URL', plugin_dir_url( __FILE__ ) );

add_action(
	'before_woocommerce_init',
	static function () {
		if ( class_exists( \Automattic\WooCommerce\Utilities\FeaturesUtil::class ) ) {
			\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'custom_order_tables', SAINA_TO_FILE, true );
		}
	}
);

require_once SAINA_TO_DIR . 'includes/class-saina-helpers.php';
require_once SAINA_TO_DIR . 'includes/class-saina-statuses.php';
require_once SAINA_TO_DIR . 'includes/class-saina-sms.php';
require_once SAINA_TO_DIR . 'includes/class-saina-ajax.php';
require_once SAINA_TO_DIR . 'includes/class-saina-frontend.php';
require_once SAINA_TO_DIR . 'includes/class-saina-admin.php';
require_once SAINA_TO_DIR . 'includes/class-saina-plugin.php';

register_activation_hook( __FILE__, array( 'Saina_TO_Plugin', 'activate' ) );
register_deactivation_hook( __FILE__, array( 'Saina_TO_Plugin', 'deactivate' ) );

add_action( 'plugins_loaded', array( 'Saina_TO_Plugin', 'instance' ) );
