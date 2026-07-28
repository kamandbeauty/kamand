<?php
/**
 * Custom roles + admin user-list columns.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Role registrar.
 */
class Havato_Roles {

	/**
	 * Hook up the users.php columns.
	 */
	public static function init() {
		// Priority 1: WooCommerce also bounces these users on admin_init, and
		// its target (the shop's My Account page) is the wrong destination for
		// a gatherer. Running first means our redirect is the one that fires.
		add_action( 'admin_init', array( __CLASS__, 'block_gatherers' ), 1 );
		// Refuse the login itself, so a banned person cannot get a fresh
		// cookie even though the REST layer would also stop them.
		add_filter( 'authenticate', array( __CLASS__, 'refuse_banned' ), 30, 1 );
		add_filter( 'manage_users_columns', array( __CLASS__, 'user_columns' ) );
		add_filter( 'manage_users_custom_column', array( __CLASS__, 'user_column_content' ), 10, 3 );

		// WooCommerce locks every user without `edit_posts`, `manage_woocommerce`
		// or `view_admin_dashboard` out of wp-admin and bounces them to its
		// My Account page. A café owner has none of those, so on a shop site
		// the owner panel became unreachable. Both filters run late so we win
		// over the shop's own customisations.
		add_filter( 'woocommerce_prevent_admin_access', array( __CLASS__, 'allow_owner_admin_access' ), 99 );
		add_filter( 'woocommerce_disable_admin_bar', array( __CLASS__, 'allow_owner_admin_bar' ), 99 );
	}

	/**
	 * Let café owners reach wp-admin on a WooCommerce site.
	 *
	 * Only the owner panel is reachable anyway — Havato_Owner_Admin::block_dashboard()
	 * redirects every other admin screen — so this widens nothing beyond the
	 * panel the role exists for.
	 *
	 * @param bool $prevent Whether WooCommerce wants to block the request.
	 * @return bool
	 */
	public static function allow_owner_admin_access( $prevent ) {
		return self::is_panel_user() ? false : $prevent;
	}

	/**
	 * Keep the admin bar for café owners on a WooCommerce site.
	 *
	 * @param bool $disable Whether WooCommerce wants to hide the bar.
	 * @return bool
	 */
	public static function allow_owner_admin_bar( $disable ) {
		return self::is_panel_user() ? false : $disable;
	}

	/**
	 * Is the current user someone who owns a wp-admin panel here?
	 *
	 * @return bool
	 */
	private static function is_panel_user() {
		if ( ! is_user_logged_in() ) {
			return false;
		}
		if ( current_user_can( 'manage_options' ) ) {
			return true;
		}
		return in_array( 'cafe_owner', (array) wp_get_current_user()->roles, true );
	}

	/**
	 * Stop a banned account from authenticating.
	 *
	 * Runs after WordPress has resolved the user, so it applies to any login
	 * route — the branded owner page, wp-login.php or Google sign-in.
	 *
	 * @param WP_User|WP_Error|null $user Resolved user.
	 * @return WP_User|WP_Error|null
	 */
	public static function refuse_banned( $user ) {
		if ( $user instanceof WP_User && havato_is_banned( $user->ID ) ) {
			return new WP_Error( 'havato_banned', Havato_I18N::t( 'account_banned' ) );
		}
		return $user;
	}

	/**
	 * Register the two native roles (idempotent, runs on init).
	 */
	public static function register_roles() {
		$gatherer = get_role( 'gatherer' );
		if ( ! $gatherer ) {
			add_role(
				'gatherer',
				'Havato Gatherer',
				array(
					'read'          => true,
					'upload_files'  => true,
					'havato_join'   => true,
				)
			);
		}

		$owner = get_role( 'cafe_owner' );
		if ( ! $owner ) {
			add_role(
				'cafe_owner',
				'Havato Café Owner',
				array(
					'read'              => true,
					'upload_files'      => true,
					'havato_manage_venue' => true,
				)
			);
		}

		// Make sure the administrator can always do everything Havato related.
		$admin = get_role( 'administrator' );
		if ( $admin ) {
			$admin->add_cap( 'havato_join' );
			$admin->add_cap( 'havato_manage_venue' );
			$admin->add_cap( 'havato_manage_platform' );
		}
	}

	/**
	 * Gatherers have no business in wp-admin: their whole experience is the
	 * [havato_app] web-app. Bounce them back to it rather than showing a bare
	 * WordPress dashboard. (Café owners keep access — that is their panel now.)
	 */
	public static function block_gatherers() {
		if ( ! is_user_logged_in() || wp_doing_ajax() ) {
			return;
		}

		$user = wp_get_current_user();
		if ( ! in_array( 'gatherer', (array) $user->roles, true ) || user_can( $user, 'manage_options' ) ) {
			return;
		}

		// Media endpoints must stay reachable so gallery uploads keep working.
		global $pagenow;
		if ( in_array( (string) $pagenow, array( 'admin-post.php', 'admin-ajax.php', 'async-upload.php', 'media-upload.php', 'profile.php' ), true ) ) {
			return;
		}

		$page_id = (int) get_option( 'havato_app_page_id' );
		wp_safe_redirect( $page_id ? get_permalink( $page_id ) : home_url( '/' ) );
		exit;
	}

	/**
	 * Add the two monitoring columns to /wp-admin/users.php.
	 *
	 * @param array $cols Existing columns.
	 * @return array
	 */
	public static function user_columns( $cols ) {
		$cols['havato_role']   = Havato_I18N::t( 'havato_role' );
		$cols['havato_venue']  = Havato_I18N::t( 'venue_status' );
		return $cols;
	}

	/**
	 * Render the column values.
	 *
	 * @param string $output  Current output.
	 * @param string $column  Column key.
	 * @param int    $user_id User id.
	 * @return string
	 */
	public static function user_column_content( $output, $column, $user_id ) {
		if ( 'havato_role' === $column ) {
			$role = havato_user_role( $user_id );

			// Make a ban obvious wherever users are listed.
			$flag = havato_is_banned( $user_id )
				? '<span class="hv-user-badge hv-badge-orange">⛔ ' . esc_html( Havato_I18N::t( 'banned_badge' ) ) . '</span> '
				: '';
			$map  = array(
				'gatherer'   => array( 'label' => 'Gatherer', 'class' => 'hv-badge-blue' ),
				'cafe_owner' => array( 'label' => 'Café Owner', 'class' => 'hv-badge-orange' ),
				'admin'      => array( 'label' => 'Administrator', 'class' => 'hv-badge-green' ),
				'guest'      => array( 'label' => '—', 'class' => 'hv-badge-gray' ),
			);
			$info = isset( $map[ $role ] ) ? $map[ $role ] : $map['guest'];
			return $flag . '<span class="hv-user-badge ' . esc_attr( $info['class'] ) . '">' . esc_html( $info['label'] ) . '</span>';
		}

		if ( 'havato_venue' === $column ) {
			global $wpdb;
			Havato_DB::ensure_tables();
			$table = Havato_DB::table( 'venues' );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$venue = $wpdb->get_row( $wpdb->prepare( "SELECT name, verified FROM $table WHERE manager_id=%d LIMIT 1", (int) $user_id ), ARRAY_A );

			if ( ! $venue ) {
				return '<span class="hv-user-badge hv-badge-gray">—</span>';
			}

			$name  = $venue['name'];
			$badge = $venue['verified']
				? '<span class="hv-user-badge hv-badge-green">✓ ' . esc_html( Havato_I18N::t( 'verified_venue' ) ) . '</span>'
				: '<span class="hv-user-badge hv-badge-orange">' . esc_html( Havato_I18N::t( 'badge_pending' ) ) . '</span>';

			return esc_html( $name ) . '<br>' . $badge;
		}

		return $output;
	}
}
