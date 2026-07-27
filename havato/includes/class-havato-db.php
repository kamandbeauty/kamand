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
			'payouts',
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
			KEY city (city)
		) $charset;";

		// 2. Events.
		$queries[] = "CREATE TABLE {$p}events (
			id varchar(64) NOT NULL,
			venue_id varchar(64) NOT NULL DEFAULT '',
			title varchar(191) NOT NULL DEFAULT '',
			event_date date NOT NULL DEFAULT '0000-00-00',
			event_time time NOT NULL DEFAULT '00:00:00',
			budget_tier varchar(20) NOT NULL DEFAULT 'medium',
			price int(11) NOT NULL DEFAULT 0,
			max_capacity int(11) NOT NULL DEFAULT 6,
			status varchar(24) NOT NULL DEFAULT 'open',
			created_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			KEY venue_id (venue_id),
			KEY status (status),
			KEY event_date (event_date)
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
		// `status`: queued | matched | cancelled, plus `pending_payment` — a
		// short-lived seat hold placed while the guest is at the WooCommerce
		// gateway so concurrent checkouts can never oversell a table.
		$queries[] = "CREATE TABLE {$p}event_registrations (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			event_id varchar(64) NOT NULL DEFAULT '',
			user_id bigint(20) unsigned NOT NULL DEFAULT 0,
			status varchar(20) NOT NULL DEFAULT 'queued',
			checked_in tinyint(1) NOT NULL DEFAULT 0,
			order_id bigint(20) unsigned NOT NULL DEFAULT 0,
			amount int(11) NOT NULL DEFAULT 0,
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

		// 14. Venue payout periods (section 5.5 settlement ledger).
		$queries[] = "CREATE TABLE {$p}payouts (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			venue_id varchar(64) NOT NULL DEFAULT '',
			period varchar(20) NOT NULL DEFAULT '',
			gross_amount bigint(20) NOT NULL DEFAULT 0,
			commission_amount bigint(20) NOT NULL DEFAULT 0,
			venue_amount bigint(20) NOT NULL DEFAULT 0,
			status varchar(20) NOT NULL DEFAULT 'due',
			paid_at datetime NULL,
			note varchar(255) NOT NULL DEFAULT '',
			updated_at datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
			PRIMARY KEY  (id),
			UNIQUE KEY venue_period (venue_id,period),
			KEY status (status)
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
