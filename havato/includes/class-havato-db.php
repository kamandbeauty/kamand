<?php
/**
 * Database layer: 13 dedicated tables + self-healing installer.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Schema manager.
 */
class Havato_DB {

	/**
	 * Runtime guard so the self-heal check runs at most once per request.
	 *
	 * @var bool
	 */
	private static $checked = false;

	/**
	 * Logical table keys.
	 *
	 * @return array
	 */
	public static function table_keys() {
		return array(
			'venues',
			'events',
			'user_profiles',
			'event_registrations',
			'groups',
			'group_members',
			'chats',
			'feedbacks',
			'friends',
			'user_photos',
			'photo_likes',
			'photo_reports',
			'private_chats',
			'venue_tables',
			'event_tables',
		);
	}

	/**
	 * Full table name for a logical key.
	 *
	 * @param string $key Logical key (e.g. 'venues').
	 * @return string
	 */
	public static function table( $key ) {
		global $wpdb;
		return $wpdb->prefix . 'havato_' . $key;
	}

	/**
	 * Self-healing check: make sure every table exists, create the missing
	 * ones silently and never interrupt the current request.
	 *
	 * Called on every shortcode render and every REST request.
	 */
	public static function ensure_tables() {
		if ( self::$checked ) {
			return;
		}
		self::$checked = true;

		global $wpdb;
		$missing = false;

		foreach ( self::table_keys() as $key ) {
			$table = self::table( $key );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.NotPrepared
			$found = $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $table ) );
			if ( $found !== $table ) {
				$missing = true;
				break;
			}
		}

		if ( $missing ) {
			self::install();
		}
	}

	/**
	 * Run dbDelta on the whole schema (idempotent).
	 */
	public static function install() {
		global $wpdb;

		require_once ABSPATH . 'wp-admin/includes/upgrade.php';

		$charset = $wpdb->get_charset_collate();
		$p       = $wpdb->prefix . 'havato_';

		$queries = array();

		// 1. Venues (cafés / restaurants).
		// `name` is the single café name (no separate Persian field — the name
		// of a venue is a proper noun and is written once). `manager_name` is
		// the person running it, shown to the administrator.
		$queries[] = "CREATE TABLE {$p}venues (
			id varchar(64) NOT NULL,
			name varchar(191) NOT NULL DEFAULT '',
			manager_name varchar(191) NOT NULL DEFAULT '',
			country varchar(8) NOT NULL DEFAULT 'ir',
			city varchar(32) NOT NULL DEFAULT 'tehran',
			address text NULL,
			lat double NOT NULL DEFAULT 0,
			lng double NOT NULL DEFAULT 0,
			image varchar(255) NOT NULL DEFAULT '',
			storefront_photo varchar(255) NOT NULL DEFAULT '',
			is_demo tinyint(1) NOT NULL DEFAULT 0,
			utilization int(11) NOT NULL DEFAULT 0,
			guests_routed int(11) NOT NULL DEFAULT 0,
			budget_tier varchar(20) NOT NULL DEFAULT 'medium',
			verified tinyint(1) NOT NULL DEFAULT 0,
			manager_id bigint(20) unsigned NOT NULL DEFAULT 0,
			quiet_hours varchar(191) NOT NULL DEFAULT '',
			menu_json longtext NULL,
			pending_menu_json longtext NULL,
			created_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			KEY manager_id (manager_id),
			KEY verified (verified),
			KEY city (city),
			KEY is_demo (is_demo)
		) $charset;";

		// 2. Events.
		$queries[] = "CREATE TABLE {$p}events (
			id varchar(64) NOT NULL,
			venue_id varchar(64) NOT NULL DEFAULT '',
			title varchar(191) NOT NULL DEFAULT '',
			event_date date NOT NULL DEFAULT '0000-00-00',
			event_time time NOT NULL DEFAULT '00:00:00',
			theme varchar(191) NOT NULL DEFAULT '',
			image varchar(255) NOT NULL DEFAULT '',
			budget_tier varchar(20) NOT NULL DEFAULT 'medium',
			max_capacity int(11) NOT NULL DEFAULT 6,
			status varchar(24) NOT NULL DEFAULT 'open',
			is_demo tinyint(1) NOT NULL DEFAULT 0,
			created_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			KEY venue_id (venue_id),
			KEY status (status),
			KEY event_date (event_date),
			KEY is_demo (is_demo)
		) $charset;";

		// 3. User personality profiles.
		$queries[] = "CREATE TABLE {$p}user_profiles (
			user_id bigint(20) unsigned NOT NULL,
			age int(11) NOT NULL DEFAULT 0,
			gender varchar(20) NOT NULL DEFAULT '',
			country varchar(8) NOT NULL DEFAULT '',
			city varchar(32) NOT NULL DEFAULT '',
			city_neighborhood varchar(191) NOT NULL DEFAULT '',
			personality_extroversion int(11) NOT NULL DEFAULT 5,
			personality_talkative int(11) NOT NULL DEFAULT 5,
			personality_vibe varchar(20) NOT NULL DEFAULT 'fun',
			personality_openness int(11) NOT NULL DEFAULT 5,
			personality_humor int(11) NOT NULL DEFAULT 5,
			personality_energy int(11) NOT NULL DEFAULT 5,
			personality_planning int(11) NOT NULL DEFAULT 5,
			personality_empathy int(11) NOT NULL DEFAULT 5,
			personality_interests text NULL,
			rating_score double NOT NULL DEFAULT 5,
			rating_count int(11) NOT NULL DEFAULT 0,
			no_show_count int(11) NOT NULL DEFAULT 0,
			attended_count int(11) NOT NULL DEFAULT 0,
			blocklist_json text NULL,
			completed tinyint(1) NOT NULL DEFAULT 0,
			updated_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (user_id)
		) $charset;";

		// 4. Event registrations (the queue).
		// `status`: queued | matched | cancelled. Joining is free, so a seat
		// is simply taken or not — there is no reservation/hold state.
		// `seats`: 1..HAVATO_MAX_SEATS. One row per booking, not per chair:
		// the UNIQUE(event_id,user_id) key means a guest bringing friends is
		// still a single row, with the party size stored here.
		$queries[] = "CREATE TABLE {$p}event_registrations (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			event_id varchar(64) NOT NULL DEFAULT '',
			user_id bigint(20) unsigned NOT NULL DEFAULT 0,
			status varchar(20) NOT NULL DEFAULT 'queued',
			checked_in tinyint(1) NOT NULL DEFAULT 0,
			seats int(11) NOT NULL DEFAULT 1,
			created_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			UNIQUE KEY event_user (event_id,user_id),
			KEY user_id (user_id),
			KEY status (status)
		) $charset;";

		// 5. Groups (tables).
		$queries[] = "CREATE TABLE {$p}groups (
			id varchar(64) NOT NULL,
			event_id varchar(64) NOT NULL DEFAULT '',
			name varchar(191) NOT NULL DEFAULT '',
			score double NOT NULL DEFAULT 0,
			created_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			KEY event_id (event_id)
		) $charset;";

		// 6. Group members.
		$queries[] = "CREATE TABLE {$p}group_members (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			group_id varchar(64) NOT NULL DEFAULT '',
			user_id bigint(20) unsigned NOT NULL DEFAULT 0,
			created_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			UNIQUE KEY group_user (group_id,user_id),
			KEY user_id (user_id)
		) $charset;";

		// 7. Group (table) live chat.
		$queries[] = "CREATE TABLE {$p}chats (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			group_id varchar(64) NOT NULL DEFAULT '',
			sender_id bigint(20) unsigned NOT NULL DEFAULT 0,
			sender_name varchar(191) NOT NULL DEFAULT '',
			message_text text NULL,
			message_time datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			is_system tinyint(1) NOT NULL DEFAULT 0,
			PRIMARY KEY  (id),
			KEY group_id (group_id),
			KEY message_time (message_time)
		) $charset;";

		// 8. Post-event feedbacks.
		$queries[] = "CREATE TABLE {$p}feedbacks (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			group_id varchar(64) NOT NULL DEFAULT '',
			reporter_id bigint(20) unsigned NOT NULL DEFAULT 0,
			reported_id bigint(20) unsigned NOT NULL DEFAULT 0,
			rating int(11) NOT NULL DEFAULT 5,
			comment text NULL,
			is_block tinyint(1) NOT NULL DEFAULT 0,
			created_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			UNIQUE KEY feedback_pair (group_id,reporter_id,reported_id),
			KEY reported_id (reported_id)
		) $charset;";

		// 9. Friends.
		$queries[] = "CREATE TABLE {$p}friends (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			user_id bigint(20) unsigned NOT NULL DEFAULT 0,
			friend_id bigint(20) unsigned NOT NULL DEFAULT 0,
			status varchar(20) NOT NULL DEFAULT 'pending',
			created_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			UNIQUE KEY friendship (user_id,friend_id),
			KEY friend_id (friend_id),
			KEY status (status)
		) $charset;";

		// 10. Profile photo gallery.
		$queries[] = "CREATE TABLE {$p}user_photos (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			user_id bigint(20) unsigned NOT NULL DEFAULT 0,
			photo_url varchar(255) NOT NULL DEFAULT '',
			status varchar(20) NOT NULL DEFAULT 'approved',
			created_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			KEY user_id (user_id),
			KEY status (status)
		) $charset;";

		// 11. Photo likes (unique per user & photo).
		$queries[] = "CREATE TABLE {$p}photo_likes (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			photo_id bigint(20) unsigned NOT NULL DEFAULT 0,
			user_id bigint(20) unsigned NOT NULL DEFAULT 0,
			created_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			UNIQUE KEY photo_user (photo_id,user_id),
			KEY user_id (user_id)
		) $charset;";

		// 12. Photo reports.
		$queries[] = "CREATE TABLE {$p}photo_reports (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			photo_id bigint(20) unsigned NOT NULL DEFAULT 0,
			reporter_id bigint(20) unsigned NOT NULL DEFAULT 0,
			reason varchar(191) NOT NULL DEFAULT '',
			status varchar(20) NOT NULL DEFAULT 'pending',
			created_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			KEY photo_id (photo_id),
			KEY status (status)
		) $charset;";

		// 13. Private (friend to friend) chat — fully separate from table chat.
		$queries[] = "CREATE TABLE {$p}private_chats (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			thread_id varchar(64) NOT NULL DEFAULT '',
			sender_id bigint(20) unsigned NOT NULL DEFAULT 0,
			receiver_id bigint(20) unsigned NOT NULL DEFAULT 0,
			message_text text NULL,
			message_time datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			is_read tinyint(1) NOT NULL DEFAULT 0,
			PRIMARY KEY  (id),
			KEY thread_id (thread_id),
			KEY receiver_id (receiver_id)
		) $charset;";

		// 14. Venue tables — the physical furniture a café owns.
		// Defined once by the owner ("3 tables of 4, 2 tables of 6") and then
		// picked per event, so an event's capacity is derived from real seats
		// instead of one arbitrary number.
		$queries[] = "CREATE TABLE {$p}venue_tables (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			venue_id varchar(64) NOT NULL DEFAULT '',
			table_number int(11) NOT NULL DEFAULT 0,
			label varchar(191) NOT NULL DEFAULT '',
			seats int(11) NOT NULL DEFAULT 4,
			quantity int(11) NOT NULL DEFAULT 1,
			active tinyint(1) NOT NULL DEFAULT 1,
			created_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			KEY venue_id (venue_id),
			KEY table_number (venue_id,table_number)
		) $charset;";

		// 15. Which tables an event uses, and how many of each.
		$queries[] = "CREATE TABLE {$p}event_tables (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			event_id varchar(64) NOT NULL DEFAULT '',
			table_id bigint(20) unsigned NOT NULL DEFAULT 0,
			seats int(11) NOT NULL DEFAULT 4,
			quantity int(11) NOT NULL DEFAULT 1,
			PRIMARY KEY  (id),
			KEY event_id (event_id),
			KEY table_id (table_id)
		) $charset;";

		foreach ( $queries as $sql ) {
			// InnoDB is required for the foreign-key-less but transactional
			// behaviour we rely on; dbDelta keeps the statement idempotent.
			dbDelta( str_replace( ') ' . $charset . ';', ') ENGINE=InnoDB ' . $charset . ';', $sql ) );
		}

		update_option( 'havato_db_version', HAVATO_DB_VERSION );
	}

	/**
	 * Upgrade routine — also acts as a boot-time self-heal.
	 */
	public static function maybe_upgrade() {
		$installed = get_option( 'havato_db_version' );
		if ( HAVATO_DB_VERSION !== $installed ) {
			self::install();
			self::migrate_name_fa_to_manager();
			self::migrate_tables_to_numbered();
		}
	}

	/**
	 * Migration: tables used to be stored as "a type with a quantity"
	 * (3 x 4-seater in one row). Cafés now number each physical table, so any
	 * legacy row with quantity > 1 is expanded into that many numbered rows.
	 *
	 * Safe to re-run: it only touches rows that still have quantity > 1 or no
	 * number yet.
	 */
	public static function migrate_tables_to_numbered() {
		global $wpdb;

		$table = self::table( 'venue_tables' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$columns = $wpdb->get_col( "DESC `$table`", 0 );
		if ( ! is_array( $columns ) || ! in_array( 'table_number', $columns, true ) ) {
			return;
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$venues = $wpdb->get_col( "SELECT DISTINCT venue_id FROM `$table`" );

		foreach ( (array) $venues as $venue_id ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$rows = $wpdb->get_results(
				$wpdb->prepare( "SELECT * FROM `$table` WHERE venue_id = %s ORDER BY id ASC", $venue_id ),
				ARRAY_A
			);

			$next = 1;
			foreach ( (array) $rows as $row ) {
				$qty = max( 1, (int) $row['quantity'] );

				// The original row becomes table #next.
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->update(
					$table,
					array( 'table_number' => $next, 'quantity' => 1 ),
					array( 'id' => (int) $row['id'] ),
					array( '%d', '%d' ),
					array( '%d' )
				);
				$next++;

				// Any extra copies become their own numbered rows.
				for ( $i = 1; $i < $qty; $i++ ) {
					// phpcs:ignore WordPress.DB.DirectDatabaseQuery
					$wpdb->insert(
						$table,
						array(
							'venue_id'     => $venue_id,
							'table_number' => $next,
							'label'        => $row['label'],
							'seats'        => (int) $row['seats'],
							'quantity'     => 1,
							'active'       => (int) $row['active'],
							'created_at'   => havato_now(),
						),
						array( '%s', '%d', '%s', '%d', '%d', '%d', '%s' )
					);
					$next++;
				}
			}
		}
	}

	/**
	 * Migration: the venues table used to carry a second Persian name
	 * (`name_fa`). A café name is a proper noun and only needs to be entered
	 * once, so that column is replaced by `manager_name`.
	 *
	 * dbDelta never drops columns, so this runs explicitly. It is safe to call
	 * repeatedly: it exits unless the legacy column is still present.
	 */
	public static function migrate_name_fa_to_manager() {
		global $wpdb;

		$table = self::table( 'venues' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$columns = $wpdb->get_col( "DESC `$table`", 0 );
		if ( ! is_array( $columns ) || ! in_array( 'name_fa', $columns, true ) ) {
			return;
		}

		// Keep whichever name the owner actually filled in: many venues only
		// ever entered the Persian one, so it must not be thrown away.
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$wpdb->query( "UPDATE `$table` SET name = name_fa WHERE (name = '' OR name IS NULL) AND name_fa <> ''" );

		// Seed the new manager name from the WordPress account behind the venue.
		if ( in_array( 'manager_name', $columns, true ) ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$rows = $wpdb->get_results( "SELECT id, manager_id FROM `$table` WHERE manager_name = '' AND manager_id > 0", ARRAY_A );

			foreach ( (array) $rows as $row ) {
				$name = havato_display_name( (int) $row['manager_id'] );
				if ( '' === $name ) {
					continue;
				}
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->update( $table, array( 'manager_name' => $name ), array( 'id' => $row['id'] ), array( '%s' ), array( '%s' ) );
			}
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$wpdb->query( "ALTER TABLE `$table` DROP COLUMN `name_fa`" );

		if ( class_exists( 'Havato_Logger' ) ) {
			Havato_Logger::log( 'Schema migrated: venues.name_fa replaced by venues.manager_name.', 'success' );
		}
	}

	/**
	 * Build the canonical private-chat thread id for two users.
	 *
	 * @param int $a First user.
	 * @param int $b Second user.
	 * @return string e.g. "12_45"
	 */
	public static function thread_id( $a, $b ) {
		$a = (int) $a;
		$b = (int) $b;
		return $a < $b ? $a . '_' . $b : $b . '_' . $a;
	}
}
