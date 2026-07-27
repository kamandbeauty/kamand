<?php
/**
 * Front-end shell: the [havato_app] shortcode.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Shortcode + asset loader.
 */
class Havato_Shortcode {

	/**
	 * Set to true when the shortcode is rendered on the current request.
	 *
	 * @var bool
	 */
	private static $rendered = false;

	/**
	 * Hooks.
	 */
	public static function init() {
		add_shortcode( 'havato_app', array( __CLASS__, 'render' ) );
		add_action( 'wp_enqueue_scripts', array( __CLASS__, 'register_assets' ) );
		add_filter( 'body_class', array( __CLASS__, 'body_class' ) );
		add_action( 'template_redirect', array( __CLASS__, 'remember_page' ) );
		add_filter( 'template_include', array( __CLASS__, 'standalone_template' ), 99 );
		add_filter( 'show_admin_bar', array( __CLASS__, 'hide_admin_bar' ) );
	}

	/**
	 * Does the current page contain the shortcode?
	 *
	 * @return bool
	 */
	public static function is_app_page() {
		if ( self::$rendered ) {
			return true;
		}
		if ( ! is_singular() ) {
			return false;
		}
		$post = get_post();
		return $post && has_shortcode( (string) $post->post_content, 'havato_app' );
	}

	/**
	 * Standalone (WebView / PWA) mode?
	 *
	 * @return bool
	 */
	public static function is_standalone() {
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( isset( $_GET['webview'] ) && '1' === sanitize_text_field( wp_unslash( $_GET['webview'] ) ) ) {
			return true;
		}
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( isset( $_GET['havato_standalone'] ) ) {
			return true;
		}
		if ( is_singular() ) {
			$post = get_post();
			if ( $post && get_post_meta( $post->ID, '_havato_standalone', true ) ) {
				return true;
			}
		}
		return false;
	}

	/**
	 * Remember which page holds the app (used by the PWA start_url).
	 */
	public static function remember_page() {
		if ( ! is_singular() ) {
			return;
		}
		$post = get_post();
		if ( ! $post || ! has_shortcode( (string) $post->post_content, 'havato_app' ) ) {
			return;
		}
		if ( (int) get_option( 'havato_app_page_id' ) !== (int) $post->ID ) {
			update_option( 'havato_app_page_id', (int) $post->ID );
		}
	}

	/**
	 * In standalone mode bypass the theme entirely (no header/footer/sidebar).
	 *
	 * @param string $template Template path.
	 * @return string
	 */
	public static function standalone_template( $template ) {
		if ( self::is_app_page() && self::is_standalone() ) {
			return HAVATO_PATH . 'templates/standalone.php';
		}
		return $template;
	}

	/**
	 * Hide the WP admin bar inside the app.
	 *
	 * @param bool $show Current state.
	 * @return bool
	 */
	public static function hide_admin_bar( $show ) {
		if ( self::is_app_page() ) {
			return false;
		}
		return $show;
	}

	/**
	 * Body classes for the app pages.
	 *
	 * @param array $classes Classes.
	 * @return array
	 */
	public static function body_class( $classes ) {
		if ( self::is_app_page() ) {
			$classes[] = 'havato-page';
			$classes[] = 'havato-' . Havato_I18N::dir();
			if ( self::is_standalone() ) {
				$classes[] = 'havato-standalone';
			}
		}
		return $classes;
	}

	/**
	 * Register (not enqueue) the assets.
	 */
	public static function register_assets() {
		wp_register_style(
			'havato-vazirmatn',
			'https://cdn.jsdelivr.net/gh/rastikerdar/vazirmatn@v33.003/Vazirmatn-font-face.css',
			array(),
			'33.003'
		);

		wp_register_style(
			'leaflet',
			'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
			array(),
			'1.9.4'
		);

		wp_register_script(
			'leaflet',
			'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
			array(),
			'1.9.4',
			true
		);

		wp_register_script(
			'havato-gis',
			'https://accounts.google.com/gsi/client',
			array(),
			null,
			true
		);

		wp_register_style(
			'havato-app',
			HAVATO_URL . 'assets/css/havato-app.css',
			array( 'havato-vazirmatn', 'leaflet' ),
			HAVATO_VERSION
		);

		wp_register_script(
			'havato-app',
			HAVATO_URL . 'assets/js/havato-app.js',
			array( 'leaflet' ),
			HAVATO_VERSION,
			true
		);
	}

	/**
	 * Enqueue everything and pass the boot data to JS.
	 */
	public static function enqueue() {
		self::register_assets();

		wp_enqueue_style( 'havato-app' );
		wp_enqueue_script( 'havato-app' );

		if ( Havato_Google_Auth::is_configured() ) {
			wp_enqueue_script( 'havato-gis' );
		}

		$lang = Havato_I18N::current_lang();

		wp_localize_script(
			'havato-app',
			'HAVATO_BOOT',
			array(
				'rest'         => esc_url_raw( rest_url( Havato_REST::NS ) ),
				'nonce'        => wp_create_nonce( 'wp_rest' ),
				'lang'         => $lang,
				'dir'          => Havato_I18N::dir( $lang ),
				'allowSwitch'  => (bool) Havato_Settings::get( 'allow_lang_switch', 1 ),
				'i18n'         => Havato_I18N::bundle(),
				'loggedIn'     => is_user_logged_in(),
				'role'         => havato_user_role(),
				'googleClient' => Havato_Settings::get( 'google_client_id', '' ),
				'googleReady'  => Havato_Google_Auth::is_configured(),
				'wooActive'    => havato_woo_active(),
				'standalone'   => self::is_standalone(),
				'swUrl'        => esc_url_raw( Havato_PWA::url( 'sw' ) ),
				'appUrl'       => esc_url_raw( Havato_PWA::app_url() ),
				'homeUrl'      => esc_url_raw( home_url( '/' ) ),
				// A real WordPress logout URL (nonced). The app calls the REST
				// endpoint first, but falls back to this when the REST call
				// fails, so signing out can never silently do nothing.
				'logoutUrl'    => esc_url_raw( wp_logout_url( home_url( '/' ) ) ),
				'interests'    => havato_interest_tags(),
				// The profile editor renders its country/city pickers straight
				// from this map. It used to be sent only in the bootstrap REST
				// response while the UI read it off the boot payload, so the
				// lists were always empty and no city could ever be chosen.
				'locations'    => havato_locations(),
				'map'          => array(
					'lat'  => (float) Havato_Settings::get( 'map_center_lat', 35.7219 ),
					'lng'  => (float) Havato_Settings::get( 'map_center_lng', 51.3347 ),
					'zoom' => (int) Havato_Settings::get( 'map_zoom', 12 ),
				),
			)
		);
	}

	/**
	 * Render the app shell.
	 *
	 * @param array $atts Shortcode attributes.
	 * @return string
	 */
	public static function render( $atts = array() ) {
		$atts = shortcode_atts(
			array(
				'view' => 'auto', // auto | client | owner.
			),
			$atts,
			'havato_app'
		);

		// Self-healing DB check on every render.
		Havato_DB::ensure_tables();

		self::$rendered = true;
		self::enqueue();

		$lang = Havato_I18N::current_lang();
		$dir  = Havato_I18N::dir( $lang );

		ob_start();
		include HAVATO_PATH . 'templates/app.php';
		return ob_get_clean();
	}
}
