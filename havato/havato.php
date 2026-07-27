<?php
/**
 * Plugin Name:       Havato — هواتو
 * Plugin URI:        https://havato.app
 * Description:       پلتفرم دورهمی‌های هوشمند در کافه‌ها | Smart social table matching web-app for cafés & restaurants (Glassmorphism PWA + WebView ready).
 * Version:           1.11.0
 * Requires at least: 5.8
 * Requires PHP:      7.4
 * Author:            Havato Team
 * Author URI:        https://havato.app
 * License:           GPL-2.0-or-later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       havato
 * Domain Path:       /languages
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

define( 'HAVATO_VERSION', '1.11.0' );
define( 'HAVATO_DB_VERSION', '1.7.0' );
define( 'HAVATO_FILE', __FILE__ );
define( 'HAVATO_PATH', plugin_dir_path( __FILE__ ) );
define( 'HAVATO_URL', plugin_dir_url( __FILE__ ) );
define( 'HAVATO_BASENAME', plugin_basename( __FILE__ ) );

/**
 * Core bootstrap. Loads every module exactly once and wires the hooks.
 */
final class Havato {

	/**
	 * Singleton instance.
	 *
	 * @var Havato|null
	 */
	private static $instance = null;

	/**
	 * Get (and lazily build) the plugin instance.
	 *
	 * @return Havato
	 */
	public static function instance() {
		if ( null === self::$instance ) {
			self::$instance = new self();
		}
		return self::$instance;
	}

	/**
	 * Constructor: include files and register hooks.
	 */
	private function __construct() {
		$this->includes();
		$this->hooks();
	}

	/**
	 * Load every class file of the plugin.
	 */
	private function includes() {
		require_once HAVATO_PATH . 'includes/functions.php';
		require_once HAVATO_PATH . 'includes/class-havato-jalali.php';
		require_once HAVATO_PATH . 'includes/class-havato-i18n.php';
		require_once HAVATO_PATH . 'includes/class-havato-db.php';
		require_once HAVATO_PATH . 'includes/class-havato-logger.php';
		require_once HAVATO_PATH . 'includes/class-havato-roles.php';
		require_once HAVATO_PATH . 'includes/class-havato-settings.php';
		require_once HAVATO_PATH . 'includes/class-havato-themes.php';
		require_once HAVATO_PATH . 'includes/class-havato-matcher.php';
		require_once HAVATO_PATH . 'includes/class-havato-woo.php';
		require_once HAVATO_PATH . 'includes/class-havato-payouts.php';
		require_once HAVATO_PATH . 'includes/class-havato-google-auth.php';
		require_once HAVATO_PATH . 'includes/class-havato-rest.php';
		require_once HAVATO_PATH . 'includes/class-havato-shortcode.php';
		require_once HAVATO_PATH . 'includes/class-havato-owner-auth.php';
		require_once HAVATO_PATH . 'includes/class-havato-pwa.php';
		require_once HAVATO_PATH . 'includes/class-havato-cron.php';

		if ( is_admin() ) {
			require_once HAVATO_PATH . 'includes/class-havato-admin-ui.php';
			require_once HAVATO_PATH . 'includes/class-havato-admin.php';
			require_once HAVATO_PATH . 'includes/class-havato-owner-admin.php';
		}
	}

	/**
	 * Register WordPress hooks.
	 */
	private function hooks() {
		add_action( 'plugins_loaded', array( $this, 'load_textdomain' ) );
		add_action( 'init', array( 'Havato_Roles', 'register_roles' ) );
		add_action( 'init', array( 'Havato_DB', 'maybe_upgrade' ), 5 );

		Havato_Roles::init();
		Havato_Settings::init();
		Havato_Themes::init();
		Havato_REST::init();
		Havato_Shortcode::init();
		Havato_Owner_Auth::init();
		Havato_PWA::init();
		Havato_Cron::init();
		Havato_Woo::init();
		Havato_Google_Auth::init();

		if ( is_admin() ) {
			Havato_Admin::init();
			Havato_Owner_Admin::init();
		}

		add_filter( 'plugin_action_links_' . HAVATO_BASENAME, array( $this, 'action_links' ) );
	}

	/**
	 * Load translations (the in-app UI uses its own instant-switch map, see Havato_I18N).
	 */
	public function load_textdomain() {
		load_plugin_textdomain( 'havato', false, dirname( HAVATO_BASENAME ) . '/languages' );
	}

	/**
	 * Quick links on the plugins screen.
	 *
	 * @param array $links Existing links.
	 * @return array
	 */
	public function action_links( $links ) {
		$custom = array(
			'<a href="' . esc_url( admin_url( 'admin.php?page=havato' ) ) . '">' . esc_html( Havato_I18N::t( 'admin_dashboard' ) ) . '</a>',
		);
		return array_merge( $custom, $links );
	}
}

/**
 * Global accessor.
 *
 * @return Havato
 */
function havato() {
	return Havato::instance();
}

havato();

/* -------------------------------------------------------------------------
 * Activation / deactivation / uninstall-safe hooks
 * ---------------------------------------------------------------------- */

register_activation_hook(
	__FILE__,
	function () {
		require_once HAVATO_PATH . 'includes/functions.php';
		require_once HAVATO_PATH . 'includes/class-havato-jalali.php';
		require_once HAVATO_PATH . 'includes/class-havato-i18n.php';
		require_once HAVATO_PATH . 'includes/class-havato-db.php';
		require_once HAVATO_PATH . 'includes/class-havato-roles.php';
		require_once HAVATO_PATH . 'includes/class-havato-settings.php';
		require_once HAVATO_PATH . 'includes/class-havato-cron.php';
		require_once HAVATO_PATH . 'includes/class-havato-owner-auth.php';

		Havato_DB::install();
		Havato_Roles::register_roles();
		Havato_Settings::install_defaults();
		Havato_Cron::schedule_events();

		// Create the café owner sign-in page so owners never need wp-login.php.
		if ( ! get_option( 'havato_owner_auth_page_id' ) ) {
			$page_id = wp_insert_post(
				array(
					'post_title'   => 'Havato — Café owners',
					'post_name'    => 'cafe-owners',
					'post_content' => '[havato_owner_auth]',
					'post_status'  => 'publish',
					'post_type'    => 'page',
				)
			);
			if ( $page_id && ! is_wp_error( $page_id ) ) {
				update_option( 'havato_owner_auth_page_id', (int) $page_id );
			}
		}

		// Flush rewrites so /havato-manifest.json & /havato-sw.js resolve.
		update_option( 'havato_flush_rewrite', 1 );
	}
);

register_deactivation_hook(
	__FILE__,
	function () {
		require_once HAVATO_PATH . 'includes/class-havato-cron.php';
		Havato_Cron::clear_events();
		flush_rewrite_rules();
	}
);
