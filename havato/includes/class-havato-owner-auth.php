<?php
/**
 * Dedicated café-owner sign-in / sign-up page.
 *
 * Café owners never touch wp-login.php: that URL is the default target of
 * every WordPress brute-force bot, and it exposes WordPress branding to a
 * business partner. This page is branded, bilingual, throttled, and — most
 * importantly — the endpoint behind it only accepts the `cafe_owner` role, so
 * it can never be used to sign in an administrator.
 *
 * Shortcode: [havato_owner_auth]
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Owner authentication front-end.
 */
class Havato_Owner_Auth {

	/**
	 * Option holding the page id, so redirects can find it.
	 */
	const PAGE_OPTION = 'havato_owner_auth_page_id';

	/**
	 * Hooks.
	 */
	public static function init() {
		add_shortcode( 'havato_owner_auth', array( __CLASS__, 'render' ) );
		add_action( 'template_redirect', array( __CLASS__, 'remember_page' ) );
		add_action( 'login_init', array( __CLASS__, 'guard_wp_login' ) );
		add_action( 'wp_enqueue_scripts', array( __CLASS__, 'register_assets' ) );
	}

	/**
	 * URL of the owner auth page, falling back to wp-login.php if the page has
	 * not been created yet (so owners are never locked out).
	 *
	 * @return string
	 */
	public static function url() {
		$page_id = (int) get_option( self::PAGE_OPTION );
		if ( $page_id && 'publish' === get_post_status( $page_id ) ) {
			return get_permalink( $page_id );
		}
		return wp_login_url();
	}

	/**
	 * Has the site owner actually created the page?
	 *
	 * @return bool
	 */
	public static function is_configured() {
		$page_id = (int) get_option( self::PAGE_OPTION );
		return $page_id && 'publish' === get_post_status( $page_id );
	}

	/**
	 * Remember which page carries the shortcode.
	 */
	public static function remember_page() {
		if ( ! is_singular() ) {
			return;
		}
		$post = get_post();
		if ( ! $post || ! has_shortcode( (string) $post->post_content, 'havato_owner_auth' ) ) {
			return;
		}
		if ( (int) get_option( self::PAGE_OPTION ) !== (int) $post->ID ) {
			update_option( self::PAGE_OPTION, (int) $post->ID );
		}
	}

	/**
	 * Keep non-administrators away from wp-login.php.
	 *
	 * Administrators are deliberately still allowed through: locking everyone
	 * out of the only recovery door would be dangerous if a plugin or theme
	 * ever broke the custom page.
	 */
	public static function guard_wp_login() {
		if ( ! self::is_configured() ) {
			return;
		}

		// Never interfere with logout, password resets or the postpass flow.
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$action = isset( $_REQUEST['action'] ) ? sanitize_key( wp_unslash( $_REQUEST['action'] ) ) : 'login';
		if ( 'login' !== $action ) {
			return;
		}

		// Allow an explicit escape hatch for administrators:
		// wp-login.php?havato_admin=1
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( isset( $_GET['havato_admin'] ) ) {
			return;
		}

		// A POST is the actual credential submission; let WordPress handle it
		// so admins signing in through the escape hatch still work.
		if ( 'POST' === ( isset( $_SERVER['REQUEST_METHOD'] ) ? strtoupper( sanitize_text_field( wp_unslash( $_SERVER['REQUEST_METHOD'] ) ) ) : 'GET' ) ) {
			return;
		}

		wp_safe_redirect( self::url() );
		exit;
	}

	/**
	 * Register the assets (shared with the main app).
	 */
	public static function register_assets() {
		Havato_Shortcode::register_assets();
	}

	/**
	 * Render the sign-in / sign-up screen.
	 *
	 * @return string
	 */
	public static function render() {
		Havato_DB::ensure_tables();

		// Already signed in as an owner? Go straight to the panel.
		if ( is_user_logged_in() ) {
			$user = wp_get_current_user();
			if ( in_array( 'cafe_owner', (array) $user->roles, true ) || user_can( $user, 'manage_options' ) ) {
				return sprintf(
					'<div class="hv-owner-auth"><div class="hv-auth-card hv-glass"><h2 class="hv-auth-title">%s</h2>'
					. '<a class="hv-btn hv-btn-blue hv-btn-block" href="%s">%s</a></div></div>',
					esc_html( Havato_I18N::t( 'owner_panel' ) ),
					esc_url( admin_url( 'admin.php?page=havato-venue' ) ),
					esc_html( Havato_I18N::t( 'owner_panel' ) )
				);
			}
		}

		wp_enqueue_style( 'havato-app' );
		wp_enqueue_script( 'havato-owner-auth', HAVATO_URL . 'assets/js/havato-owner-auth.js', array(), HAVATO_VERSION, true );

		$lang = Havato_I18N::current_lang();

		wp_localize_script(
			'havato-owner-auth',
			'HAVATO_AUTH',
			array(
				'rest'      => esc_url_raw( rest_url( Havato_REST::NS ) ),
				'nonce'     => wp_create_nonce( 'wp_rest' ),
				'lang'      => $lang,
				'dir'       => Havato_I18N::dir( $lang ),
				'i18n'      => Havato_I18N::flat( $lang ),
				'locations' => havato_locations(),
				'panelUrl'  => esc_url_raw( admin_url( 'admin.php?page=havato-venue' ) ),
				'lostPass'  => esc_url_raw( wp_lostpassword_url() ),
			)
		);

		ob_start();
		include HAVATO_PATH . 'templates/owner-auth.php';
		return ob_get_clean();
	}
}
