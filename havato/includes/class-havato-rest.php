<?php
/**
 * REST API — every screen of the SPA talks to these endpoints.
 *
 * Namespace: havato/v1
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Endpoint registry & controllers.
 */
class Havato_REST {

	const NS = 'havato/v1';

	/**
	 * Register the routes.
	 */
	public static function init() {
		add_action( 'rest_api_init', array( __CLASS__, 'register_routes' ) );
	}

	/* =====================================================================
	 * Permission helpers
	 * ================================================================== */

	/**
	 * Anyone (guests included).
	 *
	 * @return bool
	 */
	public static function public_perm() {
		return true;
	}

	/**
	 * Logged-in users only.
	 *
	 * @return bool|WP_Error
	 */
	public static function auth_perm() {
		if ( ! is_user_logged_in() ) {
			return new WP_Error( 'havato_auth', Havato_I18N::t( 'auth_title' ), array( 'status' => 401 ) );
		}
		// A banned account keeps its cookie until it expires, so every
		// authenticated endpoint has to re-check rather than trusting login.
		if ( havato_is_banned( get_current_user_id() ) ) {
			return new WP_Error( 'havato_banned', Havato_I18N::t( 'account_banned' ), array( 'status' => 403 ) );
		}
		return true;
	}

	/**
	 * Where the map should open.
	 *
	 * Centres on the viewer's own city so an Istanbul guest is not shown
	 * Tehran; falls back to the administrator's default when unknown.
	 *
	 * @param string $city City key.
	 * @return array
	 */
	public static function map_center( $city ) {
		$centre = $city ? havato_city_center( $city ) : null;

		if ( $centre ) {
			return $centre;
		}

		return array(
			'lat'  => (float) Havato_Settings::get( 'map_center_lat', 35.7219 ),
			'lng'  => (float) Havato_Settings::get( 'map_center_lng', 51.3347 ),
			'zoom' => (int) Havato_Settings::get( 'map_zoom', 12 ),
		);
	}

	/**
	 * Café owners (and admins).
	 *
	 * @return bool|WP_Error
	 */
	public static function owner_perm() {
		$auth = self::auth_perm();
		if ( is_wp_error( $auth ) ) {
			return $auth;
		}
		$role = havato_user_role();
		if ( 'cafe_owner' !== $role && 'admin' !== $role ) {
			return new WP_Error( 'havato_forbidden', 'Café owners only.', array( 'status' => 403 ) );
		}
		return true;
	}

	/**
	 * Administrators only.
	 *
	 * @return bool|WP_Error
	 */
	public static function admin_perm() {
		if ( ! current_user_can( 'manage_options' ) ) {
			return new WP_Error( 'havato_forbidden', 'Administrators only.', array( 'status' => 403 ) );
		}
		return true;
	}

	/**
	 * Boot every request: self-heal tables + resolve language.
	 *
	 * @param WP_REST_Request $req Request.
	 */
	private static function boot( $req ) {
		Havato_DB::ensure_tables();
		$lang = $req->get_param( 'lang' );
		if ( $lang ) {
			Havato_I18N::set_lang( $lang );
		}
	}

	/* =====================================================================
	 * Routes
	 * ================================================================== */

	/**
	 * Register all REST routes.
	 */
	public static function register_routes() {
		$auth   = array( __CLASS__, 'auth_perm' );
		$pub    = array( __CLASS__, 'public_perm' );
		$owner  = array( __CLASS__, 'owner_perm' );
		$admin  = array( __CLASS__, 'admin_perm' );

		$routes = array(
			// Bootstrap & auth.
			'bootstrap'          => array( 'GET', 'bootstrap', $pub ),
			'auth/google'        => array( 'POST', 'auth_google', $pub ),
			'auth/logout'        => array( 'POST', 'auth_logout', $auth ),
			'lang'               => array( 'POST', 'set_lang', $pub ),

			// Explore / events.
			'events'             => array( 'GET', 'get_events', $pub ),
			'events/join'        => array( 'POST', 'join_event', $auth ),
			'events/mine'        => array( 'GET', 'my_events', $auth ),

			// Venues & map.
			'venues'             => array( 'GET', 'get_venues', $pub ),
			'venue'              => array( 'GET', 'get_venue', $pub ),

			// Chats.
			'chat/threads'       => array( 'GET', 'chat_threads', $auth ),
			'chat/group'         => array( 'GET', 'chat_group', $auth ),
			'chat/group/send'    => array( 'POST', 'chat_group_send', $auth ),
			'chat/private'       => array( 'GET', 'chat_private', $auth ),
			'chat/private/send'  => array( 'POST', 'chat_private_send', $auth ),
			'chat/report'        => array( 'POST', 'report_message', $auth ),
			'chat/block'         => array( 'POST', 'block_user', $auth ),
			'chat/unblock'       => array( 'POST', 'unblock_user', $auth ),

			// Profile.
			'profile'            => array( 'GET', 'get_profile', $auth ),
			'profile/test'       => array( 'POST', 'save_test', $auth ),
			'profile/details'    => array( 'POST', 'save_details', $auth ),
			'profile/delete'     => array( 'POST', 'delete_account', $auth ),
			'profile/avatar'     => array( 'POST', 'upload_avatar', $auth ),

			// Photos.
			'photos/upload'      => array( 'POST', 'upload_photo', $auth ),
			'photos/like'        => array( 'POST', 'like_photo', $auth ),
			'photos/report'      => array( 'POST', 'report_photo', $auth ),
			'photos/delete'      => array( 'POST', 'delete_photo', $auth ),

			// Friends.
			'friends'            => array( 'GET', 'get_friends', $auth ),
			'friends/request'    => array( 'POST', 'friend_request', $auth ),
			'friends/respond'    => array( 'POST', 'friend_respond', $auth ),

			// Feedback.
			'feedback/pending'   => array( 'GET', 'pending_feedback', $auth ),
			'feedback/submit'    => array( 'POST', 'submit_feedback', $auth ),

			// Owner portal.
			'owner/register'     => array( 'POST', 'owner_register', $pub ),
			'owner/login'        => array( 'POST', 'owner_login', $pub ),
			'owner/dashboard'    => array( 'GET', 'owner_dashboard', $owner ),
			'owner/events'       => array( 'GET', 'owner_events', $owner ),
			'owner/event'        => array( 'GET', 'owner_event', $owner ),
			'owner/event/create' => array( 'POST', 'owner_create_event', $owner ),
			'owner/event/cancel' => array( 'POST', 'owner_cancel_event', $owner ),
			'owner/checkin'      => array( 'POST', 'owner_checkin', $owner ),
			'owner/menu'         => array( 'POST', 'owner_save_menu', $owner ),
			'owner/venue'        => array( 'POST', 'owner_save_venue', $owner ),
			'owner/upload'       => array( 'POST', 'owner_upload', $owner ),
			'owner/tables'       => array( 'GET', 'owner_get_tables', $owner ),
			'owner/tables/save'  => array( 'POST', 'owner_save_tables', $owner ),

			// Admin console.
			'admin/stats'        => array( 'GET', 'admin_stats', $admin ),
			'admin/log'          => array( 'GET', 'admin_log', $admin ),
			'admin/verify'       => array( 'POST', 'admin_verify_venue', $admin ),
			'admin/menu-approve' => array( 'POST', 'admin_menu_approve', $admin ),
			'admin/run-matcher'  => array( 'POST', 'admin_run_matcher', $admin ),
			'admin/settings'     => array( 'POST', 'admin_save_settings', $admin ),
			'admin/photo-report' => array( 'POST', 'admin_photo_report', $admin ),
			'admin/chat-report'  => array( 'POST', 'admin_chat_report', $admin ),
			'admin/seed'         => array( 'POST', 'admin_seed', $admin ),
		);

		foreach ( $routes as $path => $conf ) {
			list( $method, $callback, $permission ) = $conf;
			register_rest_route(
				self::NS,
				'/' . $path,
				array(
					'methods'             => $method,
					'callback'            => array( __CLASS__, $callback ),
					'permission_callback' => $permission,
				)
			);
		}
	}

	/* =====================================================================
	 * Bootstrap & auth
	 * ================================================================== */

	/**
	 * Full app state for the current viewer.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function bootstrap( $req ) {
		self::boot( $req );

		$user_id = get_current_user_id();
		$role    = havato_user_role();
		$lang    = Havato_I18N::current_lang();

		$data = array(
			'logged_in'     => (bool) $user_id,
			'role'          => $role,
			'lang'          => $lang,
			'dir'           => Havato_I18N::dir( $lang ),
			'google_ready'  => Havato_Google_Auth::is_configured(),
			'google_client' => Havato_Settings::get( 'google_client_id', '' ),
			'map'           => self::map_center( self::viewer_city() ),
			'max_seats'     => havato_max_seats(),
			'interests'     => havato_interest_tags(),
			'locations'     => havato_locations(),
			'city'          => self::viewer_city(),
		);

		if ( $user_id ) {
			$data['user'] = self::user_card( $user_id );

			if ( 'cafe_owner' === $role ) {
				$venue = self::owner_venue( $user_id );
				$data['venue'] = $venue ? self::venue_payload( $venue, true ) : null;
			} else {
				$profile                 = havato_get_profile( $user_id );
				$data['profile_done']    = (bool) $profile['completed'];
				$data['pending_feedback'] = count( self::collect_pending_feedback( $user_id ) );
			}
		}

		return self::ok( $data );
	}

	/**
	 * Google Sign-In.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function auth_google( $req ) {
		self::boot( $req );

		$result = Havato_Google_Auth::login_with_credential( $req->get_param( 'credential' ) );
		if ( is_wp_error( $result ) ) {
			return $result;
		}

		return self::ok(
			array(
				'user' => self::user_card( $result['user_id'] ),
				'role' => havato_user_role( $result['user_id'] ),
			)
		);
	}

	/**
	 * Sign out.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function auth_logout( $req ) {
		self::boot( $req );
		wp_logout();
		return self::ok( array( 'logged_out' => true ) );
	}

	/**
	 * Persist the language preference.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function set_lang( $req ) {
		self::boot( $req );
		$lang = Havato_I18N::sanitize_lang( $req->get_param( 'value' ) );

		if ( is_user_logged_in() ) {
			update_user_meta( get_current_user_id(), 'havato_lang', $lang );
		}

		return self::ok(
			array(
				'lang' => $lang,
				'dir'  => Havato_I18N::dir( $lang ),
			)
		);
	}

	/* =====================================================================
	 * Explore / events
	 * ================================================================== */

	/**
	 * The city the current user belongs to, or '' for guests / unfinished
	 * profiles. Drives the geographic scoping of Explore and the Map.
	 *
	 * @return string
	 */
	private static function viewer_city() {
		$user_id = get_current_user_id();
		if ( ! $user_id ) {
			return '';
		}
		$profile = havato_get_profile( $user_id );
		return isset( $profile['city'] ) ? (string) $profile['city'] : '';
	}

	/**
	 * Open events of the coming days.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function get_events( $req ) {
		self::boot( $req );

		global $wpdb;
		$events = Havato_DB::table( 'events' );
		$venues = Havato_DB::table( 'venues' );
		$regs   = Havato_DB::table( 'event_registrations' );

		$tier = sanitize_text_field( (string) $req->get_param( 'budget' ) );
		$where = "e.status IN ('open','matched') AND v.verified = 1 AND e.event_date >= CURDATE()";
		if ( in_array( $tier, array( 'low', 'medium', 'high' ), true ) ) {
			$where .= $wpdb->prepare( ' AND e.budget_tier = %s', $tier );
		}

		// Only ever show tables in the guest's own city — a Tehran user has no
		// use for an Istanbul table. Guests (no profile yet) see everything.
		$city = self::viewer_city();
		if ( $city ) {
			$where .= $wpdb->prepare( ' AND v.city = %s', $city );
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			"SELECT e.*, v.name AS venue_name, v.image AS venue_image,
					v.address AS venue_address, v.lat, v.lng, v.quiet_hours, v.verified,
					(SELECT COALESCE(SUM(r.seats),0) FROM $regs r WHERE r.event_id = e.id AND r.status <> 'cancelled') AS taken
			 FROM $events e
			 INNER JOIN $venues v ON v.id = e.venue_id
			 WHERE $where
			 ORDER BY e.event_date ASC, e.event_time ASC
			 LIMIT 60",
			ARRAY_A
		);

		$user_id = get_current_user_id();
		$out     = array();

		foreach ( (array) $rows as $row ) {
			$out[] = self::event_payload( $row, $user_id );
		}

		return self::ok( array( 'events' => $out ) );
	}

	/**
	 * Join an event. Always free; the seat goes straight into the queue.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function join_event( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id  = get_current_user_id();
		$event_id = sanitize_text_field( (string) $req->get_param( 'event_id' ) );

		$events = Havato_DB::table( 'events' );
		$regs   = Havato_DB::table( 'event_registrations' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$event = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $events WHERE id=%s", $event_id ), ARRAY_A );
		if ( ! $event ) {
			return new WP_Error( 'havato_no_event', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		// Explore only lists open and matched events, but the id travels in
		// the request body: without this check a stale tab — or a direct call
		// — could still book a seat at an event that has been cancelled or is
		// already over.
		if ( ! in_array( (string) $event['status'], array( 'open', 'matched' ), true ) ) {
			return new WP_Error( 'havato_event_closed', Havato_I18N::t( 'event_not_open' ), array( 'status' => 409 ) );
		}

		// Joining is free. What it does require is a usable profile: the
		// matcher needs the personality answers to seat anyone, and events
		// are scoped by city, so both halves must exist before taking a seat.
		$profile = havato_get_profile( $user_id );
		if ( ! $profile['completed'] ) {
			return new WP_Error( 'havato_no_profile', Havato_I18N::t( 'need_profile_first' ), array( 'status' => 400 ) );
		}
		if ( ! havato_valid_city( $profile['country'], $profile['city'] ) ) {
			return new WP_Error( 'havato_no_details', Havato_I18N::t( 'need_details_first' ), array( 'status' => 400 ) );
		}

		// A guest may bring companions. One row still represents the whole
		// party (UNIQUE event_id+user_id); `seats` carries the size.
		$seats = (int) $req->get_param( 'seats' );
		$seats = $seats > 0 ? $seats : 1;
		$seats = min( havato_max_seats(), $seats );

		// A party is always seated together, so it can never be larger than
		// the biggest single table the café assigned to this event —
		// otherwise the matcher would have nowhere to put them.
		$biggest = self::largest_table_seats( $event );
		if ( $seats > $biggest ) {
			return new WP_Error(
				'havato_party_too_big',
				sprintf( Havato_I18N::t( 'party_max_seats' ), number_format_i18n( $biggest ) ),
				array( 'status' => 409, 'max_seats' => $biggest )
			);
		}

		// Seats already taken, counting parties rather than rows — otherwise
		// a 6-seat table could be "3 rows = 3 people" while 7 guests attend.
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$taken = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COALESCE(SUM(seats),0) FROM $regs WHERE event_id=%s AND status<>'cancelled'", $event_id ) );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$mine = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $regs WHERE event_id=%s AND user_id=%d", $event_id, $user_id ), ARRAY_A );

		if ( $mine && 'cancelled' !== $mine['status'] ) {
			return self::ok( array( 'already' => true ) );
		}

		$free = (int) $event['max_capacity'] - $taken;

		if ( $free <= 0 ) {
			return new WP_Error( 'havato_full', Havato_I18N::t( 'event_full' ), array( 'status' => 409 ) );
		}

		// Asking for more seats than are left is a partial-availability case,
		// not a hard failure: say how many remain instead of silently seating
		// fewer people than the guest expects to bring.
		if ( $seats > $free ) {
			return new WP_Error(
				'havato_not_enough_seats',
				sprintf( Havato_I18N::t( 'only_n_seats_left' ), number_format_i18n( $free ) ),
				array( 'status' => 409, 'seats_left' => $free )
			);
		}

		self::queue_user( $event_id, $user_id, 'queued', $seats );
		Havato_Logger::log( sprintf( 'User request received: guest %d queued for event %s (%d seat(s)).', $user_id, $event_id, $seats ), 'info' );

		$match = Havato_Matcher::maybe_run_on_full( $event_id );

		/**
		 * TEMPORARY (requested for review): seat the table immediately instead
		 * of waiting for the last seat, so the chat room exists right after
		 * reserving and its features can be inspected.
		 *
		 * Limited to cafés outside Iran. Iranian venues follow the normal rule
		 * — the table forms when the event fills, or when the cron fallback
		 * runs before it starts.
		 *
		 * An unresolvable country counts as "no": the app would send that
		 * guest to Explore, so seating them here would leave a table formed
		 * behind their back.
		 *
		 * @param bool   $now      Whether to match on every booking.
		 * @param string $event_id Event id.
		 * @param string $country  Country of the café hosting the event.
		 */
		$country   = self::event_country( $event_id );
		$temp_seat = ( '' !== $country && 'ir' !== $country );

		if ( ! ( is_array( $match ) && ! empty( $match['ok'] ) )
			&& apply_filters( 'havato_match_immediately', $temp_seat, $event_id, $country ) ) {
			$match = Havato_Matcher::run( $event_id, true );
		}

		$matched = (bool) ( is_array( $match ) && ! empty( $match['ok'] ) );

		// Hand back the group so the app can open its chat straight away.
		$group_id = '';
		if ( $matched ) {
			$gm = Havato_DB::table( 'group_members' );
			$gr = Havato_DB::table( 'groups' );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$group_id = (string) $wpdb->get_var(
				$wpdb->prepare(
					"SELECT g.id FROM $gr g
					 INNER JOIN $gm m ON m.group_id = g.id
					 WHERE g.event_id = %s AND m.user_id = %d
					 ORDER BY g.id DESC LIMIT 1",
					$event_id,
					$user_id
				)
			);
		}

		return self::ok(
			array(
				'queued'   => true,
				'matched'  => $matched,
				'group_id' => $group_id,
				// The app decides where to land next from this, so the rule
				// lives in one place instead of being duplicated client-side.
				'country'  => $country,
			)
		);
	}

	/**
	 * Country of the café hosting an event.
	 *
	 * @param string $event_id Event id.
	 * @return string Country key, or '' when it cannot be resolved.
	 */
	private static function event_country( $event_id ) {
		global $wpdb;

		$events = Havato_DB::table( 'events' );
		$venues = Havato_DB::table( 'venues' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$country = $wpdb->get_var(
			$wpdb->prepare(
				"SELECT v.country FROM $events e
				 INNER JOIN $venues v ON v.id = e.venue_id
				 WHERE e.id = %s LIMIT 1",
				$event_id
			)
		);

		return strtolower( (string) $country );
	}

	/**
	 * The current user's own event history.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function my_events( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id = get_current_user_id();

		$events = Havato_DB::table( 'events' );
		$venues = Havato_DB::table( 'venues' );
		$regs   = Havato_DB::table( 'event_registrations' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT e.*, v.name AS venue_name, v.image AS venue_image,
						v.address AS venue_address, v.lat, v.lng, v.quiet_hours, v.verified,
						r.status AS my_status, r.checked_in,
						(SELECT COALESCE(SUM(r2.seats),0) FROM $regs r2 WHERE r2.event_id = e.id AND r2.status <> 'cancelled') AS taken
				 FROM $regs r
				 INNER JOIN $events e ON e.id = r.event_id
				 LEFT JOIN $venues v ON v.id = e.venue_id
				 WHERE r.user_id = %d AND r.status <> 'cancelled'
				 ORDER BY e.event_date DESC LIMIT 40",
				$user_id
			),
			ARRAY_A
		);

		$out = array();
		foreach ( (array) $rows as $row ) {
			$payload               = self::event_payload( $row, $user_id );
			$payload['checked_in'] = (bool) $row['checked_in'];
			$out[]                 = $payload;
		}

		return self::ok( array( 'events' => $out ) );
	}

	/* =====================================================================
	 * Venues
	 * ================================================================== */

	/**
	 * Verified venues for the map.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function get_venues( $req ) {
		self::boot( $req );

		global $wpdb;
		$venues = Havato_DB::table( 'venues' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$city = self::viewer_city();

		if ( $city ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$rows = $wpdb->get_results(
				$wpdb->prepare( "SELECT * FROM $venues WHERE verified = 1 AND city = %s ORDER BY guests_routed DESC LIMIT 200", $city ),
				ARRAY_A
			);
		} else {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$rows = $wpdb->get_results( "SELECT * FROM $venues WHERE verified = 1 ORDER BY guests_routed DESC LIMIT 200", ARRAY_A );
		}

		$out = array();
		foreach ( (array) $rows as $row ) {
			$out[] = self::venue_payload( $row, false );
		}

		return self::ok( array( 'venues' => $out ) );
	}

	/**
	 * Public café profile + approved menu.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function get_venue( $req ) {
		self::boot( $req );

		global $wpdb;
		$venues = Havato_DB::table( 'venues' );
		$id     = sanitize_text_field( (string) $req->get_param( 'id' ) );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$row = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $venues WHERE id=%s", $id ), ARRAY_A );
		if ( ! $row ) {
			return new WP_Error( 'havato_no_venue', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		return self::ok( array( 'venue' => self::venue_payload( $row, false ) ) );
	}

	/* =====================================================================
	 * Chats
	 * ================================================================== */

	/**
	 * Both chat lists: event tables + accepted friends.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function chat_threads( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id = get_current_user_id();

		$groups   = Havato_DB::table( 'groups' );
		$gm       = Havato_DB::table( 'group_members' );
		$events   = Havato_DB::table( 'events' );
		$venues   = Havato_DB::table( 'venues' );
		$chats    = Havato_DB::table( 'chats' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$group_rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT g.id, g.name, e.event_date, e.event_time, e.status AS event_status,
						v.name AS venue_name, v.image AS venue_image,
						(SELECT message_text FROM $chats c WHERE c.group_id = g.id ORDER BY c.id DESC LIMIT 1) AS last_message,
						(SELECT is_system FROM $chats c WHERE c.group_id = g.id ORDER BY c.id DESC LIMIT 1) AS last_is_system,
						(SELECT COUNT(*) FROM $gm m2 WHERE m2.group_id = g.id) AS member_count
				 FROM $gm m
				 INNER JOIN $groups g ON g.id = m.group_id
				 LEFT JOIN $events e ON e.id = g.event_id
				 LEFT JOIN $venues v ON v.id = e.venue_id
				 WHERE m.user_id = %d
				 ORDER BY e.event_date DESC",
				$user_id
			),
			ARRAY_A
		);

		$group_threads = array();
		foreach ( (array) $group_rows as $row ) {
			$group_threads[] = array(
				'id'           => $row['id'],
				// The group is named after the real table ("Table #6"), which
				// is what the guest will look for when they arrive.
				'table_name'   => $row['name'],
				'name'         => $row['venue_name'] ? $row['venue_name'] : $row['name'],
				'image'        => $row['venue_image'],
				'date'         => havato_date_pair( $row['event_date'] ),
				'time'         => substr( (string) $row['event_time'], 0, 5 ),
				'members'      => (int) $row['member_count'],
				// The preview must be decoded first: a freshly matched table's
				// newest line is the system message, which is stored as JSON.
				'last_message' => $row['last_message']
					? wp_trim_words(
						havato_message_text( $row['last_message'], ! empty( $row['last_is_system'] ) ),
						8,
						'…'
					)
					: '',
				'event_status' => $row['event_status'],
			);
		}

		return self::ok(
			array(
				'groups'  => $group_threads,
				'friends' => self::friend_threads( $user_id ),
			)
		);
	}

	/**
	 * Messages of one table chat.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function chat_group( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id  = get_current_user_id();
		$group_id = sanitize_text_field( (string) $req->get_param( 'group_id' ) );
		$since    = (int) $req->get_param( 'since' );

		if ( ! self::is_group_member( $group_id, $user_id ) ) {
			return new WP_Error( 'havato_forbidden', Havato_I18N::t( 'blocked_user' ), array( 'status' => 403 ) );
		}

		$chats = Havato_DB::table( 'chats' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			$wpdb->prepare( "SELECT * FROM $chats WHERE group_id=%s AND id > %d ORDER BY id ASC LIMIT 200", $group_id, $since ),
			ARRAY_A
		);

		// Blocking must mean "I no longer see this person", including the
		// lines they already posted to this table. Resolve the blocklist once
		// rather than per message.
		$profile = havato_get_profile( $user_id );
		$blocked = array_map( 'intval', (array) $profile['blocklist'] );

		$messages = array();
		// Highest id actually scanned, blocked or not. The client uses it as
		// the next `since`, so a filtered-out trailing message is not
		// re-queried on every poll.
		$cursor = (int) $since;

		foreach ( (array) $rows as $row ) {
			$sender = (int) $row['sender_id'];
			$cursor = max( $cursor, (int) $row['id'] );

			if ( $sender && $sender !== $user_id && in_array( $sender, $blocked, true ) ) {
				continue;
			}

			$messages[] = array(
				'id'        => (int) $row['id'],
				'sender_id' => $sender,
				'name'      => $row['sender_name'],
				'avatar'    => $sender ? havato_avatar( $sender ) : '',
				// System lines carry one string per language; the client picks
				// the active one so a Persian guest never sees the English half.
				'text'      => havato_message_pair( $row['message_text'], (bool) $row['is_system'] ),
				'time'      => substr( (string) $row['message_time'], 11, 5 ),
				'time_full' => havato_date_pair( $row['message_time'], true ),
				'is_system' => (bool) $row['is_system'],
				'mine'      => $sender === $user_id,
			);
		}

		return self::ok(
			array(
				'cursor'   => $cursor,
				'messages' => $messages,
				'members'  => self::group_members( $group_id, $user_id ),
			)
		);
	}

	/**
	 * Post a message into a table chat.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function chat_group_send( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id  = get_current_user_id();
		$group_id = sanitize_text_field( (string) $req->get_param( 'group_id' ) );
		$text     = havato_clamp_text( sanitize_textarea_field( (string) $req->get_param( 'text' ) ), 1000 );

		if ( '' === trim( $text ) ) {
			return new WP_Error( 'havato_empty', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}
		if ( ! self::is_group_member( $group_id, $user_id ) ) {
			return new WP_Error( 'havato_forbidden', Havato_I18N::t( 'blocked_user' ), array( 'status' => 403 ) );
		}

		$chats = Havato_DB::table( 'chats' );

		// Flag for review if the text trips the word list. The message is
		// delivered exactly as written and the sender is told nothing; only
		// the admin panel shows the marker.
		$flag = havato_profanity_hit( $text );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert(
			$chats,
			array(
				'group_id'     => $group_id,
				'sender_id'    => $user_id,
				'sender_name'  => havato_display_name( $user_id ),
				'message_text' => $text,
				'message_time' => havato_now(),
				'is_system'    => 0,
				'flagged'      => '' !== $flag ? 1 : 0,
				'flag_term'    => $flag,
			),
			array( '%s', '%d', '%s', '%s', '%s', '%d', '%d', '%s' )
		);

		return self::ok( array( 'id' => (int) $wpdb->insert_id ) );
	}

	/**
	 * Private conversation with one friend.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function chat_private( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id  = get_current_user_id();
		$other_id = (int) $req->get_param( 'user_id' );
		$since    = (int) $req->get_param( 'since' );

		if ( havato_is_blocked( $user_id, $other_id ) || ! havato_are_friends( $user_id, $other_id ) ) {
			return new WP_Error( 'havato_not_friends', Havato_I18N::t( 'blocked_user' ), array( 'status' => 403 ) );
		}

		$table  = Havato_DB::table( 'private_chats' );
		$thread = Havato_DB::thread_id( $user_id, $other_id );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			$wpdb->prepare( "SELECT * FROM $table WHERE thread_id=%s AND id > %d ORDER BY id ASC LIMIT 200", $thread, $since ),
			ARRAY_A
		);

		// Mark incoming as read.
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$wpdb->query( $wpdb->prepare( "UPDATE $table SET is_read=1 WHERE thread_id=%s AND receiver_id=%d AND is_read=0", $thread, $user_id ) );

		$messages = array();
		foreach ( (array) $rows as $row ) {
			$messages[] = array(
				'id'        => (int) $row['id'],
				'sender_id' => (int) $row['sender_id'],
				'name'      => havato_display_name( (int) $row['sender_id'] ),
				'avatar'    => havato_avatar( (int) $row['sender_id'] ),
				// Same shape as a table message: the renderer is shared, so it
				// must always receive a language map. A private line is never a
				// system line, hence `false`.
				'text'      => havato_message_pair( $row['message_text'], false ),
				'time'      => substr( (string) $row['message_time'], 11, 5 ),
				'time_full' => havato_date_pair( $row['message_time'], true ),
				'mine'      => (int) $row['sender_id'] === $user_id,
			);
		}

		return self::ok(
			array(
				'messages' => $messages,
				'peer'     => self::user_card( $other_id ),
			)
		);
	}

	/**
	 * Send a private message.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function chat_private_send( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id  = get_current_user_id();
		$other_id = (int) $req->get_param( 'user_id' );
		$text     = havato_clamp_text( sanitize_textarea_field( (string) $req->get_param( 'text' ) ), 1000 );

		if ( '' === trim( $text ) ) {
			return new WP_Error( 'havato_empty', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}
		if ( havato_is_blocked( $user_id, $other_id ) || ! havato_are_friends( $user_id, $other_id ) ) {
			return new WP_Error( 'havato_not_friends', Havato_I18N::t( 'blocked_user' ), array( 'status' => 403 ) );
		}

		$table = Havato_DB::table( 'private_chats' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		// Same silent review flag as the table chat.
		$flag = havato_profanity_hit( $text );

		$wpdb->insert(
			$table,
			array(
				'thread_id'    => Havato_DB::thread_id( $user_id, $other_id ),
				'sender_id'    => $user_id,
				'receiver_id'  => $other_id,
				'message_text' => $text,
				'message_time' => havato_now(),
				'is_read'      => 0,
				'flagged'      => '' !== $flag ? 1 : 0,
				'flag_term'    => $flag,
			),
			array( '%s', '%d', '%d', '%s', '%s', '%d', '%d', '%s' )
		);

		return self::ok( array( 'id' => (int) $wpdb->insert_id ) );
	}

	/* =====================================================================
	 * Profile & gallery
	 * ================================================================== */

	/**
	 * Own profile, or another user's public profile.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function get_profile( $req ) {
		self::boot( $req );

		$viewer = get_current_user_id();
		$target = (int) $req->get_param( 'user_id' );
		if ( ! $target ) {
			$target = $viewer;
		}

		$is_self = ( $target === $viewer );

		if ( ! $is_self && havato_is_blocked( $viewer, $target ) ) {
			return new WP_Error( 'havato_blocked', Havato_I18N::t( 'blocked_user' ), array( 'status' => 403 ) );
		}

		$profile = havato_get_profile( $target );
		$tags    = havato_interest_tags();

		$interests = array();
		foreach ( $profile['interests'] as $key ) {
			if ( isset( $tags[ $key ] ) ) {
				$interests[] = array( 'key' => $key ) + $tags[ $key ];
			}
		}

		$data = array(
			'user'          => self::user_card( $target ),
			'is_self'       => $is_self,
			'completed'     => (bool) $profile['completed'],
			'age'           => (int) $profile['age'],
			'gender'        => $profile['gender'],
			'country'       => isset( $profile['country'] ) ? $profile['country'] : '',
			'city'          => isset( $profile['city'] ) ? $profile['city'] : '',
			'city_label'    => havato_city_label( isset( $profile['city'] ) ? $profile['city'] : '' ),
			'phone'         => $is_self ? $profile['phone'] : '',
			'extroversion'  => (int) $profile['personality_extroversion'],
			'talkative'     => (int) $profile['personality_talkative'],
			'openness'      => (int) $profile['personality_openness'],
			'humor'         => (int) $profile['personality_humor'],
			'energy'        => (int) $profile['personality_energy'],
			'planning'      => (int) $profile['personality_planning'],
			'empathy'       => (int) $profile['personality_empathy'],
			'vibe'          => $profile['personality_vibe'],
			'interests'     => $interests,
			'rating'        => round( havato_effective_rating( $profile ), 1 ),
			'rating_count'  => (int) $profile['rating_count'],
			'no_shows'      => (int) $profile['no_show_count'],
			'empty_seats'   => (int) $profile['empty_seat_count'],
			'penalty'       => round( (float) $profile['penalty_points'], 1 ),
			'attended'      => (int) $profile['attended_count'],
			'photos'        => self::user_photos( $target, $viewer, $is_self ),
			'friend_status' => $is_self ? 'self' : havato_friend_status( $viewer, $target ),
			'gallery_open'  => $is_self ? true : self::can_view_gallery( $viewer, $target ),
		);

		if ( $is_self ) {
		}

		return self::ok( $data );
	}

	/**
	 * Save the one-shot personality test.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function save_test( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id = get_current_user_id();
		$table   = Havato_DB::table( 'user_profiles' );

		// The 30-second test is now purely psychometric. Name, age, country
		// and city are personal details and are edited from the profile
		// screen instead (see save_details), so answering the test can never
		// be blocked by a location list failing to load.
		$traits = array();
		foreach ( self::trait_keys() as $key ) {
			$traits[ 'personality_' . $key ] = max( 1, min( 10, (int) $req->get_param( $key ) ) );
		}

		$vibe = 'deep' === $req->get_param( 'vibe' ) ? 'deep' : 'fun';

		$raw_interests = $req->get_param( 'interests' );
		$raw_interests = is_array( $raw_interests ) ? $raw_interests : havato_json( $raw_interests );
		$allowed       = array_keys( havato_interest_tags() );
		$interests     = array_values( array_intersect( array_map( 'sanitize_key', $raw_interests ), $allowed ) );

		$data = array_merge(
			$traits,
			array(
				'user_id'               => $user_id,
				'personality_vibe'      => $vibe,
				'personality_interests' => wp_json_encode( $interests ),
				'completed'             => 1,
				'updated_at'            => havato_now(),
			)
		);

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$exists = $wpdb->get_var( $wpdb->prepare( "SELECT user_id FROM $table WHERE user_id=%d", $user_id ) );

		if ( $exists ) {
			unset( $data['user_id'] );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $table, $data, array( 'user_id' => $user_id ) );
		} else {
			$data['rating_score']   = 5;
			$data['blocklist_json'] = '[]';
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->insert( $table, $data );
		}

		Havato_Logger::log( sprintf( 'Personality profile stored for user %d.', $user_id ), 'info' );

		return self::ok( array( 'completed' => true ) );
	}

	/**
	 * The psychometric sliders, in the order the test asks them.
	 *
	 * Kept in one place so the REST layer, the matcher and the profile screen
	 * can never drift out of sync.
	 *
	 * @return array
	 */
	public static function trait_keys() {
		return array( 'extroversion', 'talkative', 'openness', 'humor', 'energy', 'planning', 'empathy' );
	}

	/**
	 * Save the personal details (name, age, gender, country, city, area).
	 *
	 * Deliberately separate from the personality test: these are facts about
	 * the person rather than answers, the user must be able to correct them
	 * later, and a failure here must never cost somebody their test answers.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function save_details( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id = get_current_user_id();
		$table   = Havato_DB::table( 'user_profiles' );

		$name = sanitize_text_field( (string) $req->get_param( 'name' ) );
		$name = trim( preg_replace( '/\s+/u', ' ', $name ) );
		if ( function_exists( 'mb_strlen' ) ? mb_strlen( $name ) < 2 : strlen( $name ) < 2 ) {
			return new WP_Error( 'havato_bad_name', Havato_I18N::t( 'err_name_short' ), array( 'status' => 400 ) );
		}
		$name = function_exists( 'mb_substr' ) ? mb_substr( $name, 0, 60 ) : substr( $name, 0, 60 );

		$age = (int) $req->get_param( 'age' );
		if ( $age < 18 || $age > 75 ) {
			return new WP_Error( 'havato_bad_age', Havato_I18N::t( 'err_age_range' ), array( 'status' => 400 ) );
		}

		// Only male/female are offered now; anything else is rejected rather
		// than silently stored, so the gender-balance term stays meaningful.
		$gender = sanitize_text_field( (string) $req->get_param( 'gender' ) );
		if ( ! in_array( $gender, array( 'male', 'female' ), true ) ) {
			return new WP_Error( 'havato_bad_gender', Havato_I18N::t( 'q_gender' ), array( 'status' => 400 ) );
		}

		// Country/city must be a pair we actually operate in, otherwise the
		// city filter would silently hide every event from this user.
		$country = sanitize_key( (string) $req->get_param( 'country' ) );
		$city    = sanitize_key( (string) $req->get_param( 'city' ) );
		if ( ! havato_valid_city( $country, $city ) ) {
			return new WP_Error( 'havato_bad_city', Havato_I18N::t( 'q_city_select' ), array( 'status' => 400 ) );
		}

		// Phone is required: it is how a café reaches a guest about their
		// booking. Stored normalised so "0912…", "+98912…" and "0098912…"
		// are one number rather than three.
		$phone = havato_normalize_phone( (string) $req->get_param( 'phone' ), $country );
		if ( '' === $phone ) {
			return new WP_Error( 'havato_bad_phone', Havato_I18N::t( 'err_phone' ), array( 'status' => 400 ) );
		}

		// One account per number, or a blocked guest could simply re-register.
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$clash = (int) $wpdb->get_var( $wpdb->prepare( "SELECT user_id FROM $table WHERE phone=%s AND user_id<>%d LIMIT 1", $phone, $user_id ) );
		if ( $clash ) {
			return new WP_Error( 'havato_phone_taken', Havato_I18N::t( 'err_phone_taken' ), array( 'status' => 409 ) );
		}

		// The display name lives on the WP user, not in the profile table, so
		// it stays correct everywhere the app already renders a name.
		wp_update_user(
			array(
				'ID'           => $user_id,
				'display_name' => $name,
			)
		);

		$data = array(
			'user_id'           => $user_id,
			'age'               => $age,
			'gender'            => $gender,
			'country'           => $country,
			'city'              => $city,
			'phone'             => $phone,
			'updated_at'        => havato_now(),
		);

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$exists = $wpdb->get_var( $wpdb->prepare( "SELECT user_id FROM $table WHERE user_id=%d", $user_id ) );

		if ( $exists ) {
			unset( $data['user_id'] );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $table, $data, array( 'user_id' => $user_id ) );
		} else {
			// Details saved before the test: seed the row without marking the
			// personality profile complete.
			$data['rating_score']   = 5;
			$data['blocklist_json'] = '[]';
			$data['completed']      = 0;
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->insert( $table, $data );
		}

		// First time a country is chosen, adopt its language as the default so
		// a Turkish guest gets a Turkish panel. Never overrides a language the
		// user has already picked themselves.
		if ( ! get_user_meta( $user_id, 'havato_lang', true ) ) {
			$implied = Havato_I18N::country_language( $user_id );
			if ( $implied ) {
				update_user_meta( $user_id, 'havato_lang', $implied );
			}
		}

		Havato_Logger::log( sprintf( 'Personal details updated for user %d.', $user_id ), 'info' );

		return self::ok(
			array(
				'saved' => true,
				'user'  => self::user_card( $user_id ),
				'city'  => $city,
				'map'   => self::map_center( $city ),
				'lang'  => Havato_I18N::current_lang(),
			)
		);
	}

	/**
	 * Permanently delete the caller's own account.
	 *
	 * Deliberately self-service only: it acts on the logged-in user and takes
	 * no user id, so it cannot be pointed at somebody else. Administrators are
	 * refused because deleting the last admin through an app screen would lock
	 * the site out; they can still be removed from wp-admin.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function delete_account( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id = get_current_user_id();

		if ( user_can( $user_id, 'manage_options' ) ) {
			return new WP_Error( 'havato_admin_delete', Havato_I18N::t( 'delete_admin_blocked' ), array( 'status' => 403 ) );
		}

		// The client asks twice; require it to say so, so a stray POST cannot
		// wipe an account.
		if ( 'DELETE' !== strtoupper( (string) $req->get_param( 'confirm' ) ) ) {
			return new WP_Error( 'havato_no_confirm', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}

		// Remove everything that belongs to this person. Group chat lines are
		// kept but anonymised, otherwise other guests' conversations would
		// develop holes.
		$chats = Havato_DB::table( 'chats' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update( $chats, array( 'sender_id' => 0, 'sender_name' => Havato_I18N::t( 'deleted_user' ) ), array( 'sender_id' => $user_id ), array( '%d', '%s' ), array( '%d' ) );

		// These all key on user_id.
		foreach ( array( 'user_profiles', 'event_registrations', 'group_members', 'user_photos', 'photo_likes' ) as $table ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->delete( Havato_DB::table( $table ), array( 'user_id' => $user_id ), array( '%d' ) );
		}

		// photo_reports keys on reporter_id, not user_id.
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( Havato_DB::table( 'photo_reports' ), array( 'reporter_id' => $user_id ), array( '%d' ) );

		$friends = Havato_DB::table( 'friends' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$wpdb->query( $wpdb->prepare( "DELETE FROM $friends WHERE user_id=%d OR friend_id=%d", $user_id, $user_id ) );

		$pm = Havato_DB::table( 'private_chats' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$wpdb->query( $wpdb->prepare( "DELETE FROM $pm WHERE sender_id=%d OR receiver_id=%d", $user_id, $user_id ) );

		$feedbacks = Havato_DB::table( 'feedbacks' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$wpdb->query( $wpdb->prepare( "DELETE FROM $feedbacks WHERE reporter_id=%d OR reported_id=%d", $user_id, $user_id ) );

		Havato_Logger::log( sprintf( 'Account %d deleted at the user\'s own request.', $user_id ), 'info' );

		require_once ABSPATH . 'wp-admin/includes/user.php';
		wp_logout();
		wp_delete_user( $user_id );

		return self::ok( array( 'deleted' => true ) );
	}

	/**
	 * Upload/replace the avatar.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function upload_avatar( $req ) {
		self::boot( $req );

		$url = self::handle_upload( 'file' );
		if ( is_wp_error( $url ) ) {
			return $url;
		}

		update_user_meta( get_current_user_id(), 'havato_avatar', $url );

		return self::ok( array( 'url' => $url ) );
	}

	/**
	 * Add a photo to the gallery.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function upload_photo( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id = get_current_user_id();

		$url = self::handle_upload( 'file' );
		if ( is_wp_error( $url ) ) {
			return $url;
		}

		$status = (int) Havato_Settings::get( 'photo_auto_approve', 1 ) ? 'approved' : 'pending';
		$table  = Havato_DB::table( 'user_photos' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert(
			$table,
			array(
				'user_id'    => $user_id,
				'photo_url'  => $url,
				'status'     => $status,
				'created_at' => havato_now(),
			),
			array( '%d', '%s', '%s', '%s' )
		);

		return self::ok(
			array(
				'photo' => array(
					'id'     => (int) $wpdb->insert_id,
					'url'    => $url,
					'status' => $status,
					'likes'  => 0,
					'liked'  => false,
					'mine'   => true,
				),
			)
		);
	}

	/**
	 * Toggle a like (one per user & photo, enforced by a unique index).
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function like_photo( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id  = get_current_user_id();
		$photo_id = (int) $req->get_param( 'photo_id' );

		$likes  = Havato_DB::table( 'photo_likes' );
		$photos = Havato_DB::table( 'user_photos' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$owner = (int) $wpdb->get_var( $wpdb->prepare( "SELECT user_id FROM $photos WHERE id=%d", $photo_id ) );
		if ( ! $owner ) {
			return new WP_Error( 'havato_no_photo', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}
		// Same gallery visibility rule as user_photos(): you can only like a
		// photo you are actually allowed to see (own photo or accepted friend).
		if ( ! self::can_view_gallery( $user_id, $owner ) ) {
			return new WP_Error( 'havato_blocked', Havato_I18N::t( 'blocked_user' ), array( 'status' => 403 ) );
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$existing = (int) $wpdb->get_var( $wpdb->prepare( "SELECT id FROM $likes WHERE photo_id=%d AND user_id=%d", $photo_id, $user_id ) );

		if ( $existing ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->delete( $likes, array( 'id' => $existing ), array( '%d' ) );
			$liked = false;
		} else {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->insert(
				$likes,
				array(
					'photo_id'   => $photo_id,
					'user_id'    => $user_id,
					'created_at' => havato_now(),
				),
				array( '%d', '%d', '%s' )
			);
			$liked = true;
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$count = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM $likes WHERE photo_id=%d", $photo_id ) );

		return self::ok( array( 'liked' => $liked, 'likes' => $count ) );
	}

	/**
	 * Report a photo.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function report_photo( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id  = get_current_user_id();
		$photo_id = (int) $req->get_param( 'photo_id' );
		$reason   = sanitize_text_field( (string) $req->get_param( 'reason' ) );

		$photos_t = Havato_DB::table( 'user_photos' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$owner = (int) $wpdb->get_var( $wpdb->prepare( "SELECT user_id FROM $photos_t WHERE id=%d", $photo_id ) );

		if ( ! $owner ) {
			return new WP_Error( 'havato_no_photo', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}
		// Only a viewer who can legitimately see the photo may report it.
		if ( ! self::can_view_gallery( $user_id, $owner ) ) {
			return new WP_Error( 'havato_blocked', Havato_I18N::t( 'blocked_user' ), array( 'status' => 403 ) );
		}

		$table = Havato_DB::table( 'photo_reports' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert(
			$table,
			array(
				'photo_id'    => $photo_id,
				'reporter_id' => $user_id,
				'reason'      => $reason,
				'status'      => 'pending',
				'created_at'  => havato_now(),
			),
			array( '%d', '%d', '%s', '%s', '%s' )
		);

		$photos = Havato_DB::table( 'user_photos' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update( $photos, array( 'status' => 'reported' ), array( 'id' => $photo_id ), array( '%s' ), array( '%d' ) );

		Havato_Logger::log( sprintf( 'Photo #%d reported by user %d (%s).', $photo_id, $user_id, $reason ), 'warn' );

		return self::ok( array( 'reported' => true, 'message' => Havato_I18N::t( 'report_sent' ) ) );
	}

	/**
	 * Delete one of your own photos.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function delete_photo( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id  = get_current_user_id();
		$photo_id = (int) $req->get_param( 'photo_id' );
		$photos   = Havato_DB::table( 'user_photos' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $photos, array( 'id' => $photo_id, 'user_id' => $user_id ), array( '%d', '%d' ) );

		return self::ok( array( 'deleted' => true ) );
	}

	/* =====================================================================
	 * Chat moderation
	 * ================================================================== */

	/**
	 * Report a chat message.
	 *
	 * The reporter must be able to see the message in the first place, so the
	 * same membership/friendship rules as reading apply. A copy of the text is
	 * stored with the report: the sender can edit nothing, but the row may be
	 * anonymised later if they delete their account, and a moderator still
	 * needs to see what was actually said.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function report_message( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id    = get_current_user_id();
		$scope      = 'private' === $req->get_param( 'scope' ) ? 'private' : 'group';
		$message_id = (int) $req->get_param( 'message_id' );
		$reason     = sanitize_text_field( (string) $req->get_param( 'reason' ) );

		$allowed = array( 'nudity', 'fake', 'spam', 'other' );
		$reason  = in_array( $reason, $allowed, true ) ? $reason : 'other';

		if ( $message_id <= 0 ) {
			return new WP_Error( 'havato_no_message', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}

		if ( 'group' === $scope ) {
			$chats = Havato_DB::table( 'chats' );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$row = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $chats WHERE id=%d", $message_id ), ARRAY_A );
			if ( ! $row || ! self::is_group_member( $row['group_id'], $user_id ) ) {
				return new WP_Error( 'havato_forbidden', Havato_I18N::t( 'blocked_user' ), array( 'status' => 403 ) );
			}
		} else {
			$pm = Havato_DB::table( 'private_chats' );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$row = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $pm WHERE id=%d", $message_id ), ARRAY_A );
			// Only the two people in the thread may report it.
			if ( ! $row || ( (int) $row['sender_id'] !== $user_id && (int) $row['receiver_id'] !== $user_id ) ) {
				return new WP_Error( 'havato_forbidden', Havato_I18N::t( 'blocked_user' ), array( 'status' => 403 ) );
			}
		}

		$sender = (int) $row['sender_id'];
		if ( $sender === $user_id ) {
			return new WP_Error( 'havato_self_report', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}

		$reports = Havato_DB::table( 'message_reports' );

		// UNIQUE(scope,message_id,reporter_id) makes this idempotent, so a
		// double tap cannot flood the queue.
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->replace(
			$reports,
			array(
				'scope'       => $scope,
				'message_id'  => $message_id,
				'reporter_id' => $user_id,
				'reported_id' => $sender,
				'reason'      => $reason,
				// Decoded defensively: only guest text can reach here, but the
				// queue must never show a moderator a raw JSON blob.
				'excerpt'     => havato_clamp_text(
					havato_message_text( (string) $row['message_text'], ! empty( $row['is_system'] ) ),
					500
				),
				'status'      => 'pending',
				'created_at'  => havato_now(),
			),
			array( '%s', '%d', '%d', '%d', '%s', '%s', '%s', '%s' )
		);

		Havato_Logger::log( sprintf( 'Message %d (%s) reported by user %d.', $message_id, $scope, $user_id ), 'warn' );

		return self::ok( array( 'reported' => true ) );
	}

	/**
	 * Block another guest.
	 *
	 * A block is one-directional in intent but enforced both ways by
	 * havato_is_blocked(): neither person is matched with, or can message,
	 * the other again.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function block_user( $req ) {
		self::boot( $req );

		$user_id = get_current_user_id();
		$target  = (int) $req->get_param( 'user_id' );

		if ( $target <= 0 || $target === $user_id ) {
			return new WP_Error( 'havato_bad_target', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}

		self::add_to_blocklist( $user_id, $target );

		// A block also ends any friendship, otherwise the private thread would
		// stay open from the other side.
		global $wpdb;
		$friends = Havato_DB::table( 'friends' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$wpdb->query(
			$wpdb->prepare(
				"DELETE FROM $friends WHERE (user_id=%d AND friend_id=%d) OR (user_id=%d AND friend_id=%d)",
				$user_id,
				$target,
				$target,
				$user_id
			)
		);

		Havato_Logger::log( sprintf( 'User %d blocked user %d.', $user_id, $target ), 'info' );

		return self::ok( array( 'blocked' => true ) );
	}

	/**
	 * Undo a block.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function unblock_user( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id = get_current_user_id();
		$target  = (int) $req->get_param( 'user_id' );

		if ( $target <= 0 ) {
			return new WP_Error( 'havato_bad_target', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}

		$profiles = Havato_DB::table( 'user_profiles' );
		$profile  = havato_get_profile( $user_id );
		$list     = array_values( array_diff( $profile['blocklist'], array( $target ) ) );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update( $profiles, array( 'blocklist_json' => wp_json_encode( $list ) ), array( 'user_id' => $user_id ), array( '%s' ), array( '%d' ) );

		return self::ok( array( 'unblocked' => true, 'blocked' => $list ) );
	}

	/**
	 * Resolve a reported message (administrator).
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function admin_chat_report( $req ) {
		self::boot( $req );

		global $wpdb;
		$id     = (int) $req->get_param( 'report_id' );
		$action = sanitize_key( (string) $req->get_param( 'action_type' ) );

		$reports = Havato_DB::table( 'message_reports' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$report = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $reports WHERE id=%d", $id ), ARRAY_A );

		if ( ! $report ) {
			return self::ok( array( 'done' => false ) );
		}

		if ( 'delete' === $action ) {
			// Blank the message rather than removing the row, so the rest of
			// the conversation keeps its order and context.
			$table = 'private' === $report['scope']
				? Havato_DB::table( 'private_chats' )
				: Havato_DB::table( 'chats' );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $table, array( 'message_text' => Havato_I18N::t( 'message_removed' ) ), array( 'id' => (int) $report['message_id'] ), array( '%s' ), array( '%d' ) );
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update( $reports, array( 'status' => 'delete' === $action ? 'removed' : 'kept' ), array( 'id' => $id ), array( '%s' ), array( '%d' ) );

		Havato_Logger::log( sprintf( 'Chat report %d resolved (%s).', $id, $action ), 'info' );

		return self::ok( array( 'done' => true ) );
	}

	/* =====================================================================
	 * Friends
	 * ================================================================== */

	/**
	 * Friend list + incoming requests.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function get_friends( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id = get_current_user_id();
		$table   = Havato_DB::table( 'friends' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$pending = $wpdb->get_results( $wpdb->prepare( "SELECT * FROM $table WHERE friend_id=%d AND status='pending'", $user_id ), ARRAY_A );

		$requests = array();
		foreach ( (array) $pending as $row ) {
			if ( havato_is_blocked( $user_id, (int) $row['user_id'] ) ) {
				continue;
			}
			$requests[] = array(
				'id'   => (int) $row['id'],
				'user' => self::user_card( (int) $row['user_id'] ),
			);
		}

		return self::ok(
			array(
				'friends'  => self::friend_threads( $user_id ),
				'requests' => $requests,
			)
		);
	}

	/**
	 * Send a friend request.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function friend_request( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id = get_current_user_id();
		$target  = (int) $req->get_param( 'user_id' );

		if ( ! $target || $target === $user_id ) {
			return new WP_Error( 'havato_bad_target', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}

		// HARD CONSTRAINT: blocked in either direction → no friendship at all.
		if ( havato_is_blocked( $user_id, $target ) ) {
			return new WP_Error( 'havato_blocked', Havato_I18N::t( 'blocked_user' ), array( 'status' => 403 ) );
		}

		$status = havato_friend_status( $user_id, $target );
		if ( in_array( $status, array( 'accepted', 'pending_out' ), true ) ) {
			return self::ok( array( 'status' => $status ) );
		}

		if ( 'pending_in' === $status ) {
			return self::friend_accept_pair( $target, $user_id );
		}

		$table = Havato_DB::table( 'friends' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->replace(
			$table,
			array(
				'user_id'    => $user_id,
				'friend_id'  => $target,
				'status'     => 'pending',
				'created_at' => havato_now(),
			),
			array( '%d', '%d', '%s', '%s' )
		);

		return self::ok( array( 'status' => 'pending_out' ) );
	}

	/**
	 * Accept / reject an incoming request.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function friend_respond( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id = get_current_user_id();
		$from    = (int) $req->get_param( 'user_id' );
		$accept  = (bool) $req->get_param( 'accept' );

		$table = Havato_DB::table( 'friends' );

		if ( $accept && ! havato_is_blocked( $user_id, $from ) ) {
			return self::friend_accept_pair( $from, $user_id );
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update(
			$table,
			array( 'status' => 'rejected' ),
			array( 'user_id' => $from, 'friend_id' => $user_id ),
			array( '%s' ),
			array( '%d', '%d' )
		);

		return self::ok( array( 'status' => 'rejected' ) );
	}

	/* =====================================================================
	 * Post-event feedback
	 * ================================================================== */

	/**
	 * Pending feedback cards for the current user.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function pending_feedback( $req ) {
		self::boot( $req );
		return self::ok( array( 'items' => self::collect_pending_feedback( get_current_user_id() ) ) );
	}

	/**
	 * Store one feedback entry (rating + comment + optional block).
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function submit_feedback( $req ) {
		self::boot( $req );

		global $wpdb;
		$user_id  = get_current_user_id();
		$group_id = sanitize_text_field( (string) $req->get_param( 'group_id' ) );
		$target   = (int) $req->get_param( 'user_id' );
		$rating   = max( 1, min( 5, (int) $req->get_param( 'rating' ) ) );
		$comment  = havato_clamp_text( sanitize_textarea_field( (string) $req->get_param( 'comment' ) ), 500 );
		$block    = (bool) $req->get_param( 'block' );

		if ( ! self::is_group_member( $group_id, $user_id ) || ! self::is_group_member( $group_id, $target ) ) {
			return new WP_Error( 'havato_forbidden', Havato_I18N::t( 'error_generic' ), array( 'status' => 403 ) );
		}

		$table = Havato_DB::table( 'feedbacks' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->replace(
			$table,
			array(
				'group_id'    => $group_id,
				'reporter_id' => $user_id,
				'reported_id' => $target,
				'rating'      => $rating,
				'comment'     => $comment,
				'is_block'    => $block ? 1 : 0,
				'created_at'  => havato_now(),
			),
			array( '%s', '%d', '%d', '%d', '%s', '%d', '%s' )
		);

		self::recalculate_rating( $target );

		if ( $block ) {
			self::add_to_blocklist( $user_id, $target );
		}

		return self::ok( array( 'saved' => true, 'message' => Havato_I18N::t( 'feedback_sent' ) ) );
	}

	/* =====================================================================
	 * Owner portal
	 * ================================================================== */

	/**
	 * Register a partner café (creates the user + venue and logs in instantly).
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_register( $req ) {
		self::boot( $req );

		global $wpdb;

		// Registration is public, so the same IP throttle applies — otherwise
		// a script could flood the approvals queue with fake cafés.
		if ( ! current_user_can( 'manage_options' ) ) {
			$throttle = self::check_login_throttle();
			if ( is_wp_error( $throttle ) ) {
				return $throttle;
			}
		}

		$email   = sanitize_email( (string) $req->get_param( 'email' ) );
		$pass    = (string) $req->get_param( 'password' );
		$name    = sanitize_text_field( (string) $req->get_param( 'venue_name' ) );
		$manager = sanitize_text_field( (string) $req->get_param( 'manager_name' ) );
		$country = sanitize_key( (string) $req->get_param( 'country' ) );
		$city    = sanitize_key( (string) $req->get_param( 'city' ) );
		$addr    = havato_clamp_text( sanitize_textarea_field( (string) $req->get_param( 'address' ) ), 300 );

		$storefront = esc_url_raw( (string) $req->get_param( 'storefront_photo' ) );

		if ( ! is_email( $email ) || strlen( $pass ) < 6 || '' === $name || '' === $manager || ! havato_valid_city( $country, $city ) ) {
			return new WP_Error( 'havato_bad_input', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}

		if ( email_exists( $email ) ) {
			return new WP_Error( 'havato_email_exists', Havato_I18N::t( 'error_generic' ), array( 'status' => 409 ) );
		}

		$login = sanitize_user( preg_replace( '/@.*/', '', $email ) . '_cafe', true );
		$i     = 1;
		while ( username_exists( $login ) ) {
			$login = $login . $i;
			$i++;
		}

		$uid = wp_insert_user(
			array(
				'user_login'   => $login,
				'user_email'   => $email,
				'user_pass'    => $pass,
				'display_name' => $manager,
				'role'         => 'cafe_owner',
			)
		);

		if ( is_wp_error( $uid ) ) {
			return $uid;
		}

		$venue_id = havato_uid( 'v' );
		$venues   = Havato_DB::table( 'venues' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert(
			$venues,
			array(
				'id'           => $venue_id,
				'name'         => $name,
				'manager_name' => $manager,
				'country'      => $country,
				'city'         => $city,
				'storefront_photo' => $storefront,
				'address'      => $addr,
				'lat'          => (float) Havato_Settings::get( 'map_center_lat', 35.7219 ),
				'lng'          => (float) Havato_Settings::get( 'map_center_lng', 51.3347 ),
				'budget_tier'  => 'medium',
				'verified'     => 0,
				'manager_id'   => (int) $uid,
				'menu_json'    => '[]',
				'created_at'   => havato_now(),
			),
			array( '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%f', '%f', '%s', '%d', '%d', '%s', '%s' )
		);

		// Instant session — no second login required after a refresh.
		Havato_Google_Auth::force_login( $uid );

		Havato_Logger::log( sprintf( 'New partner café registered: %s (pending verification).', $name ), 'info' );

		return self::ok(
			array(
				'user'  => self::user_card( $uid ),
				'venue' => self::venue_payload( self::owner_venue( $uid ), true ),
			)
		);
	}


	/* =====================================================================
	 * Login throttling (owner auth page)
	 * ================================================================== */

	/**
	 * Transient key for the caller's IP.
	 *
	 * @return string
	 */
	private static function throttle_key() {
		$ip = '';
		if ( ! empty( $_SERVER['REMOTE_ADDR'] ) ) {
			$ip = sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ) );
		}
		return 'havato_login_fail_' . md5( $ip );
	}

	/**
	 * Refuse further attempts once the limit is hit.
	 *
	 * @return true|WP_Error
	 */
	private static function check_login_throttle() {
		$max   = (int) apply_filters( 'havato_login_max_attempts', 5 );
		$tries = (int) get_transient( self::throttle_key() );

		if ( $tries >= $max ) {
			return new WP_Error(
				'havato_too_many',
				Havato_I18N::t( 'login_throttled' ),
				array( 'status' => 429 )
			);
		}
		return true;
	}

	/**
	 * Count a failed attempt (window: 15 minutes, sliding).
	 */
	private static function record_failed_login() {
		$key     = self::throttle_key();
		$window  = (int) apply_filters( 'havato_login_window', 15 * MINUTE_IN_SECONDS );
		$tries   = (int) get_transient( $key );
		set_transient( $key, $tries + 1, $window );
	}

	/**
	 * Reset the counter after a successful login.
	 */
	private static function clear_login_throttle() {
		delete_transient( self::throttle_key() );
	}

	/**
	 * Café owner sign-in.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_login( $req ) {
		self::boot( $req );

		// Brute-force guard: this endpoint is public, so throttle by IP before
		// touching the password at all.
		$throttle = self::check_login_throttle();
		if ( is_wp_error( $throttle ) ) {
			return $throttle;
		}

		$email = sanitize_text_field( (string) $req->get_param( 'email' ) );
		$pass  = (string) $req->get_param( 'password' );

		$user = wp_authenticate( $email, $pass );
		if ( is_wp_error( $user ) ) {
			self::record_failed_login();
			return new WP_Error( 'havato_login_failed', Havato_I18N::t( 'login_failed' ), array( 'status' => 401 ) );
		}

		// HARD CONSTRAINT: this door is for café owners only. Without this an
		// administrator could be signed in through a public, unthrottled
		// endpoint — a privilege-escalation path that bypasses wp-login.php
		// entirely. Admins must use the normal WordPress login.
		if ( ! in_array( 'cafe_owner', (array) $user->roles, true ) ) {
			self::record_failed_login();
			return new WP_Error( 'havato_not_owner', Havato_I18N::t( 'login_owner_only' ), array( 'status' => 403 ) );
		}

		self::clear_login_throttle();
		Havato_Google_Auth::force_login( $user->ID );

		$venue = self::owner_venue( $user->ID );

		return self::ok(
			array(
				'user'  => self::user_card( $user->ID ),
				'role'  => havato_user_role( $user->ID ),
				'venue' => $venue ? self::venue_payload( $venue, true ) : null,
			)
		);
	}

	/**
	 * Owner KPI dashboard.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_dashboard( $req ) {
		self::boot( $req );

		global $wpdb;
		$venue = self::owner_venue( get_current_user_id() );
		if ( ! $venue ) {
			return new WP_Error( 'havato_no_venue', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		$events = Havato_DB::table( 'events' );
		$regs   = Havato_DB::table( 'event_registrations' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$upcoming = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM $events WHERE venue_id=%s AND event_date >= CURDATE()", $venue['id'] ) );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$checked = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM $regs r INNER JOIN $events e ON e.id=r.event_id WHERE e.venue_id=%s AND r.checked_in=1", $venue['id'] ) );

		return self::ok(
			array(
				'venue'    => self::venue_payload( $venue, true ),
				'stats'    => array(
					'utilization'   => (int) $venue['utilization'],
					'guests_routed' => (int) $venue['guests_routed'],
					'upcoming'      => $upcoming,
					'checked_in'    => $checked,
				),
			)
		);
	}

	/**
	 * Events of the owner's venue.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_events( $req ) {
		self::boot( $req );

		global $wpdb;
		$venue = self::owner_venue( get_current_user_id() );
		if ( ! $venue ) {
			return new WP_Error( 'havato_no_venue', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		$events = Havato_DB::table( 'events' );
		$regs   = Havato_DB::table( 'event_registrations' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT e.*, (SELECT COALESCE(SUM(r.seats),0) FROM $regs r WHERE r.event_id=e.id AND r.status<>'cancelled') AS taken
				 FROM $events e WHERE e.venue_id=%s ORDER BY e.event_date DESC LIMIT 60",
				$venue['id']
			),
			ARRAY_A
		);

		$out = array();
		foreach ( (array) $rows as $row ) {
			$row['venue_name']    = $venue['name'];
			$row['venue_image']   = $venue['image'];
			$out[]                = self::event_payload( $row, 0 );
		}

		return self::ok( array( 'events' => $out ) );
	}

	/**
	 * Members seated at one event of this venue (+ check-in state).
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_event( $req ) {
		self::boot( $req );

		global $wpdb;
		$venue = self::owner_venue( get_current_user_id() );
		if ( ! $venue ) {
			return new WP_Error( 'havato_no_venue', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		$event_id = sanitize_text_field( (string) $req->get_param( 'event_id' ) );
		$events   = Havato_DB::table( 'events' );
		$regs     = Havato_DB::table( 'event_registrations' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$event = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $events WHERE id=%s AND venue_id=%s", $event_id, $venue['id'] ), ARRAY_A );
		if ( ! $event ) {
			return new WP_Error( 'havato_no_event', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results( $wpdb->prepare( "SELECT * FROM $regs WHERE event_id=%s AND status <> 'cancelled' ORDER BY id ASC", $event_id ), ARRAY_A );

		$members = array();
		foreach ( (array) $rows as $row ) {
			$profile   = havato_get_profile( (int) $row['user_id'] );
			$members[] = array(
				'user'       => self::user_card( (int) $row['user_id'] ),
				'status'     => $row['status'],
				'checked_in' => (bool) $row['checked_in'],
				'rating'     => round( havato_effective_rating( $profile ), 1 ),
			);
		}

		$event['venue_name']    = $venue['name'];
		$event['taken']         = count( $members );

		return self::ok(
			array(
				'event'   => self::event_payload( $event, 0 ),
				'members' => $members,
			)
		);
	}


	/**
	 * The café's physical tables.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_get_tables( $req ) {
		self::boot( $req );

		$venue = self::owner_venue( get_current_user_id() );
		if ( ! $venue ) {
			return new WP_Error( 'havato_no_venue', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		return self::ok(
			array(
				'tables' => self::venue_tables( $venue['id'] ),
				'locked' => self::tables_locked_by( $venue['id'] ),
			)
		);
	}

	/**
	 * Replace the café's table list.
	 *
	 * Rows are rewritten wholesale, but ids are preserved where the client
	 * sends them so existing events keep pointing at the same table.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_save_tables( $req ) {
		self::boot( $req );

		global $wpdb;
		$venue = self::owner_venue( get_current_user_id() );
		if ( ! $venue ) {
			return new WP_Error( 'havato_no_venue', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		// HARD CONSTRAINT: the furniture cannot change while an event is still
		// running on it, otherwise a seated group could lose its table or the
		// capacity of a live event would silently shift under the guests.
		$locked = self::tables_locked_by( $venue['id'] );
		if ( ! empty( $locked ) ) {
			return new WP_Error(
				'havato_tables_locked',
				sprintf( Havato_I18N::t( 'tables_locked' ), count( $locked ) ),
				array( 'status' => 409, 'events' => $locked )
			);
		}

		$items = $req->get_param( 'tables' );
		$items = is_array( $items ) ? $items : havato_json( $items );
		$table = Havato_DB::table( 'venue_tables' );

		$keep  = array();
		$seen  = array();

		foreach ( $items as $item ) {
			if ( ! is_array( $item ) ) {
				continue;
			}

			$seats  = max( 2, min( 20, isset( $item['seats'] ) ? (int) $item['seats'] : 4 ) );
			$number = isset( $item['table_number'] ) ? (int) $item['table_number'] : 0;

			// The number is the one painted on the table in the room, so it is
			// required and never invented for the café.
			if ( $number < 1 || $number > 999 ) {
				return new WP_Error(
					'havato_table_number_required',
					Havato_I18N::t( 'table_number_required' ),
					array( 'status' => 400 )
				);
			}
			$label  = isset( $item['label'] ) ? sanitize_text_field( $item['label'] ) : '';
			$id     = isset( $item['id'] ) ? (int) $item['id'] : 0;

			// Table numbers identify a physical table, so they must be unique
			// within the café; a duplicate would make check-in ambiguous.
			if ( isset( $seen[ $number ] ) ) {
				return new WP_Error(
					'havato_duplicate_number',
					sprintf( Havato_I18N::t( 'table_number_duplicate' ), $number ),
					array( 'status' => 400 )
				);
			}
			$seen[ $number ] = true;

			$data = array(
				'venue_id'     => $venue['id'],
				'table_number' => $number,
				'label'        => $label,
				'seats'        => $seats,
				'quantity'     => 1,
				'active'       => 1,
			);

			if ( $id ) {
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->update( $table, $data, array( 'id' => $id, 'venue_id' => $venue['id'] ), array( '%s', '%d', '%s', '%d', '%d', '%d' ), array( '%d', '%s' ) );
				$keep[] = $id;
			} else {
				$data['created_at'] = havato_now();
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->insert( $table, $data, array( '%s', '%d', '%s', '%d', '%d', '%d', '%s' ) );
				$keep[] = (int) $wpdb->insert_id;
			}
		}

		// Retire anything the owner removed. Soft-delete (active = 0) rather
		// than DELETE, so past events that referenced the table still resolve.
		if ( ! empty( $keep ) ) {
			$ph = implode( ',', array_fill( 0, count( $keep ), '%d' ) );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$wpdb->query(
				$wpdb->prepare(
					"UPDATE $table SET active = 0 WHERE venue_id = %s AND id NOT IN ($ph)",
					array_merge( array( $venue['id'] ), $keep )
				)
			);
		} else {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $table, array( 'active' => 0 ), array( 'venue_id' => $venue['id'] ), array( '%d' ), array( '%s' ) );
		}

		return self::ok( array( 'tables' => self::venue_tables( $venue['id'] ) ) );
	}


	/**
	 * Events that currently hold this café's tables.
	 *
	 * "Active" means an event that has not happened yet or is still being
	 * matched: open, matched, or pending_admin with a future date. Completed
	 * events are historical, so they never block editing.
	 *
	 * @param string $venue_id Venue id.
	 * @return array Blocking events (id + label), empty when editing is safe.
	 */
	public static function tables_locked_by( $venue_id ) {
		global $wpdb;
		Havato_DB::ensure_tables();

		$events = Havato_DB::table( 'events' );
		$lang   = Havato_I18N::current_lang();

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT id, title, event_date, event_time
				 FROM $events
				 WHERE venue_id = %s
				   AND status IN ('open','matched','pending_admin')
				   AND TIMESTAMP(event_date, event_time) >= DATE_SUB(NOW(), INTERVAL 6 HOUR)
				 ORDER BY event_date ASC",
				$venue_id
			),
			ARRAY_A
		);

		$out = array();
		foreach ( (array) $rows as $row ) {
			$out[] = array(
				'id'    => $row['id'],
				'label' => ( '' !== trim( (string) $row['title'] ) ? $row['title'] . ' — ' : '' )
					. Havato_Jalali::format( $row['event_date'], $lang )
					. ' ' . substr( $row['event_time'], 0, 5 ),
			);
		}

		return $out;
	}

	/**
	 * Active tables of a venue.
	 *
	 * @param string $venue_id Venue id.
	 * @return array
	 */
	public static function venue_tables( $venue_id ) {
		global $wpdb;
		Havato_DB::ensure_tables();

		$table = Havato_DB::table( 'venue_tables' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			$wpdb->prepare( "SELECT * FROM $table WHERE venue_id = %s AND active = 1 ORDER BY table_number ASC, id ASC", $venue_id ),
			ARRAY_A
		);

		return array_map(
			function ( $row ) {
				return array(
					'id'           => (int) $row['id'],
					'table_number' => (int) $row['table_number'],
					'label'        => $row['label'],
					'seats'        => (int) $row['seats'],
					'quantity'     => (int) $row['quantity'],
				);
			},
			(array) $rows
		);
	}

	/**
	 * Tables assigned to one event.
	 *
	 * @param string $event_id Event id.
	 * @return array
	 */
	/**
	 * Seats of the largest single table assigned to an event.
	 *
	 * A booking is seated as one group, so this is the ceiling on a party.
	 *
	 * @param array $event Event row.
	 * @return int
	 */
	public static function largest_table_seats( $event ) {
		$max = 0;
		foreach ( self::event_tables( $event['id'] ) as $row ) {
			$max = max( $max, (int) $row['seats'] );
		}
		// Legacy events carry no furniture: fall back to the stated capacity.
		if ( $max <= 0 ) {
			$max = (int) $event['max_capacity'];
		}
		return max( 1, $max );
	}

	public static function event_tables( $event_id ) {
		global $wpdb;
		Havato_DB::ensure_tables();

		$et = Havato_DB::table( 'event_tables' );
		$vt = Havato_DB::table( 'venue_tables' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT et.*, vt.label, vt.table_number FROM $et et
				 LEFT JOIN $vt vt ON vt.id = et.table_id
				 WHERE et.event_id = %s ORDER BY vt.table_number ASC",
				$event_id
			),
			ARRAY_A
		);

		return array_map(
			function ( $row ) {
				return array(
					'table_id'     => (int) $row['table_id'],
					'table_number' => (int) $row['table_number'],
					'label'        => $row['label'],
					'seats'        => (int) $row['seats'],
					'quantity'     => (int) $row['quantity'],
				);
			},
			(array) $rows
		);
	}

	/**
	 * Create a new social table for the owner's venue.
	 *
	 * Unverified venues can prepare events, but they stay `pending_admin`
	 * (invisible to guests) until the venue itself is verified.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_create_event( $req ) {
		self::boot( $req );

		global $wpdb;
		$venue = self::owner_venue( get_current_user_id() );
		if ( ! $venue ) {
			return new WP_Error( 'havato_no_venue', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		$date = sanitize_text_field( (string) $req->get_param( 'event_date' ) );
		$time = sanitize_text_field( (string) $req->get_param( 'event_time' ) );

		if ( ! preg_match( '/^\d{4}-\d{2}-\d{2}$/', $date ) ) {
			return new WP_Error( 'havato_bad_date', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}
		if ( ! preg_match( '/^\d{2}:\d{2}(:\d{2})?$/', $time ) ) {
			return new WP_Error( 'havato_bad_time', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}
		if ( 5 === strlen( $time ) ) {
			$time .= ':00';
		}

		$tier = sanitize_text_field( (string) $req->get_param( 'budget_tier' ) );
		$tier = in_array( $tier, array( 'low', 'medium', 'high' ), true ) ? $tier : $venue['budget_tier'];

		// Tables selected for this event. Capacity is DERIVED from the real
		// furniture (3 x 4-seater = 12) rather than typed in, so the matcher
		// can seat one group per physical table instead of one giant group.
		$picked = $req->get_param( 'tables' );
		$picked = is_array( $picked ) ? $picked : havato_json( $picked );

		$available = array();
		foreach ( self::venue_tables( $venue['id'] ) as $vt ) {
			$available[ (int) $vt['id'] ] = $vt;
		}

		$chosen   = array();
		$capacity = 0;

		foreach ( (array) $picked as $row ) {
			$tid = isset( $row['table_id'] ) ? (int) $row['table_id'] : 0;
			$qty = isset( $row['quantity'] ) ? (int) $row['quantity'] : 0;

			if ( $qty < 1 || ! isset( $available[ $tid ] ) ) {
				continue;
			}
			// Never allow more copies than the café actually owns.
			$qty = min( $qty, (int) $available[ $tid ]['quantity'] );

			$chosen[] = array(
				'table_id' => $tid,
				'seats'    => (int) $available[ $tid ]['seats'],
				'quantity' => $qty,
			);
			$capacity += (int) $available[ $tid ]['seats'] * $qty;
		}

		// Backwards compatible: a café that has not defined any furniture yet
		// can still publish an event with a plain seat count.
		if ( empty( $chosen ) ) {
			$capacity = max( 2, min( 60, (int) $req->get_param( 'max_capacity' ) ) );
		}

		if ( $capacity < 2 ) {
			return new WP_Error( 'havato_no_tables', Havato_I18N::t( 'event_need_tables' ), array( 'status' => 400 ) );
		}

		$theme = sanitize_text_field( (string) $req->get_param( 'theme' ) );
		$image = esc_url_raw( (string) $req->get_param( 'image' ) );

		$event_id = havato_uid( 'e' );
		$events   = Havato_DB::table( 'events' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert(
			$events,
			array(
				'id'           => $event_id,
				'venue_id'     => $venue['id'],
				'title'        => sanitize_text_field( (string) $req->get_param( 'title' ) ),
				'theme'        => $theme,
				'image'        => $image,
				'event_date'   => $date,
				'event_time'   => $time,
				'budget_tier'  => $tier,
				'max_capacity' => $capacity,
				'status'       => $venue['verified'] ? 'open' : 'pending_admin',
				'created_at'   => havato_now(),
			),
			array( '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%d', '%d', '%s', '%s' )
		);

		// Persist the chosen furniture for the matcher and the guest list.
		if ( ! empty( $chosen ) ) {
			$et = Havato_DB::table( 'event_tables' );
			foreach ( $chosen as $row ) {
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->insert(
					$et,
					array(
						'event_id' => $event_id,
						'table_id' => $row['table_id'],
						'seats'    => $row['seats'],
						'quantity' => $row['quantity'],
					),
					array( '%s', '%d', '%d', '%d' )
				);
			}
		}

		Havato_Logger::log( sprintf( 'New table published by venue %s for %s %s.', $venue['id'], $date, $time ), 'info' );

		return self::ok( array( 'event_id' => $event_id ) );
	}

	/**
	 * Cancel an event that has no paid guests yet.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_cancel_event( $req ) {
		self::boot( $req );

		global $wpdb;
		$venue = self::owner_venue( get_current_user_id() );
		if ( ! $venue ) {
			return new WP_Error( 'havato_no_venue', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		$event_id = sanitize_text_field( (string) $req->get_param( 'event_id' ) );
		$events   = Havato_DB::table( 'events' );
		$regs     = Havato_DB::table( 'event_registrations' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$owns = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM $events WHERE id=%s AND venue_id=%s", $event_id, $venue['id'] ) );
		if ( ! $owns ) {
			return new WP_Error( 'havato_forbidden', Havato_I18N::t( 'error_generic' ), array( 'status' => 403 ) );
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$booked = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM $regs WHERE event_id=%s AND status<>'cancelled'", $event_id ) );
		if ( $booked > 0 ) {
			return new WP_Error( 'havato_has_guests', Havato_I18N::t( 'error_generic' ), array( 'status' => 409 ) );
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $regs, array( 'event_id' => $event_id ), array( '%s' ) );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $events, array( 'id' => $event_id ), array( '%s' ) );

		return self::ok( array( 'deleted' => true ) );
	}

	/**
	 * Toggle the check-in flag of one guest (section 6.5).
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_checkin( $req ) {
		self::boot( $req );

		global $wpdb;
		$venue = self::owner_venue( get_current_user_id() );
		if ( ! $venue ) {
			return new WP_Error( 'havato_no_venue', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		$event_id = sanitize_text_field( (string) $req->get_param( 'event_id' ) );
		$target   = (int) $req->get_param( 'user_id' );
		$value    = (bool) $req->get_param( 'checked_in' );
		// How many of the party actually walked in. Absent (older callers)
		// means "all of them" when checking in, which preserves the previous
		// all-or-nothing behaviour.
		$arrived  = $req->get_param( 'arrived' );

		$events = Havato_DB::table( 'events' );
		$regs   = Havato_DB::table( 'event_registrations' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$owns = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM $events WHERE id=%s AND venue_id=%s", $event_id, $venue['id'] ) );
		if ( ! $owns ) {
			return new WP_Error( 'havato_forbidden', Havato_I18N::t( 'error_generic' ), array( 'status' => 403 ) );
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$booked = (int) $wpdb->get_var( $wpdb->prepare( "SELECT seats FROM $regs WHERE event_id=%s AND user_id=%d", $event_id, $target ) );
		$booked = max( 1, $booked );

		if ( null === $arrived || '' === $arrived ) {
			$count = $value ? $booked : 0;
		} else {
			$count = max( 0, min( $booked, (int) $arrived ) );
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update(
			$regs,
			array(
				'checked_in' => $count > 0 ? 1 : 0,
				'arrived'    => $count,
			),
			array( 'event_id' => $event_id, 'user_id' => $target ),
			array( '%d', '%d' ),
			array( '%s', '%d' )
		);

		$profiles = Havato_DB::table( 'user_profiles' );
		if ( $value ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$wpdb->query( $wpdb->prepare( "UPDATE $profiles SET attended_count = attended_count + 1 WHERE user_id=%d", $target ) );
		}

		Havato_Logger::log( sprintf( 'Check-in %s for guest %d at event %s.', $value ? 'confirmed' : 'revoked', $target, $event_id ), 'info' );

		return self::ok( array( 'checked_in' => $value ) );
	}

	/**
	 * Save the menu (goes to pending_menu_json until admin approval).
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_save_menu( $req ) {
		self::boot( $req );

		global $wpdb;
		$venue = self::owner_venue( get_current_user_id() );
		if ( ! $venue ) {
			return new WP_Error( 'havato_no_venue', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		$items  = havato_sanitize_menu( $req->get_param( 'items' ) );
		$venues = Havato_DB::table( 'venues' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update(
			$venues,
			array( 'pending_menu_json' => wp_json_encode( $items ) ),
			array( 'id' => $venue['id'] ),
			array( '%s' ),
			array( '%s' )
		);

		Havato_Logger::log( sprintf( 'Menu update submitted for review by venue %s.', $venue['id'] ), 'info' );

		return self::ok(
			array(
				'pending' => $items,
				'message' => Havato_I18N::t( 'menu_saved_pending' ),
			)
		);
	}

	/**
	 * Save the venue profile (auto-save from the settings tab).
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_save_venue( $req ) {
		self::boot( $req );

		global $wpdb;
		$venue = self::owner_venue( get_current_user_id() );
		if ( ! $venue ) {
			return new WP_Error( 'havato_no_venue', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		$fields = array();
		$format = array();

		$map = array(
			'name'         => '%s',
			'manager_name' => '%s',
			'manager_phone' => '%s',
			'country'      => '%s',
			'city'         => '%s',
			'address'     => '%s',
			'image'       => '%s',
			'storefront_photo' => '%s',
			'quiet_hours' => '%s',
			'budget_tier' => '%s',
			'lat'         => '%f',
			'lng'         => '%f',
		);

		foreach ( $map as $key => $fmt ) {
			$value = $req->get_param( $key );
			if ( null === $value ) {
				continue;
			}
			if ( '%f' === $fmt ) {
				$fields[ $key ] = (float) $value;
			} elseif ( 'image' === $key || 'storefront_photo' === $key ) {
				$fields[ $key ] = esc_url_raw( (string) $value );
			} elseif ( 'address' === $key ) {
				$fields[ $key ] = havato_clamp_text( sanitize_textarea_field( (string) $value ), 300 );
			} elseif ( 'manager_name' === $key ) {
				$fields[ $key ] = sanitize_text_field( (string) $value );
			} elseif ( 'manager_phone' === $key ) {
				// Normalised against whichever country the café is saving
				// with, so the stored number is always canonical.
				$c     = sanitize_key( (string) $req->get_param( 'country' ) );
				$c     = havato_valid_country( $c ) ? $c : $venue['country'];
				$phone = havato_normalize_phone( (string) $value, $c );
				if ( '' === $phone && '' !== trim( (string) $value ) ) {
					array_pop( $format );
					continue;
				}
				$fields[ $key ] = $phone;
			} elseif ( 'country' === $key ) {
				$c              = sanitize_key( (string) $value );
				$fields[ $key ] = havato_valid_country( $c ) ? $c : 'ir';
			} elseif ( 'city' === $key ) {
				// Validate against the country in the same request so a café
				// can never end up as Iran/Istanbul. An invalid pair keeps the
				// stored value by being dropped from the update.
				$c    = sanitize_key( (string) $req->get_param( 'country' ) );
				$city = sanitize_key( (string) $value );
				if ( ! havato_valid_city( $c, $city ) ) {
					array_pop( $format );
					continue;
				}
				$fields[ $key ] = $city;
			} elseif ( 'budget_tier' === $key ) {
				$tier           = sanitize_text_field( (string) $value );
				$fields[ $key ] = in_array( $tier, array( 'low', 'medium', 'high' ), true ) ? $tier : 'medium';
			} else {
				$fields[ $key ] = sanitize_text_field( (string) $value );
			}
			$format[] = $fmt;
		}

		if ( empty( $fields ) ) {
			return self::ok( array( 'saved' => false ) );
		}

		$venues = Havato_DB::table( 'venues' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update( $venues, $fields, array( 'id' => $venue['id'] ), $format, array( '%s' ) );

		return self::ok(
			array(
				'saved' => true,
				'venue' => self::venue_payload( self::owner_venue( get_current_user_id() ), true ),
			)
		);
	}

	/**
	 * Media upload from the owner portal (cover / menu item images).
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response|WP_Error
	 */
	public static function owner_upload( $req ) {
		self::boot( $req );
		$url = self::handle_upload( 'file' );
		if ( is_wp_error( $url ) ) {
			return $url;
		}
		return self::ok( array( 'url' => $url ) );
	}

	/* =====================================================================
	 * Admin console
	 * ================================================================== */

	/**
	 * Dashboard statistics.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function admin_stats( $req ) {
		self::boot( $req );
		return self::ok( self::stats_payload() );
	}

	/**
	 * Live console tail.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function admin_log( $req ) {
		self::boot( $req );
		return self::ok( array( 'lines' => Havato_Logger::tail( (int) $req->get_param( 'limit' ) ? (int) $req->get_param( 'limit' ) : 40 ) ) );
	}

	/**
	 * Verify (or un-verify) a venue.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function admin_verify_venue( $req ) {
		self::boot( $req );

		global $wpdb;
		$venue_id = sanitize_text_field( (string) $req->get_param( 'venue_id' ) );
		$value    = null === $req->get_param( 'verified' ) ? 1 : (int) (bool) $req->get_param( 'verified' );

		$venues = Havato_DB::table( 'venues' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update( $venues, array( 'verified' => $value ), array( 'id' => $venue_id ), array( '%d' ), array( '%s' ) );

		self::sync_venue_events( $venue_id, (bool) $value );

		Havato_Logger::log( sprintf( 'Venue %s %s by administrator.', $venue_id, $value ? 'verified' : 'suspended' ), 'success' );

		return self::ok( array( 'verified' => (bool) $value ) );
	}

	/**
	 * Approve or reject a pending menu.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function admin_menu_approve( $req ) {
		self::boot( $req );

		global $wpdb;
		$venue_id = sanitize_text_field( (string) $req->get_param( 'venue_id' ) );
		$approve  = (bool) $req->get_param( 'approve' );

		$venues = Havato_DB::table( 'venues' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$row = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $venues WHERE id=%s", $venue_id ), ARRAY_A );
		if ( ! $row ) {
			return new WP_Error( 'havato_no_venue', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		if ( $approve ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update(
				$venues,
				array( 'menu_json' => $row['pending_menu_json'], 'pending_menu_json' => '' ),
				array( 'id' => $venue_id ),
				array( '%s', '%s' ),
				array( '%s' )
			);
			Havato_Logger::log( sprintf( 'Menu approved and published for venue %s.', $venue_id ), 'success' );
		} else {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $venues, array( 'pending_menu_json' => '' ), array( 'id' => $venue_id ), array( '%s' ), array( '%s' ) );
			Havato_Logger::log( sprintf( 'Pending menu rejected for venue %s.', $venue_id ), 'warn' );
		}

		return self::ok( array( 'approved' => $approve ) );
	}

	/**
	 * Manually run the matcher (admin backup trigger).
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function admin_run_matcher( $req ) {
		self::boot( $req );

		$event_id = sanitize_text_field( (string) $req->get_param( 'event_id' ) );

		if ( $event_id ) {
			$result = Havato_Matcher::run( $event_id, true );
			return self::ok( $result );
		}

		$count = Havato_Cron::force_match_due_events( true );

		return self::ok(
			array(
				'ok'      => true,
				'message' => sprintf( '%d event(s) processed.', $count ),
			)
		);
	}

	/**
	 * Save settings from any admin sub-page.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function admin_save_settings( $req ) {
		self::boot( $req );

		$values = $req->get_param( 'settings' );
		$values = is_array( $values ) ? $values : havato_json( $values );

		$saved = Havato_Settings::update( $values );

		Havato_Logger::log( 'Platform settings updated by administrator.', 'info' );

		return self::ok( array( 'settings' => $saved ) );
	}

	/**
	 * Moderate a reported photo.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function admin_photo_report( $req ) {
		self::boot( $req );

		global $wpdb;
		$report_id = (int) $req->get_param( 'report_id' );
		$action    = sanitize_text_field( (string) $req->get_param( 'action_type' ) );

		$reports = Havato_DB::table( 'photo_reports' );
		$photos  = Havato_DB::table( 'user_photos' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$report = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $reports WHERE id=%d", $report_id ), ARRAY_A );
		if ( ! $report ) {
			return new WP_Error( 'havato_no_report', Havato_I18N::t( 'error_generic' ), array( 'status' => 404 ) );
		}

		if ( 'remove' === $action ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $photos, array( 'status' => 'removed' ), array( 'id' => (int) $report['photo_id'] ), array( '%s' ), array( '%d' ) );
			$status = 'actioned';
		} else {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $photos, array( 'status' => 'approved' ), array( 'id' => (int) $report['photo_id'] ), array( '%s' ), array( '%d' ) );
			$status = 'reviewed';
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update( $reports, array( 'status' => $status ), array( 'id' => $report_id ), array( '%s' ), array( '%d' ) );

		return self::ok( array( 'status' => $status ) );
	}

	/**
	 * Create demo content so a fresh install is never an empty screen.
	 *
	 * @param WP_REST_Request $req Request.
	 * @return WP_REST_Response
	 */
	public static function admin_seed( $req ) {
		self::boot( $req );
		require_once HAVATO_PATH . 'includes/class-havato-seeder.php';
		$result = Havato_Seeder::run();
		return self::ok( $result );
	}

	/* =====================================================================
	 * Shared payload builders
	 * ================================================================== */

	/**
	 * Platform statistics used by the admin dashboard.
	 *
	 * @return array
	 */
	public static function stats_payload() {
		global $wpdb;
		Havato_DB::ensure_tables();

		$venues = Havato_DB::table( 'venues' );
		$events = Havato_DB::table( 'events' );
		$regs   = Havato_DB::table( 'event_registrations' );
		$groups = Havato_DB::table( 'groups' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$active_users = (int) $wpdb->get_var( "SELECT COUNT(DISTINCT user_id) FROM $regs" );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$matched = (int) $wpdb->get_var( "SELECT COUNT(*) FROM $groups" );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$venue_count = (int) $wpdb->get_var( "SELECT COUNT(*) FROM $venues" );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$signups = (int) $wpdb->get_var( "SELECT COALESCE(SUM(seats),0) FROM $regs WHERE status <> 'cancelled'" );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$last_week = (int) $wpdb->get_var( "SELECT COUNT(DISTINCT user_id) FROM $regs WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)" );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$prev_week = (int) $wpdb->get_var( "SELECT COUNT(DISTINCT user_id) FROM $regs WHERE created_at >= DATE_SUB(NOW(), INTERVAL 14 DAY) AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)" );

		$growth = $prev_week > 0 ? round( ( ( $last_week - $prev_week ) / $prev_week ) * 100, 1 ) : ( $last_week > 0 ? 100.0 : 0.0 );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$open_events = (int) $wpdb->get_var( "SELECT COUNT(*) FROM $events WHERE status='open'" );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$pending_venues = (int) $wpdb->get_var( "SELECT COUNT(*) FROM $venues WHERE verified=0" );

		return array(
			'active_users'   => $active_users,
			'matched_tables' => $matched,
			'venues'         => $venue_count,
			'signups'        => $signups,
			'growth'         => $growth,
			'open_events'    => $open_events,
			'pending_venues' => $pending_venues,
			'log'            => Havato_Logger::tail( 12 ),
		);
	}

	/**
	 * Minimal user card used everywhere in the UI.
	 *
	 * @param int $user_id User id.
	 * @return array
	 */
	public static function user_card( $user_id ) {
		$user_id = (int) $user_id;
		$profile = havato_get_profile( $user_id );

		return array(
			'id'     => $user_id,
			'name'   => havato_display_name( $user_id ),
			'avatar' => havato_avatar( $user_id ),
			'role'   => havato_user_role( $user_id ),
			'rating' => round( havato_effective_rating( $profile ), 1 ),
			'age'    => (int) $profile['age'],
		);
	}

	/**
	 * Event payload (bilingual labels precomputed for instant switching).
	 *
	 * @param array $row     Joined event row.
	 * @param int   $user_id Viewer.
	 * @return array
	 */
	private static function event_payload( $row, $user_id ) {
		global $wpdb;

		$taken    = isset( $row['taken'] ) ? (int) $row['taken'] : 0;
		$capacity = (int) $row['max_capacity'];

		$joined = false;
		if ( $user_id ) {
			if ( isset( $row['my_status'] ) ) {
				$joined = ( 'cancelled' !== $row['my_status'] );
			} else {
				$regs = Havato_DB::table( 'event_registrations' );
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
				$joined = (bool) $wpdb->get_var( $wpdb->prepare( "SELECT id FROM $regs WHERE event_id=%s AND user_id=%d AND status<>'cancelled'", $row['id'], $user_id ) );
			}
		}

		return array(
			'id'          => $row['id'],
			'venue_id'    => $row['venue_id'],
			'venue'       => isset( $row['venue_name'] ) ? $row['venue_name'] : '',
			// The event's own photo is optional; fall back to the café's.
			'image'       => ! empty( $row['image'] ) ? $row['image'] : ( isset( $row['venue_image'] ) ? $row['venue_image'] : '' ),
			'theme'       => isset( $row['theme'] ) ? $row['theme'] : '',
			'address'     => isset( $row['venue_address'] ) ? $row['venue_address'] : '',
			'title'       => $row['title'],
			'date'        => havato_date_pair( $row['event_date'] ),
			'weekday'     => array(
				'fa' => Havato_Jalali::week_day( $row['event_date'], 'fa' ),
				'en' => Havato_Jalali::week_day( $row['event_date'], 'en' ),
			),
			'time'        => substr( (string) $row['event_time'], 0, 5 ),
			'budget_tier' => $row['budget_tier'],
			'capacity'    => $capacity,
			'taken'       => $taken,
			'seats_left'  => max( 0, $capacity - $taken ),
			'status'      => $row['status'],
			'joined'      => $joined,
			'lat'         => isset( $row['lat'] ) ? (float) $row['lat'] : 0,
			'lng'         => isset( $row['lng'] ) ? (float) $row['lng'] : 0,
		);
	}

	/**
	 * Venue payload. `$private` also exposes the pending menu (owner only).
	 *
	 * @param array $row     Venue row.
	 * @param bool  $private Include owner-only fields.
	 * @return array
	 */
	private static function venue_payload( $row, $private = false ) {
		if ( ! $row ) {
			return array();
		}

		// Prices follow the café's own country: an Istanbul menu is priced in
		// Lira even when a Persian-speaking guest is reading it.
		$country = isset( $row['country'] ) ? (string) $row['country'] : '';

		$menu = havato_json( $row['menu_json'] );
		foreach ( $menu as $i => $item ) {
			$menu[ $i ]['price_label'] = havato_price_pair( isset( $item['price'] ) ? (int) $item['price'] : 0, $country );
		}

		$payload = array(
			'id'            => $row['id'],
			// A café name is a proper noun: stored and shown once, identical
			// in both languages.
			'name'          => $row['name'],
			'manager_name'  => isset( $row['manager_name'] ) ? $row['manager_name'] : '',
			'country'       => isset( $row['country'] ) ? $row['country'] : '',
			'city'          => isset( $row['city'] ) ? $row['city'] : '',
			'storefront'    => isset( $row['storefront_photo'] ) ? $row['storefront_photo'] : '',
			'city_label'    => havato_city_label( isset( $row['city'] ) ? $row['city'] : '' ),
			'address'       => $row['address'],
			'lat'           => (float) $row['lat'],
			'lng'           => (float) $row['lng'],
			'image'         => $row['image'],
			'utilization'   => (int) $row['utilization'],
			'guests_routed' => (int) $row['guests_routed'],
			'budget_tier'   => $row['budget_tier'],
			'verified'      => (bool) (int) $row['verified'],
			'quiet_hours'   => $row['quiet_hours'],
			'menu'          => $menu,
		);

		if ( $private ) {
			$pending = havato_json( $row['pending_menu_json'] );
			foreach ( $pending as $i => $item ) {
				$pending[ $i ]['price_label'] = havato_price_pair( isset( $item['price'] ) ? (int) $item['price'] : 0, $country );
			}
			$payload['pending_menu'] = $pending;
			$payload['manager_id']   = (int) $row['manager_id'];
			// Owner-only. Guests receive $private = false and therefore never
			// see the café's contact number.
			$payload['manager_phone'] = isset( $row['manager_phone'] ) ? $row['manager_phone'] : '';
		}

		return $payload;
	}

	/**
	 * Keep the events of a venue in sync with its verification state.
	 *
	 * Verifying a café publishes every table it prepared while pending;
	 * suspending it pulls the still-open tables back out of the Explore feed
	 * (already matched or completed tables are never touched).
	 *
	 * @param string $venue_id Venue id.
	 * @param bool   $verified New verification state.
	 */
	public static function sync_venue_events( $venue_id, $verified ) {
		global $wpdb;
		$events = Havato_DB::table( 'events' );

		if ( $verified ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$changed = (int) $wpdb->query( $wpdb->prepare( "UPDATE $events SET status='open' WHERE venue_id=%s AND status='pending_admin'", $venue_id ) );
			if ( $changed > 0 ) {
				Havato_Logger::log( sprintf( '%d pending table(s) published for venue %s.', $changed, $venue_id ), 'success' );
			}
			return;
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$changed = (int) $wpdb->query( $wpdb->prepare( "UPDATE $events SET status='pending_admin' WHERE venue_id=%s AND status='open'", $venue_id ) );
		if ( $changed > 0 ) {
			Havato_Logger::log( sprintf( '%d open table(s) unpublished for venue %s.', $changed, $venue_id ), 'warn' );
		}
	}

	/**
	 * The venue managed by a user.
	 *
	 * @param int $user_id User id.
	 * @return array|null
	 */
	public static function owner_venue( $user_id ) {
		global $wpdb;
		Havato_DB::ensure_tables();
		$venues = Havato_DB::table( 'venues' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$row = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $venues WHERE manager_id=%d ORDER BY created_at ASC LIMIT 1", (int) $user_id ), ARRAY_A );
		return $row ? $row : null;
	}

	/**
	 * Accepted friends as chat threads.
	 *
	 * @param int $user_id User id.
	 * @return array
	 */
	private static function friend_threads( $user_id ) {
		global $wpdb;
		$friends = Havato_DB::table( 'friends' );
		$pc      = Havato_DB::table( 'private_chats' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT * FROM $friends WHERE status='accepted' AND (user_id=%d OR friend_id=%d)",
				$user_id,
				$user_id
			),
			ARRAY_A
		);

		$out = array();
		foreach ( (array) $rows as $row ) {
			$other = ( (int) $row['user_id'] === (int) $user_id ) ? (int) $row['friend_id'] : (int) $row['user_id'];

			// Blocked users disappear completely.
			if ( havato_is_blocked( $user_id, $other ) ) {
				continue;
			}

			$thread = Havato_DB::thread_id( $user_id, $other );

			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$last = $wpdb->get_row( $wpdb->prepare( "SELECT message_text, message_time FROM $pc WHERE thread_id=%s ORDER BY id DESC LIMIT 1", $thread ), ARRAY_A );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$unread = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM $pc WHERE thread_id=%s AND receiver_id=%d AND is_read=0", $thread, $user_id ) );

			$out[] = array(
				'user'         => self::user_card( $other ),
				'last_message' => $last ? wp_trim_words( $last['message_text'], 8, '…' ) : '',
				'last_time'    => $last ? substr( (string) $last['message_time'], 11, 5 ) : '',
				'unread'       => $unread,
			);
		}

		return $out;
	}

	/**
	 * Members of a group with the viewer's friendship state.
	 *
	 * @param string $group_id Group id.
	 * @param int    $viewer   Viewer id.
	 * @return array
	 */
	private static function group_members( $group_id, $viewer ) {
		global $wpdb;
		$gm = Havato_DB::table( 'group_members' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$ids = $wpdb->get_col( $wpdb->prepare( "SELECT user_id FROM $gm WHERE group_id=%s", $group_id ) );

		$out = array();
		foreach ( (array) $ids as $uid ) {
			$uid  = (int) $uid;
			$card = self::user_card( $uid );

			$card['friend_status'] = ( $uid === (int) $viewer ) ? 'self' : havato_friend_status( $viewer, $uid );
			$card['blocked']       = ( $uid !== (int) $viewer ) && havato_is_blocked( $viewer, $uid );

			$out[] = $card;
		}

		return $out;
	}

	/**
	 * Photos of a user, respecting privacy & moderation state.
	 *
	 * @param int  $target  Owner.
	 * @param int  $viewer  Viewer.
	 * @param bool $is_self Viewing your own gallery.
	 * @return array
	 */
	private static function user_photos( $target, $viewer, $is_self ) {
		global $wpdb;

		// HARD CONSTRAINT (section 4.5): the gallery of another member only
		// unlocks once the friendship is `accepted`. Blocked pairs and mere
		// table-mates never see each other's photos.
		if ( ! $is_self && ! havato_are_friends( $viewer, $target ) ) {
			return array();
		}

		$photos = Havato_DB::table( 'user_photos' );
		$likes  = Havato_DB::table( 'photo_likes' );

		$where = $is_self ? "user_id=%d AND status <> 'removed'" : "user_id=%d AND status IN ('approved','reported')";

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results( $wpdb->prepare( "SELECT * FROM $photos WHERE $where ORDER BY id DESC LIMIT 60", (int) $target ), ARRAY_A );

		$out = array();
		foreach ( (array) $rows as $row ) {
			$pid = (int) $row['id'];
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$count = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM $likes WHERE photo_id=%d", $pid ) );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$liked = (bool) $wpdb->get_var( $wpdb->prepare( "SELECT id FROM $likes WHERE photo_id=%d AND user_id=%d", $pid, (int) $viewer ) );

			$out[] = array(
				'id'     => $pid,
				'url'    => $row['photo_url'],
				'status' => $row['status'],
				'likes'  => $count,
				'liked'  => $liked,
				'mine'   => $is_self,
				'date'   => havato_date_pair( $row['created_at'] ),
			);
		}

		return $out;
	}

	/**
	 * Pending feedback cards (completed events without a submitted review).
	 *
	 * @param int $user_id User id.
	 * @return array
	 */
	public static function collect_pending_feedback( $user_id ) {
		global $wpdb;
		Havato_DB::ensure_tables();

		$groups    = Havato_DB::table( 'groups' );
		$gm        = Havato_DB::table( 'group_members' );
		$events    = Havato_DB::table( 'events' );
		$venues    = Havato_DB::table( 'venues' );
		$feedbacks = Havato_DB::table( 'feedbacks' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT g.id, g.event_id, e.event_date, v.name AS venue_name
				 FROM $gm m
				 INNER JOIN $groups g ON g.id = m.group_id
				 INNER JOIN $events e ON e.id = g.event_id
				 LEFT JOIN $venues v ON v.id = e.venue_id
				 WHERE m.user_id = %d AND e.status = 'completed'
				 ORDER BY e.event_date DESC LIMIT 10",
				$user_id
			),
			ARRAY_A
		);

		$out = array();

		foreach ( (array) $rows as $row ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$mates = $wpdb->get_col( $wpdb->prepare( "SELECT user_id FROM $gm WHERE group_id=%s AND user_id<>%d", $row['id'], $user_id ) );

			$pending = array();
			foreach ( (array) $mates as $mate ) {
				$mate = (int) $mate;
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
				$done = (int) $wpdb->get_var( $wpdb->prepare( "SELECT id FROM $feedbacks WHERE group_id=%s AND reporter_id=%d AND reported_id=%d", $row['id'], $user_id, $mate ) );
				if ( $done ) {
					continue;
				}
				$card                  = self::user_card( $mate );
				$card['friend_status'] = havato_friend_status( $user_id, $mate );
				$card['blocked']       = havato_is_blocked( $user_id, $mate );
				$pending[]             = $card;
			}

			if ( empty( $pending ) ) {
				continue;
			}

			$out[] = array(
				'group_id' => $row['id'],
				'event_id' => $row['event_id'],
				'venue'    => $row['venue_name'],
				'date'     => havato_date_pair( $row['event_date'] ),
				'mates'    => $pending,
			);
		}

		return $out;
	}

	/* =====================================================================
	 * Internal helpers
	 * ================================================================== */

	/**
	 * Insert a user into an event queue.
	 *
	 * @param string $event_id Event id.
	 * @param int    $user_id  User id.
	 * @param string $status   Registration status, normally 'queued'.
	 * @param int    $seats    Party size (the booker plus their companions).
	 */
	private static function queue_user( $event_id, $user_id, $status = 'queued', $seats = 1 ) {
		global $wpdb;
		$regs = Havato_DB::table( 'event_registrations' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->replace(
			$regs,
			array(
				'event_id'   => $event_id,
				'user_id'    => (int) $user_id,
				'status'     => $status,
				'checked_in' => 0,
				'seats'      => max( 1, min( havato_max_seats(), (int) $seats ) ),
				'created_at' => havato_now(),
			),
			array( '%s', '%d', '%s', '%d', '%d', '%s' )
		);
	}

	/**
	 * May a viewer see (and therefore like / report) another member's gallery?
	 *
	 * Section 4.5: photos unlock only for `accepted` friends, and a block in
	 * either direction closes everything again.
	 *
	 * @param int $viewer Viewer id.
	 * @param int $owner  Gallery owner id.
	 * @return bool
	 */
	private static function can_view_gallery( $viewer, $owner ) {
		$viewer = (int) $viewer;
		$owner  = (int) $owner;

		if ( $viewer === $owner ) {
			return true;
		}
		if ( havato_is_blocked( $viewer, $owner ) ) {
			return false;
		}
		return havato_are_friends( $viewer, $owner );
	}

	/**
	 * Is a user a member of a group?
	 *
	 * @param string $group_id Group.
	 * @param int    $user_id  User.
	 * @return bool
	 */
	private static function is_group_member( $group_id, $user_id ) {
		global $wpdb;
		$gm = Havato_DB::table( 'group_members' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		return (bool) $wpdb->get_var( $wpdb->prepare( "SELECT id FROM $gm WHERE group_id=%s AND user_id=%d", $group_id, (int) $user_id ) );
	}

	/**
	 * Mark a friendship as accepted (both directions normalized to one row).
	 *
	 * @param int $requester Requester id.
	 * @param int $target    Target id.
	 * @return WP_REST_Response
	 */
	private static function friend_accept_pair( $requester, $target ) {
		global $wpdb;
		$table = Havato_DB::table( 'friends' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->replace(
			$table,
			array(
				'user_id'    => (int) $requester,
				'friend_id'  => (int) $target,
				'status'     => 'accepted',
				'created_at' => havato_now(),
			),
			array( '%d', '%d', '%s', '%s' )
		);

		// Remove any mirrored pending row so the pair has a single truth.
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $table, array( 'user_id' => (int) $target, 'friend_id' => (int) $requester ), array( '%d', '%d' ) );

		return self::ok( array( 'status' => 'accepted' ) );
	}

	/**
	 * Recompute a user's average behaviour score from their feedbacks.
	 *
	 * @param int $user_id User id.
	 */
	private static function recalculate_rating( $user_id ) {
		global $wpdb;
		$feedbacks = Havato_DB::table( 'feedbacks' );
		$profiles  = Havato_DB::table( 'user_profiles' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$row = $wpdb->get_row( $wpdb->prepare( "SELECT AVG(rating) AS avg_rating, COUNT(*) AS c FROM $feedbacks WHERE reported_id=%d", (int) $user_id ), ARRAY_A );

		$avg   = $row && $row['avg_rating'] ? (float) $row['avg_rating'] : 5.0;
		$count = $row ? (int) $row['c'] : 0;

		// Make sure the profile row exists before updating.
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$exists = $wpdb->get_var( $wpdb->prepare( "SELECT user_id FROM $profiles WHERE user_id=%d", (int) $user_id ) );

		if ( $exists ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update(
				$profiles,
				array( 'rating_score' => $avg, 'rating_count' => $count ),
				array( 'user_id' => (int) $user_id ),
				array( '%f', '%d' ),
				array( '%d' )
			);
		} else {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->insert(
				$profiles,
				array(
					'user_id'      => (int) $user_id,
					'rating_score' => $avg,
					'rating_count' => $count,
					'updated_at'   => havato_now(),
				),
				array( '%d', '%f', '%d', '%s' )
			);
		}
	}

	/**
	 * Append a user to another user's blocklist.
	 *
	 * @param int $owner  Blocklist owner.
	 * @param int $target Blocked user.
	 */
	private static function add_to_blocklist( $owner, $target ) {
		global $wpdb;
		$profiles = Havato_DB::table( 'user_profiles' );

		$profile = havato_get_profile( $owner );
		$list    = $profile['blocklist'];

		if ( ! in_array( (int) $target, $list, true ) ) {
			$list[] = (int) $target;
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$exists = $wpdb->get_var( $wpdb->prepare( "SELECT user_id FROM $profiles WHERE user_id=%d", (int) $owner ) );

		if ( $exists ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $profiles, array( 'blocklist_json' => wp_json_encode( $list ) ), array( 'user_id' => (int) $owner ), array( '%s' ), array( '%d' ) );
		} else {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->insert(
				$profiles,
				array(
					'user_id'        => (int) $owner,
					'blocklist_json' => wp_json_encode( $list ),
					'updated_at'     => havato_now(),
				),
				array( '%d', '%s', '%s' )
			);
		}

		// A block also tears down the friendship, in both directions.
		$friends = Havato_DB::table( 'friends' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $friends, array( 'user_id' => (int) $owner, 'friend_id' => (int) $target ), array( '%d', '%d' ) );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $friends, array( 'user_id' => (int) $target, 'friend_id' => (int) $owner ), array( '%d', '%d' ) );
	}

	/**
	 * Handle a media upload through the WordPress media library.
	 *
	 * @param string $field $_FILES key.
	 * @return string|WP_Error URL.
	 */
	private static function handle_upload( $field ) {
		if ( empty( $_FILES[ $field ] ) ) {
			return new WP_Error( 'havato_no_file', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}

		require_once ABSPATH . 'wp-admin/includes/file.php';
		require_once ABSPATH . 'wp-admin/includes/image.php';
		require_once ABSPATH . 'wp-admin/includes/media.php';

		// phpcs:ignore WordPress.Security.ValidatedSanitizedInput
		$file = $_FILES[ $field ];

		$allowed = array( 'jpg', 'jpeg', 'png', 'gif', 'webp' );
		$check   = wp_check_filetype( isset( $file['name'] ) ? $file['name'] : '' );
		if ( ! $check['ext'] || ! in_array( strtolower( $check['ext'] ), $allowed, true ) ) {
			return new WP_Error( 'havato_bad_file', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}

		$attachment_id = media_handle_upload( $field, 0 );
		if ( is_wp_error( $attachment_id ) ) {
			return $attachment_id;
		}

		$url = wp_get_attachment_url( $attachment_id );
		return $url ? $url : new WP_Error( 'havato_upload_failed', Havato_I18N::t( 'error_generic' ), array( 'status' => 500 ) );
	}

	/**
	 * Uniform success envelope.
	 *
	 * @param array $data Payload.
	 * @return WP_REST_Response
	 */
	private static function ok( $data ) {
		return new WP_REST_Response( array_merge( array( 'success' => true ), $data ), 200 );
	}
}
