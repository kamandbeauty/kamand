<?php
/**
 * Scheduled jobs.
 *
 * 1. havato_matcher_cron   — every 15 min: FALLBACK matching path (section 7)
 *                            forces the algorithm on events that start within
 *                            `cron_lead_hours` and are still unmatched.
 * 2. havato_lifecycle_cron — every 15 min: closes finished events (status
 *                            `completed`), which unlocks the post-event
 *                            feedback (section 7.5) and penalises no-shows.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Cron manager.
 */
class Havato_Cron {

	/**
	 * Register schedules and handlers.
	 */
	public static function init() {
		add_filter( 'cron_schedules', array( __CLASS__, 'add_schedule' ) );
		add_action( 'havato_matcher_cron', array( __CLASS__, 'run_matcher_cron' ) );
		add_action( 'havato_lifecycle_cron', array( __CLASS__, 'run_lifecycle_cron' ) );
		add_action( 'init', array( __CLASS__, 'schedule_events' ), 20 );
	}

	/**
	 * Add the 15-minute interval.
	 *
	 * @param array $schedules Existing schedules.
	 * @return array
	 */
	public static function add_schedule( $schedules ) {
		if ( ! isset( $schedules['havato_15min'] ) ) {
			$schedules['havato_15min'] = array(
				'interval' => 15 * MINUTE_IN_SECONDS,
				'display'  => 'Havato — every 15 minutes',
			);
		}
		return $schedules;
	}

	/**
	 * Make sure both jobs exist.
	 */
	public static function schedule_events() {
		if ( ! wp_next_scheduled( 'havato_matcher_cron' ) ) {
			wp_schedule_event( time() + 60, 'havato_15min', 'havato_matcher_cron' );
		}
		if ( ! wp_next_scheduled( 'havato_lifecycle_cron' ) ) {
			wp_schedule_event( time() + 120, 'havato_15min', 'havato_lifecycle_cron' );
		}
	}

	/**
	 * Remove the jobs on deactivation.
	 */
	public static function clear_events() {
		wp_clear_scheduled_hook( 'havato_matcher_cron' );
		wp_clear_scheduled_hook( 'havato_lifecycle_cron' );
	}

	/**
	 * FALLBACK matcher path.
	 */
	public static function run_matcher_cron() {
		self::force_match_due_events( false );
	}

	/**
	 * Force the matcher on every event that starts inside the lead window and
	 * is still `open`, no matter how few guests registered.
	 *
	 * @param bool $ignore_window Run on every open event (admin manual trigger).
	 * @return int Number of events processed.
	 */
	public static function force_match_due_events( $ignore_window = false ) {
		global $wpdb;
		Havato_DB::ensure_tables();

		$events = Havato_DB::table( 'events' );
		$lead   = max( 1, (int) Havato_Settings::get( 'cron_lead_hours', 2 ) );

		if ( $ignore_window ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$ids = $wpdb->get_col( "SELECT id FROM $events WHERE status='open'" );
		} else {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$ids = $wpdb->get_col(
				$wpdb->prepare(
					"SELECT id FROM $events
					 WHERE status='open'
					   AND TIMESTAMP(event_date, event_time) <= DATE_ADD(NOW(), INTERVAL %d HOUR)
					   AND TIMESTAMP(event_date, event_time) >= DATE_SUB(NOW(), INTERVAL 12 HOUR)",
					$lead
				)
			);
		}

		if ( empty( $ids ) ) {
			return 0;
		}

		Havato_Logger::log( sprintf( 'Fallback cron armed: %d event(s) inside the %dh lead window.', count( $ids ), $lead ), 'info' );

		$count = 0;
		foreach ( $ids as $id ) {
			// Relaxed = true: this is exactly the low-registration scenario.
			$result = Havato_Matcher::run( $id, true );
			if ( ! empty( $result['ok'] ) ) {
				$count++;
			}
		}

		return $count;
	}

	/**
	 * Close events whose time has passed and apply no-show penalties.
	 */
	public static function run_lifecycle_cron() {
		global $wpdb;
		Havato_DB::ensure_tables();

		$events   = Havato_DB::table( 'events' );
		$regs     = Havato_DB::table( 'event_registrations' );
		$profiles = Havato_DB::table( 'user_profiles' );
		$hours    = max( 1, (int) Havato_Settings::get( 'auto_complete_hours', 3 ) );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$ids = $wpdb->get_col(
			$wpdb->prepare(
				"SELECT id FROM $events
				 WHERE status IN ('open','matched')
				   AND TIMESTAMP(event_date, event_time) <= DATE_SUB(NOW(), INTERVAL %d HOUR)",
				$hours
			)
		);

		foreach ( (array) $ids as $id ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $events, array( 'status' => 'completed' ), array( 'id' => $id ), array( '%s' ), array( '%s' ) );

			// --- Reliability penalties -----------------------------------
			// Two distinct failures are charged here:
			//   1. the booker never turned up at all;
			//   2. they turned up but left seats they reserved for others
			//      empty — each empty chair is charged separately, because
			//      it is a chair somebody else could have used.
			$per_no_show    = (float) Havato_Settings::get( 'penalty_no_show', 1 );
			$per_empty_seat = (float) Havato_Settings::get( 'penalty_empty_seat', 1 );

			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$rows = $wpdb->get_results(
				$wpdb->prepare( "SELECT user_id, seats, arrived, checked_in FROM $regs WHERE event_id=%s AND status='matched'", $id ),
				ARRAY_A
			);

			$no_shows = 0;
			$empty    = 0;

			foreach ( (array) $rows as $row ) {
				$uid   = (int) $row['user_id'];
				$booked = max( 1, (int) $row['seats'] );

				// `arrived` is authoritative once the café has used the new
				// counter. Older rows only carry the checked_in flag, so fall
				// back to "all of them" / "none of them".
				if ( (int) $row['arrived'] > 0 ) {
					$arrived = min( $booked, (int) $row['arrived'] );
				} else {
					$arrived = (int) $row['checked_in'] ? $booked : 0;
				}

				$missing = max( 0, $booked - $arrived );
				if ( 0 === $missing ) {
					continue;
				}

				if ( 0 === $arrived ) {
					// Nobody came. The booker owns the no-show, plus every
					// extra chair they were holding.
					$points = $per_no_show + ( ( $missing - 1 ) * $per_empty_seat );
					$no_shows++;
					$empty += ( $missing - 1 );

					// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
					$wpdb->query( $wpdb->prepare( "UPDATE $profiles SET no_show_count = no_show_count + 1 WHERE user_id=%d", $uid ) );
				} else {
					// They came, but brought fewer people than they booked.
					$points = $missing * $per_empty_seat;
					$empty += $missing;
				}

				// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
				$wpdb->query(
					$wpdb->prepare(
						"UPDATE $profiles SET penalty_points = penalty_points + %f, empty_seat_count = empty_seat_count + %d WHERE user_id=%d",
						$points,
						$missing - ( 0 === $arrived ? 1 : 0 ),
						$uid
					)
				);
			}

			Havato_Logger::log(
				sprintf(
					'Event %s closed — feedback round opened (%d no-show, %d empty seat(s) charged).',
					$id,
					$no_shows,
					$empty
				),
				'info'
			);
		}
	}
}
