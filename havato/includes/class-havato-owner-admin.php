<?php
/**
 * Café owner panel inside wp-admin (desktop).
 *
 * The mobile owner portal was removed from the web-app: a café is run from a
 * counter, not a phone. Everything the owner needs now lives here, reusing the
 * exact same REST endpoints (owner/dashboard, owner/events, owner/menu, …) so
 * there is a single source of truth for the business logic.
 *
 * The `cafe_owner` role is also locked down to just this panel plus their own
 * profile — see restrict_menus() and block_dashboard().
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Owner-facing wp-admin screens.
 */
class Havato_Owner_Admin {

	/**
	 * Hooks.
	 */
	public static function init() {
		add_action( 'admin_menu', array( __CLASS__, 'menu' ), 9 );
		add_action( 'admin_post_havato_owner_action', array( __CLASS__, 'handle_post' ) );
		add_action( 'admin_notices', array( __CLASS__, 'notices' ) );
		add_action( 'admin_enqueue_scripts', array( __CLASS__, 'assets' ) );

		// Lock the role down to its own panel.
		add_action( 'admin_menu', array( __CLASS__, 'restrict_menus' ), 999 );
		add_action( 'admin_init', array( __CLASS__, 'block_dashboard' ) );
		add_action( 'admin_bar_menu', array( __CLASS__, 'clean_admin_bar' ), 999 );
		add_filter( 'show_admin_bar', array( __CLASS__, 'admin_bar_visibility' ) );
		add_action( 'admin_head', array( __CLASS__, 'hide_screen_clutter' ) );

		// Send owners straight to their panel after logging in.
		add_filter( 'login_redirect', array( __CLASS__, 'login_redirect' ), 10, 3 );
	}

	/**
	 * Is the current user a café owner (and not an administrator)?
	 *
	 * Administrators keep the full WordPress experience so they can still
	 * manage the site.
	 *
	 * @return bool
	 */
	public static function is_owner() {
		if ( ! is_user_logged_in() || current_user_can( 'manage_options' ) ) {
			return false;
		}
		return in_array( 'cafe_owner', (array) wp_get_current_user()->roles, true );
	}

	/**
	 * Register the owner menu.
	 */
	public static function menu() {
		if ( ! self::is_owner() ) {
			return;
		}

		$cap = 'read';

		add_menu_page(
			Havato_I18N::t( 'owner_panel' ),
			Havato_I18N::t( 'owner_panel' ),
			$cap,
			'havato-venue',
			array( __CLASS__, 'page_dashboard' ),
			'dashicons-coffee',
			3
		);

		$pages = array(
			'havato-venue'          => array( 'tab_dashboard', 'page_dashboard' ),
			'havato-venue-events'   => array( 'tab_venue_events', 'page_events' ),
			'havato-venue-tables'   => array( 'tab_tables', 'page_tables' ),
			'havato-venue-menu'     => array( 'tab_menu_builder', 'page_menu' ),
			'havato-venue-settings' => array( 'tab_venue_settings', 'page_settings' ),
		);

		foreach ( $pages as $slug => $conf ) {
			add_submenu_page(
				'havato-venue',
				Havato_I18N::t( $conf[0] ),
				Havato_I18N::t( $conf[0] ),
				$cap,
				$slug,
				array( __CLASS__, $conf[1] )
			);
		}
	}

	/**
	 * Strip every menu the owner has no business seeing.
	 *
	 * Capability checks already block most of it; this removes the leftovers
	 * (Dashboard, Posts, Media, Comments, Tools) so the sidebar shows only the
	 * Havato panel and their own profile.
	 */
	public static function restrict_menus() {
		if ( ! self::is_owner() ) {
			return;
		}

		global $menu;

		$allowed = array( 'havato-venue', 'profile.php' );

		foreach ( (array) $menu as $key => $item ) {
			$slug = isset( $item[2] ) ? $item[2] : '';
			if ( '' === $slug ) {
				continue;
			}
			// Keep separators out of the way but do not treat them as pages.
			if ( false !== strpos( (string) $slug, 'separator' ) ) {
				unset( $menu[ $key ] );
				continue;
			}
			if ( ! in_array( $slug, $allowed, true ) ) {
				remove_menu_page( $slug );
			}
		}

		// Media is hidden from the sidebar, but uploads must keep working for
		// cover / menu photos, so the capability itself is left intact.
		remove_submenu_page( 'profile.php', 'user-edit.php' );
	}

	/**
	 * Owners have no use for the WordPress dashboard or the post editor:
	 * bounce them to their own panel instead of showing an empty screen.
	 */
	public static function block_dashboard() {
		if ( ! self::is_owner() || wp_doing_ajax() ) {
			return;
		}

		global $pagenow;

		$allowed_files = array( 'admin.php', 'profile.php', 'admin-post.php', 'admin-ajax.php', 'async-upload.php', 'media-upload.php' );

		// Any admin.php request must target a Havato page.
		if ( 'admin.php' === $pagenow ) {
			// phpcs:ignore WordPress.Security.NonceVerification.Recommended
			$page = isset( $_GET['page'] ) ? sanitize_key( wp_unslash( $_GET['page'] ) ) : '';
			if ( 0 !== strpos( $page, 'havato-venue' ) ) {
				wp_safe_redirect( admin_url( 'admin.php?page=havato-venue' ) );
				exit;
			}
			return;
		}

		if ( ! in_array( (string) $pagenow, $allowed_files, true ) ) {
			wp_safe_redirect( admin_url( 'admin.php?page=havato-venue' ) );
			exit;
		}
	}

	/**
	 * Trim the admin bar down to the essentials.
	 *
	 * @param WP_Admin_Bar $bar Admin bar.
	 */
	public static function clean_admin_bar( $bar ) {
		if ( ! self::is_owner() ) {
			return;
		}
		foreach ( array( 'wp-logo', 'comments', 'new-content', 'updates', 'customize' ) as $node ) {
			$bar->remove_node( $node );
		}
	}

	/**
	 * Hide the admin bar on the front-end for owners (they have no site role).
	 *
	 * @param bool $show Current state.
	 * @return bool
	 */
	public static function admin_bar_visibility( $show ) {
		if ( self::is_owner() && ! is_admin() ) {
			return false;
		}
		return $show;
	}

	/**
	 * Hide help tabs / screen options that would only confuse the owner.
	 */
	public static function hide_screen_clutter() {
		if ( ! self::is_owner() ) {
			return;
		}
		echo '<style>#screen-meta-links,#contextual-help-link-wrap,#screen-options-link-wrap{display:none!important}</style>';
	}

	/**
	 * Land owners on their panel after login.
	 *
	 * @param string           $redirect Default redirect.
	 * @param string           $request  Requested redirect.
	 * @param WP_User|WP_Error $user     User.
	 * @return string
	 */
	public static function login_redirect( $redirect, $request, $user ) {
		if ( $user instanceof WP_User
			&& in_array( 'cafe_owner', (array) $user->roles, true )
			&& ! user_can( $user, 'manage_options' ) ) {
			return admin_url( 'admin.php?page=havato-venue' );
		}
		return $redirect;
	}

	/**
	 * Load the desktop stylesheet / script on owner screens only.
	 *
	 * @param string $hook Screen hook.
	 */
	public static function assets( $hook ) {
		if ( ! self::is_owner() || false === strpos( $hook, 'havato-venue' ) ) {
			return;
		}

		wp_enqueue_media();

		wp_enqueue_style( 'havato-admin', HAVATO_URL . 'assets/css/havato-admin.css', array(), HAVATO_VERSION );
		wp_enqueue_style( 'leaflet', 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css', array(), '1.9.4' );
		wp_enqueue_script( 'leaflet', 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js', array(), '1.9.4', true );

		wp_enqueue_script(
			'havato-owner-admin',
			HAVATO_URL . 'assets/js/havato-owner-admin.js',
			array( 'leaflet' ),
			HAVATO_VERSION,
			true
		);

		$lang = Havato_I18N::current_lang();

		wp_localize_script(
			'havato-owner-admin',
			'HAVATO_OWNER',
			array(
				'rest'      => esc_url_raw( rest_url( Havato_REST::NS ) ),
				'nonce'     => wp_create_nonce( 'wp_rest' ),
				'lang'      => $lang,
				'dir'       => Havato_I18N::dir( $lang ),
				'i18n'      => Havato_I18N::flat( $lang ),
				'locations' => havato_locations(),
				'map'       => array(
					'lat'  => (float) Havato_Settings::get( 'map_center_lat', 35.7219 ),
					'lng'  => (float) Havato_Settings::get( 'map_center_lng', 51.3347 ),
					'zoom' => (int) Havato_Settings::get( 'map_zoom', 12 ),
				),
			)
		);
	}

	/* =====================================================================
	 * Shared chrome
	 * ================================================================== */

	/**
	 * The venue owned by the current user.
	 *
	 * @return array|null
	 */
	private static function venue() {
		return Havato_REST::owner_venue( get_current_user_id() );
	}

	/**
	 * Page header + tab strip.
	 *
	 * @param string     $title Page title.
	 * @param array|null $venue Venue row.
	 */
	private static function head( $title, $venue ) {
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$current = isset( $_GET['page'] ) ? sanitize_key( wp_unslash( $_GET['page'] ) ) : 'havato-venue';

		$tabs = array(
			'havato-venue'          => Havato_I18N::t( 'tab_dashboard' ),
			'havato-venue-events'   => Havato_I18N::t( 'tab_venue_events' ),
			'havato-venue-tables'   => Havato_I18N::t( 'tab_tables' ),
			'havato-venue-menu'     => Havato_I18N::t( 'tab_menu_builder' ),
			'havato-venue-settings' => Havato_I18N::t( 'tab_venue_settings' ),
		);

		$name = $venue ? $venue['name'] : Havato_I18N::t( 'owner_panel' );

		echo '<div class="wrap hv-admin hv-owner">';
		echo '<div class="hv-admin-head"><div class="hv-admin-brand">';
		echo '<span class="hv-admin-logo">H</span><div>';
		echo '<h1>' . esc_html( $title ) . '</h1>';
		echo '<p>' . esc_html( $name ) . '</p>';
		echo '</div></div></div>';

		if ( $venue && ! (int) $venue['verified'] ) {
			echo '<div class="hv-adm-alert is-orange">' . esc_html( Havato_I18N::t( 'owner_pending_notice' ) ) . '</div>';
		}

		echo '<nav class="hv-admin-tabs">';
		foreach ( $tabs as $slug => $label ) {
			printf(
				'<a class="hv-admin-tab%s" href="%s">%s</a>',
				$slug === $current ? ' is-active' : '',
				esc_url( admin_url( 'admin.php?page=' . $slug ) ),
				esc_html( $label )
			);
		}
		echo '</nav>';
	}

	/**
	 * Close the wrapper.
	 */
	private static function foot() {
		echo '</div>';
	}

	/**
	 * Shown when the account has no venue attached yet.
	 */
	private static function no_venue() {
		echo '<div class="hv-adm-card"><p class="hv-adm-muted">' .
			esc_html( Havato_I18N::t( 'error_generic' ) ) . '</p></div>';
		self::foot();
	}

	/* =====================================================================
	 * Page 1 — dashboard
	 * ================================================================== */

	/**
	 * KPI dashboard.
	 */
	public static function page_dashboard() {
		global $wpdb;
		Havato_DB::ensure_tables();

		$venue = self::venue();
		self::head( Havato_I18N::t( 'tab_dashboard' ), $venue );

		if ( ! $venue ) {
			self::no_venue();
			return;
		}

		$events = Havato_DB::table( 'events' );
		$regs   = Havato_DB::table( 'event_registrations' );
		$lang   = Havato_I18N::current_lang();

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$upcoming = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM $events WHERE venue_id=%s AND event_date >= CURDATE()", $venue['id'] ) );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$checked = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM $regs r INNER JOIN $events e ON e.id=r.event_id WHERE e.venue_id=%s AND r.checked_in=1", $venue['id'] ) );

		$fmt = function ( $n ) use ( $lang ) {
			return 'fa' === $lang ? Havato_Jalali::fa_digits( number_format( (int) $n ) ) : number_format( (int) $n );
		};

		// An unverified café is invisible to guests, and the single biggest
		// thing that speeds up approval is a photo of the shopfront, so ask
		// for it prominently until it is supplied.
		if ( ! (int) $venue['verified'] ) {
			self::storefront_prompt( $venue );
		}

		echo '<div class="hv-adm-stats">';
		Havato_Admin_UI::stat_card( Havato_I18N::t( 'utilization' ), $fmt( $venue['utilization'] ) . '%', 'blue', 'chart-bar' );
		Havato_Admin_UI::stat_card( Havato_I18N::t( 'guests_routed' ), $fmt( $venue['guests_routed'] ), 'green', 'groups' );
		Havato_Admin_UI::stat_card( Havato_I18N::t( 'tab_venue_events' ), $fmt( $upcoming ), 'orange', 'calendar-alt' );
		Havato_Admin_UI::stat_card( Havato_I18N::t( 'check_in' ), $fmt( $checked ), 'pink', 'yes-alt' );
		echo '</div>';

		// Upcoming tables at a glance.
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT e.*, (SELECT COALESCE(SUM(r.seats),0) FROM $regs r WHERE r.event_id=e.id AND r.status <> 'cancelled') AS taken
				 FROM $events e WHERE e.venue_id=%s AND e.event_date >= CURDATE()
				 ORDER BY e.event_date ASC LIMIT 10",
				$venue['id']
			),
			ARRAY_A
		);

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'explore_title' ) ) . '</h2>';
		self::events_table( $rows, $lang, false );
		echo '</div>';

		self::foot();
	}

	/**
	 * Storefront-photo request shown to unverified cafés.
	 *
	 * @param array $venue Venue row.
	 */
	private static function storefront_prompt( $venue ) {
		$has = ! empty( $venue['storefront_photo'] );

		echo '<div class="hv-adm-card hv-adm-storefront' . ( $has ? ' is-done' : '' ) . '">';
		echo '<div class="hv-adm-storefront-body">';
		echo '<span class="hv-adm-stat-icon is-orange"><span class="dashicons dashicons-camera"></span></span>';
		echo '<div>';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'storefront_title' ) ) . '</h2>';
		echo '<p class="hv-adm-muted">' . esc_html(
			$has ? Havato_I18N::t( 'storefront_received' ) : Havato_I18N::t( 'storefront_hint' )
		) . '</p>';
		echo '</div></div>';

		echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '">';
		wp_nonce_field( 'havato_owner', 'havato_owner_nonce' );
		echo '<input type="hidden" name="action" value="havato_owner_action">';
		echo '<input type="hidden" name="havato_action" value="save_storefront">';
		echo '<input type="hidden" name="storefront_photo" id="hv-storefront-url" value="' .
			esc_attr( $venue['storefront_photo'] ) . '">';

		if ( $has ) {
			echo '<img class="hv-adm-storefront-img" src="' . esc_url( $venue['storefront_photo'] ) . '" alt="">';
		}

		echo '<p class="hv-adm-storefront-actions">';
		echo '<button type="button" class="hv-adm-btn hv-adm-btn-ghost" id="hv-storefront-pick">' .
			esc_html( $has ? Havato_I18N::t( 'edit' ) : Havato_I18N::t( 'upload_photo' ) ) . '</button> ';
		echo '<button type="submit" class="hv-adm-btn hv-adm-btn-green" id="hv-storefront-save"' .
			( $has ? '' : ' disabled' ) . '>' . esc_html( Havato_I18N::t( 'save' ) ) . '</button>';
		echo '</p>';
		echo '</form></div>';
	}

	/* =====================================================================
	 * Page 2 — events + check-in
	 * ================================================================== */

	/**
	 * Venue events.
	 */
	public static function page_events() {
		global $wpdb;
		Havato_DB::ensure_tables();

		$venue = self::venue();
		self::head( Havato_I18N::t( 'tab_venue_events' ), $venue );

		if ( ! $venue ) {
			self::no_venue();
			return;
		}

		$lang   = Havato_I18N::current_lang();
		$events = Havato_DB::table( 'events' );
		$regs   = Havato_DB::table( 'event_registrations' );

		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$open_event = isset( $_GET['event'] ) ? sanitize_text_field( wp_unslash( $_GET['event'] ) ) : '';

		if ( $open_event ) {
			self::event_detail( $venue, $open_event, $lang );
			self::foot();
			return;
		}

		// New-table form.
		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'add_item' ) ) . '</h2>';
		echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '">';
		wp_nonce_field( 'havato_owner', 'havato_owner_nonce' );
		echo '<input type="hidden" name="action" value="havato_owner_action">';
		echo '<input type="hidden" name="havato_action" value="create_event">';
		echo '<div class="hv-adm-inline-form">';

		echo '<label class="hv-adm-grow">' . esc_html( Havato_I18N::t( 'event_title' ) ) .
			'<input type="text" name="title" maxlength="120" placeholder="' .
			esc_attr( Havato_I18N::t( 'event_title_hint' ) ) . '"></label>';
		echo '<label>' . esc_html( Havato_I18N::t( 'col_date' ) ) .
			'<input type="date" name="event_date" required value="' . esc_attr( gmdate( 'Y-m-d', strtotime( '+1 day' ) ) ) . '"></label>';
		echo '<label>' . esc_html( Havato_I18N::t( 'quiet_hours' ) ) .
			'<input type="time" name="event_time" required value="19:00"></label>';
		// Table pickers, or a plain seat count if no furniture is defined yet.
		$tables = Havato_REST::venue_tables( $venue['id'] );

		if ( empty( $tables ) ) {
			echo '<label>' . esc_html( Havato_I18N::t( 'seats_left' ) ) .
				'<input type="number" name="max_capacity" min="2" max="60" value="6"></label>';
		}
		echo '<label>' . esc_html( Havato_I18N::t( 'atmosphere' ) ) . '<select name="budget_tier">';
		foreach ( array( 'low', 'medium', 'high' ) as $tier ) {
			printf(
				'<option value="%s"%s>%s</option>',
				esc_attr( $tier ),
				selected( $tier, 'medium', false ),
				esc_html( Havato_I18N::t( 'budget_' . $tier ) )
			);
		}
		echo '</select></label>';
		echo '<label class="hv-adm-grow">' . esc_html( Havato_I18N::t( 'event_theme' ) ) .
			'<input type="text" name="theme" maxlength="120" placeholder="' .
			esc_attr( Havato_I18N::t( 'event_theme_hint' ) ) . '"></label>';

		// Optional event photo (falls back to the café cover).
		echo '<label>' . esc_html( Havato_I18N::t( 'event_image' ) ) .
			'<span class="hv-adm-imgpick">' .
				'<input type="hidden" name="image" id="hv-event-image">' .
				'<img id="hv-event-image-preview" alt="" hidden>' .
				'<button type="button" class="hv-adm-btn hv-adm-btn-ghost" id="hv-event-image-pick">' .
					esc_html( Havato_I18N::t( 'upload_photo' ) ) . '</button>' .
			'</span></label>';

		echo '</div>'; // close the field row before the table pickers.

		if ( ! empty( $tables ) ) {
			echo '<div class="hv-adm-tablepick">';
			echo '<span class="hv-adm-tablepick-label">' . esc_html( Havato_I18N::t( 'event_tables_pick' ) ) . '</span>';
			echo '<div class="hv-adm-tablepick-grid">';

			foreach ( $tables as $i => $row ) {
				$name = sprintf( Havato_I18N::t( 'table_number_label' ), $row['table_number'] );
				if ( '' !== $row['label'] ) {
					$name .= ' — ' . $row['label'];
				}

				echo '<label class="hv-adm-tablepick-item">';
				printf(
					'<input type="checkbox" name="tables[%1$d][use]" value="1" data-seats="%2$d">',
					(int) $i,
					(int) $row['seats']
				);
				printf( '<input type="hidden" name="tables[%d][table_id]" value="%d">', (int) $i, (int) $row['id'] );
				echo '<span class="hv-adm-tablepick-name">' . esc_html( $name ) . '</span>';
				echo '<span class="hv-adm-muted">' .
					esc_html( sprintf( '%d %s', $row['seats'], Havato_I18N::t( 'table_seats' ) ) ) . '</span>';
				// Each row is now one physical table, so the quantity is always 1.
				printf( '<input type="hidden" name="tables[%d][quantity]" value="1">', (int) $i );
				echo '</label>';
			}

			echo '</div>';
			echo '<p class="hv-adm-muted" id="hv-event-capacity"></p>';
			echo '</div>';
		}

		echo '<p><button type="submit" class="hv-adm-btn hv-adm-btn-blue">' .
			esc_html( Havato_I18N::t( 'save' ) ) . '</button></p>';
		echo '</form></div>';

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT e.*, (SELECT COALESCE(SUM(r.seats),0) FROM $regs r WHERE r.event_id=e.id AND r.status <> 'cancelled') AS taken
				 FROM $events e WHERE e.venue_id=%s ORDER BY e.event_date DESC LIMIT 60",
				$venue['id']
			),
			ARRAY_A
		);

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'tab_venue_events' ) ) . '</h2>';
		self::events_table( $rows, $lang, true );
		echo '</div>';

		self::foot();
	}

	/**
	 * Reusable events table.
	 *
	 * @param array  $rows        Event rows.
	 * @param string $lang        Language.
	 * @param bool   $with_manage Show the manage link.
	 */
	private static function events_table( $rows, $lang, $with_manage ) {
		if ( empty( $rows ) ) {
			echo '<p class="hv-adm-muted">' . esc_html( Havato_I18N::t( 'empty_state' ) ) . '</p>';
			return;
		}

		echo '<table class="hv-adm-table"><thead><tr>';
		echo '<th>' . esc_html( Havato_I18N::t( 'col_date' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'seats_left' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'col_status' ) ) . '</th>';
		echo '<th></th></tr></thead><tbody>';

		foreach ( $rows as $row ) {
			$badge = array(
				'open'          => 'is-green',
				'matched'       => 'is-blue',
				'completed'     => 'is-gray',
				'pending_admin' => 'is-yellow',
			);
			$class = isset( $badge[ $row['status'] ] ) ? $badge[ $row['status'] ] : 'is-gray';

			echo '<tr>';
			echo '<td><strong>' . esc_html( Havato_Jalali::format( $row['event_date'], $lang ) ) . '</strong><br>' .
				'<span class="hv-adm-muted">' . esc_html( substr( $row['event_time'], 0, 5 ) ) .
				( '' !== trim( (string) $row['title'] ) ? ' — ' . esc_html( $row['title'] ) : '' ) .
				'</span></td>';
			echo '<td>' . esc_html( $row['taken'] . ' / ' . $row['max_capacity'] ) . '</td>';
			echo '<td>' . esc_html( havato_price( (int) $row['price'], $lang ) ) . '</td>';
			echo '<td><span class="hv-adm-badge ' . esc_attr( $class ) . '">' .
				esc_html( Havato_I18N::t( 'status_' . $row['status'] ) ) . '</span></td>';
			echo '<td class="hv-adm-actions">';
			if ( $with_manage ) {
				printf(
					'<a class="hv-adm-btn hv-adm-btn-ghost" href="%s">%s</a>',
					esc_url( admin_url( 'admin.php?page=havato-venue-events&event=' . rawurlencode( $row['id'] ) ) ),
					esc_html( Havato_I18N::t( 'members_at_table' ) )
				);
			}
			echo '</td></tr>';
		}

		echo '</tbody></table>';
	}

	/**
	 * One event: the guest list with check-in toggles.
	 *
	 * @param array  $venue    Venue row.
	 * @param string $event_id Event id.
	 * @param string $lang     Language.
	 */
	private static function event_detail( $venue, $event_id, $lang ) {
		global $wpdb;

		$events = Havato_DB::table( 'events' );
		$regs   = Havato_DB::table( 'event_registrations' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$event = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $events WHERE id=%s AND venue_id=%s", $event_id, $venue['id'] ), ARRAY_A );

		if ( ! $event ) {
			echo '<div class="hv-adm-card"><p class="hv-adm-muted">' . esc_html( Havato_I18N::t( 'empty_state' ) ) . '</p></div>';
			return;
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$members = $wpdb->get_results(
			$wpdb->prepare( "SELECT * FROM $regs WHERE event_id=%s AND status <> 'cancelled' ORDER BY id ASC", $event_id ),
			ARRAY_A
		);

		echo '<p><a class="hv-adm-btn hv-adm-btn-ghost" href="' .
			esc_url( admin_url( 'admin.php?page=havato-venue-events' ) ) . '">&larr; ' .
			esc_html( Havato_I18N::t( 'back' ) ) . '</a></p>';

		echo '<div class="hv-adm-card">';
		printf(
			'<h2 class="hv-adm-card-title">%s — %s</h2>',
			esc_html( Havato_Jalali::format( $event['event_date'], $lang ) ),
			esc_html( substr( $event['event_time'], 0, 5 ) )
		);

		if ( empty( $members ) ) {
			echo '<p class="hv-adm-muted">' . esc_html( Havato_I18N::t( 'empty_state' ) ) . '</p></div>';
			return;
		}

		echo '<table class="hv-adm-table"><thead><tr>';
		echo '<th>' . esc_html( Havato_I18N::t( 'col_manager' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'rating_score' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'col_status' ) ) . '</th>';
		echo '<th></th></tr></thead><tbody>';

		foreach ( $members as $member ) {
			$uid     = (int) $member['user_id'];
			$profile = havato_get_profile( $uid );
			$in      = (int) $member['checked_in'];

			echo '<tr>';
			echo '<td class="hv-adm-user"><img src="' . esc_url( havato_avatar( $uid ) ) . '" alt="">' .
				'<strong>' . esc_html( havato_display_name( $uid ) ) . '</strong></td>';
			echo '<td>★ ' . esc_html( round( (float) $profile['rating_score'], 1 ) ) . '</td>';
			echo '<td>' . ( $in
				? '<span class="hv-adm-badge is-green">' . esc_html( Havato_I18N::t( 'check_in' ) ) . '</span>'
				: '<span class="hv-adm-badge is-gray">—</span>' ) . '</td>';
			echo '<td class="hv-adm-actions">';

			echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '">';
			wp_nonce_field( 'havato_owner', 'havato_owner_nonce' );
			echo '<input type="hidden" name="action" value="havato_owner_action">';
			echo '<input type="hidden" name="havato_action" value="checkin">';
			echo '<input type="hidden" name="event_id" value="' . esc_attr( $event_id ) . '">';
			echo '<input type="hidden" name="user_id" value="' . esc_attr( $uid ) . '">';
			echo '<input type="hidden" name="checked_in" value="' . ( $in ? '0' : '1' ) . '">';
			printf(
				'<button type="submit" class="hv-adm-btn %s">%s</button>',
				$in ? 'hv-adm-btn-ghost' : 'hv-adm-btn-green',
				esc_html( $in ? Havato_I18N::t( 'cancel' ) : Havato_I18N::t( 'not_checked_in' ) )
			);
			echo '</form>';

			echo '</td></tr>';
		}

		echo '</tbody></table></div>';
	}

	/* =====================================================================
	 * Page — the café's physical tables
	 * ================================================================== */

	/**
	 * Define the furniture: how many tables of each size the café has.
	 *
	 * These are picked per event, and the matcher then seats one group per
	 * physical table instead of one oversized group.
	 */
	public static function page_tables() {
		$venue = self::venue();
		self::head( Havato_I18N::t( 'tab_tables' ), $venue );

		if ( ! $venue ) {
			self::no_venue();
			return;
		}

		$tables = Havato_REST::venue_tables( $venue['id'] );
		$locked = Havato_REST::tables_locked_by( $venue['id'] );
		$seats  = 0;
		foreach ( $tables as $row ) {
			$seats += $row['seats'] * $row['quantity'];
		}

		echo '<div class="hv-adm-alert is-blue">' . esc_html( Havato_I18N::t( 'tables_hint' ) ) .
			' ' . esc_html( Havato_I18N::t( 'table_number_hint' ) ) . '</div>';

		// Editing is blocked while an event still depends on this furniture.
		if ( ! empty( $locked ) ) {
			echo '<div class="hv-adm-alert is-orange">';
			echo '<strong>' . esc_html( sprintf( Havato_I18N::t( 'tables_locked' ), count( $locked ) ) ) . '</strong>';
			echo '<ul class="hv-adm-locklist">';
			foreach ( $locked as $ev ) {
				echo '<li>' . esc_html( $ev['label'] ) . '</li>';
			}
			echo '</ul>';
			echo '<span class="hv-adm-muted">' . esc_html( Havato_I18N::t( 'tables_locked_hint' ) ) . '</span>';
			echo '</div>';
		}

		echo '<div class="hv-adm-card">';
		printf(
			'<h2 class="hv-adm-card-title">%s — %s</h2>',
			esc_html( Havato_I18N::t( 'tab_tables' ) ),
			esc_html( sprintf( '%d %s', $seats, Havato_I18N::t( 'seats_left' ) ) )
		);
		printf(
			'<div id="hv-owner-tables" data-tables="%s" data-nonce="%s" data-action="%s" data-locked="%s"></div>',
			esc_attr( wp_json_encode( $tables ) ),
			esc_attr( wp_create_nonce( 'havato_owner' ) ),
			esc_url( admin_url( 'admin-post.php' ) ),
			empty( $locked ) ? '0' : '1'
		);
		echo '</div>';

		self::foot();
	}

	/* =====================================================================
	 * Page 3 — menu builder
	 * ================================================================== */

	/**
	 * Menu builder (display-only menu, pending admin approval).
	 */
	public static function page_menu() {
		$venue = self::venue();
		self::head( Havato_I18N::t( 'tab_menu_builder' ), $venue );

		if ( ! $venue ) {
			self::no_venue();
			return;
		}

		$pending = havato_json( $venue['pending_menu_json'] );
		$live    = havato_json( $venue['menu_json'] );
		$items   = ! empty( $pending ) ? $pending : $live;

		if ( ! empty( $pending ) ) {
			echo '<div class="hv-adm-alert is-orange">' . esc_html( Havato_I18N::t( 'menu_pending_badge' ) ) . '</div>';
		}
		echo '<div class="hv-adm-alert is-blue">' . esc_html( Havato_I18N::t( 'menu_display_only' ) ) . '</div>';

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'venue_menu' ) ) . '</h2>';
		printf(
			'<div id="hv-owner-menu" data-items="%s" data-nonce="%s" data-action="%s"></div>',
			esc_attr( wp_json_encode( array_values( $items ) ) ),
			esc_attr( wp_create_nonce( 'havato_owner' ) ),
			esc_url( admin_url( 'admin-post.php' ) )
		);
		echo '</div>';

		self::foot();
	}

	/* =====================================================================
	 * Page 4 — venue settings
	 * ================================================================== */

	/**
	 * Venue profile.
	 */
	public static function page_settings() {
		$venue = self::venue();
		self::head( Havato_I18N::t( 'tab_venue_settings' ), $venue );

		if ( ! $venue ) {
			self::no_venue();
			return;
		}

		echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '" class="hv-adm-card">';
		wp_nonce_field( 'havato_owner', 'havato_owner_nonce' );
		echo '<input type="hidden" name="action" value="havato_owner_action">';
		echo '<input type="hidden" name="havato_action" value="save_venue">';

		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'tab_venue_settings' ) ) . '</h2>';

		echo '<div class="hv-adm-fields">';
		printf(
			'<label>%s<input type="text" name="name" value="%s" required></label>',
			esc_html( Havato_I18N::t( 'venue_name' ) ),
			esc_attr( $venue['name'] )
		);
		printf(
			'<label>%s<input type="text" name="manager_name" value="%s"></label>',
			esc_html( Havato_I18N::t( 'manager_name' ) ),
			esc_attr( $venue['manager_name'] )
		);

		// Country / city.
		$locations = havato_locations();
		$lang      = Havato_I18N::current_lang();

		echo '<label>' . esc_html( Havato_I18N::t( 'q_country' ) ) . '<select name="country" id="hv-owner-country">';
		foreach ( $locations as $code => $info ) {
			printf(
				'<option value="%s"%s>%s</option>',
				esc_attr( $code ),
				selected( $code, $venue['country'], false ),
				esc_html( $info['label'][ $lang ] )
			);
		}
		echo '</select></label>';

		echo '<label>' . esc_html( Havato_I18N::t( 'q_city_select' ) ) . '<select name="city" id="hv-owner-city">';
		$current_country = isset( $locations[ $venue['country'] ] ) ? $venue['country'] : key( $locations );
		foreach ( $locations[ $current_country ]['cities'] as $code => $label ) {
			printf(
				'<option value="%s"%s>%s</option>',
				esc_attr( $code ),
				selected( $code, $venue['city'], false ),
				esc_html( $label[ $lang ] )
			);
		}
		echo '</select></label>';

		printf(
			'<label>%s<input type="text" name="quiet_hours" value="%s" placeholder="10:00 - 16:00"></label>',
			esc_html( Havato_I18N::t( 'quiet_hours' ) ),
			esc_attr( $venue['quiet_hours'] )
		);
		echo '</div>';

		printf(
			'<label class="hv-adm-block-label">%s<textarea name="address" rows="3">%s</textarea></label>',
			esc_html( Havato_I18N::t( 'venue_address' ) ),
			esc_textarea( $venue['address'] )
		);

		// Cover image via the WordPress media library.
		echo '<div class="hv-adm-cover">';
		echo '<label class="hv-adm-block-label">' . esc_html( Havato_I18N::t( 'cover_image' ) ) . '</label>';
		echo '<input type="hidden" name="image" id="hv-owner-image" value="' . esc_attr( $venue['image'] ) . '">';
		echo '<img id="hv-owner-image-preview" src="' . esc_url( $venue['image'] ) . '" alt=""' .
			( $venue['image'] ? '' : ' hidden' ) . '>';
		echo '<button type="button" class="hv-adm-btn hv-adm-btn-ghost" id="hv-owner-pick-image">' .
			esc_html( Havato_I18N::t( 'upload_photo' ) ) . '</button>';
		echo '</div>';

		// Draggable pin.
		echo '<h3 class="hv-adm-card-title" style="margin-top:22px">' . esc_html( Havato_I18N::t( 'col_location' ) ) . '</h3>';
		echo '<p class="hv-adm-muted">' . esc_html( Havato_I18N::t( 'drag_pin' ) ) . '</p>';
		printf(
			'<div id="hv-owner-map" data-lat="%s" data-lng="%s"></div>',
			esc_attr( $venue['lat'] ),
			esc_attr( $venue['lng'] )
		);
		echo '<input type="hidden" name="lat" id="hv-owner-lat" value="' . esc_attr( $venue['lat'] ) . '">';
		echo '<input type="hidden" name="lng" id="hv-owner-lng" value="' . esc_attr( $venue['lng'] ) . '">';

		echo '<p style="margin-top:18px"><button type="submit" class="hv-adm-btn hv-adm-btn-blue">' .
			esc_html( Havato_I18N::t( 'save' ) ) . '</button></p>';
		echo '</form>';

		self::foot();
	}

	/* =====================================================================
	 * POST handler
	 * ================================================================== */

	/**
	 * Flash message after a redirect.
	 */
	public static function notices() {
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( empty( $_GET['havato_msg'] ) || ! self::is_owner() ) {
			return;
		}
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$msg = sanitize_text_field( wp_unslash( $_GET['havato_msg'] ) );
		printf( '<div class="notice notice-success is-dismissible"><p>%s</p></div>', esc_html( $msg ) );
	}

	/**
	 * Handle every owner form submission.
	 *
	 * Each action delegates to the same REST controller the mobile portal used,
	 * so validation and business rules live in exactly one place.
	 */
	public static function handle_post() {
		if ( ! self::is_owner() && ! current_user_can( 'manage_options' ) ) {
			wp_die( 'Forbidden', 403 );
		}

		check_admin_referer( 'havato_owner', 'havato_owner_nonce' );

		$action = isset( $_POST['havato_action'] ) ? sanitize_key( wp_unslash( $_POST['havato_action'] ) ) : '';
		$page   = 'havato-venue';
		$msg    = Havato_I18N::t( 'saved' );
		$extra  = array();

		switch ( $action ) {
			case 'create_event':
				$req = new WP_REST_Request( 'POST' );
				foreach ( array( 'title', 'theme', 'event_date', 'event_time', 'budget_tier' ) as $key ) {
					$req->set_param( $key, isset( $_POST[ $key ] ) ? sanitize_text_field( wp_unslash( $_POST[ $key ] ) ) : '' );
				}
				$req->set_param( 'image', isset( $_POST['image'] ) ? esc_url_raw( wp_unslash( $_POST['image'] ) ) : '' );
				$req->set_param( 'max_capacity', isset( $_POST['max_capacity'] ) ? (int) $_POST['max_capacity'] : 6 );

				// Only the ticked tables count toward the event.
				$picked = array();
				// phpcs:ignore WordPress.Security.NonceVerification.Missing -- verified above.
				$raw_tables = isset( $_POST['tables'] ) && is_array( $_POST['tables'] ) ? wp_unslash( $_POST['tables'] ) : array();
				foreach ( $raw_tables as $row ) {
					if ( empty( $row['use'] ) || empty( $row['table_id'] ) ) {
						continue;
					}
					$picked[] = array(
						'table_id' => (int) $row['table_id'],
						'quantity' => isset( $row['quantity'] ) ? (int) $row['quantity'] : 1,
					);
				}
				$req->set_param( 'tables', $picked );

				$result = Havato_REST::owner_create_event( $req );
				if ( is_wp_error( $result ) ) {
					$msg = $result->get_error_message();
				}
				$page = 'havato-venue-events';
				break;

			case 'checkin':
				$req = new WP_REST_Request( 'POST' );
				$req->set_param( 'event_id', isset( $_POST['event_id'] ) ? sanitize_text_field( wp_unslash( $_POST['event_id'] ) ) : '' );
				$req->set_param( 'user_id', isset( $_POST['user_id'] ) ? (int) $_POST['user_id'] : 0 );
				$req->set_param( 'checked_in', ! empty( $_POST['checked_in'] ) );

				$result = Havato_REST::owner_checkin( $req );
				if ( is_wp_error( $result ) ) {
					$msg = $result->get_error_message();
				}
				$page  = 'havato-venue-events';
				$extra = array( 'event' => isset( $_POST['event_id'] ) ? sanitize_text_field( wp_unslash( $_POST['event_id'] ) ) : '' );
				break;

			case 'save_storefront':
				$req = new WP_REST_Request( 'POST' );
				$req->set_param( 'storefront_photo', isset( $_POST['storefront_photo'] ) ? esc_url_raw( wp_unslash( $_POST['storefront_photo'] ) ) : '' );

				$result = Havato_REST::owner_save_venue( $req );
				$msg    = is_wp_error( $result ) ? $result->get_error_message() : Havato_I18N::t( 'storefront_received' );
				break;

			case 'save_venue':
				$req = new WP_REST_Request( 'POST' );
				foreach ( array( 'name', 'manager_name', 'quiet_hours', 'country', 'city' ) as $key ) {
					if ( isset( $_POST[ $key ] ) ) {
						$req->set_param( $key, sanitize_text_field( wp_unslash( $_POST[ $key ] ) ) );
					}
				}
				if ( isset( $_POST['address'] ) ) {
					$req->set_param( 'address', sanitize_textarea_field( wp_unslash( $_POST['address'] ) ) );
				}
				if ( isset( $_POST['image'] ) ) {
					$req->set_param( 'image', esc_url_raw( wp_unslash( $_POST['image'] ) ) );
				}
				foreach ( array( 'lat', 'lng' ) as $key ) {
					if ( isset( $_POST[ $key ] ) && '' !== $_POST[ $key ] ) {
						$req->set_param( $key, (float) $_POST[ $key ] );
					}
				}

				$result = Havato_REST::owner_save_venue( $req );
				if ( is_wp_error( $result ) ) {
					$msg = $result->get_error_message();
				}
				$page = 'havato-venue-settings';
				break;

			case 'save_tables':
				$raw = isset( $_POST['tables_json'] ) ? wp_unslash( $_POST['tables_json'] ) : '[]';
				$req = new WP_REST_Request( 'POST' );
				$req->set_param( 'tables', havato_json( $raw ) );

				$result = Havato_REST::owner_save_tables( $req );
				$msg    = is_wp_error( $result ) ? $result->get_error_message() : Havato_I18N::t( 'saved' );
				$page   = 'havato-venue-tables';
				break;

			case 'save_menu':
				$raw = isset( $_POST['menu_json'] ) ? wp_unslash( $_POST['menu_json'] ) : '[]';
				$req = new WP_REST_Request( 'POST' );
				$req->set_param( 'items', havato_json( $raw ) );

				$result = Havato_REST::owner_save_menu( $req );
				$msg    = is_wp_error( $result ) ? $result->get_error_message() : Havato_I18N::t( 'menu_saved_pending' );
				$page   = 'havato-venue-menu';
				break;
		}

		wp_safe_redirect(
			add_query_arg(
				array_merge(
					array(
						'page'       => $page,
						'havato_msg' => rawurlencode( $msg ),
					),
					$extra
				),
				admin_url( 'admin.php' )
			)
		);
		exit;
	}
}
