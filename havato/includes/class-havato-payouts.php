<?php
/**
 * Venue payout ledger (section 5.5).
 *
 * Every ticket is charged on the platform's WooCommerce account, so the café's
 * share has to be tracked explicitly. This class aggregates ticket revenue per
 * venue per month, applies the configured commission and stores a "due / paid"
 * settlement row that both the owner portal and wp-admin can read.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Settlement calculator.
 */
class Havato_Payouts {

	/**
	 * Recalculate the ledger for one venue (all periods with sales).
	 *
	 * @param string $venue_id  Venue id.
	 * @param bool   $for_admin Include platform-only revenue figures.
	 * @return array Rows.
	 */
	public static function rebuild_venue( $venue_id, $for_admin = false ) {
		global $wpdb;
		Havato_DB::ensure_tables();

		$regs     = Havato_DB::table( 'event_registrations' );
		$events   = Havato_DB::table( 'events' );
		$payouts  = Havato_DB::table( 'payouts' );
		$percent  = max( 0, min( 100, (int) Havato_Settings::get( 'commission_percent', 20 ) ) );

		// Group paid registrations by calendar month of the event date.
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT DATE_FORMAT(e.event_date, '%%Y-%%m') AS period, SUM(r.amount) AS gross
				 FROM $regs r
				 INNER JOIN $events e ON e.id = r.event_id
				 WHERE e.venue_id = %s AND r.amount > 0
				   AND r.status NOT IN ('cancelled','pending_payment')
				 GROUP BY period",
				$venue_id
			),
			ARRAY_A
		);

		foreach ( (array) $rows as $row ) {
			$gross      = (int) $row['gross'];
			$commission = (int) round( $gross * $percent / 100 );
			$share      = $gross - $commission;

			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$existing = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $payouts WHERE venue_id=%s AND period=%s", $venue_id, $row['period'] ), ARRAY_A );

			if ( $existing ) {
				// Never overwrite a period that has already been paid out.
				if ( 'paid' === $existing['status'] ) {
					continue;
				}
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->update(
					$payouts,
					array(
						'gross_amount'      => $gross,
						'commission_amount' => $commission,
						'venue_amount'      => $share,
						'updated_at'        => havato_now(),
					),
					array( 'id' => (int) $existing['id'] ),
					array( '%d', '%d', '%d', '%s' ),
					array( '%d' )
				);
			} else {
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->insert(
					$payouts,
					array(
						'venue_id'          => $venue_id,
						'period'            => $row['period'],
						'gross_amount'      => $gross,
						'commission_amount' => $commission,
						'venue_amount'      => $share,
						'status'            => 'due',
						'updated_at'        => havato_now(),
					),
					array( '%s', '%s', '%d', '%d', '%d', '%s', '%s' )
				);
			}
		}

		return self::get_venue_payouts( $venue_id, $for_admin );
	}

	/**
	 * Rebuild every venue (cron).
	 */
	public static function rebuild_all() {
		global $wpdb;
		Havato_DB::ensure_tables();
		$venues = Havato_DB::table( 'venues' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$ids = $wpdb->get_col( "SELECT id FROM $venues" );
		foreach ( (array) $ids as $id ) {
			self::rebuild_venue( $id );
		}
	}

	/**
	 * Ledger rows for one venue, newest period first.
	 *
	 * @param string $venue_id Venue id.
	 * @param bool   $for_admin Include platform-only figures (gross revenue and
	 *                          the commission cut). Café owners must never see
	 *                          these — they only get their own share.
	 * @return array
	 */
	public static function get_venue_payouts( $venue_id, $for_admin = false ) {
		global $wpdb;
		$payouts = Havato_DB::table( 'payouts' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results( $wpdb->prepare( "SELECT * FROM $payouts WHERE venue_id=%s ORDER BY period DESC", $venue_id ), ARRAY_A );

		$rows = array_map( array( __CLASS__, 'format_row' ), (array) $rows );

		if ( $for_admin ) {
			return $rows;
		}

		// Strip every platform-revenue field before it reaches the owner app.
		return array_map(
			function ( $row ) {
				unset(
					$row['gross_amount'],
					$row['commission_amount'],
					$row['gross_label'],
					$row['commission_label']
				);
				return $row;
			},
			$rows
		);
	}

	/**
	 * All ledger rows (admin view).
	 *
	 * @param string $status Filter: '', 'due', 'paid'.
	 * @return array
	 */
	public static function all( $status = '' ) {
		global $wpdb;
		Havato_DB::ensure_tables();
		$payouts = Havato_DB::table( 'payouts' );
		$venues  = Havato_DB::table( 'venues' );

		if ( $status ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$rows = $wpdb->get_results( $wpdb->prepare( "SELECT p.*, v.name, v.name_fa FROM $payouts p LEFT JOIN $venues v ON v.id=p.venue_id WHERE p.status=%s ORDER BY p.period DESC", $status ), ARRAY_A );
		} else {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$rows = $wpdb->get_results( "SELECT p.*, v.name, v.name_fa FROM $payouts p LEFT JOIN $venues v ON v.id=p.venue_id ORDER BY p.period DESC", ARRAY_A );
		}

		return array_map( array( __CLASS__, 'format_row' ), (array) $rows );
	}

	/**
	 * Mark one settlement period as paid (admin action).
	 *
	 * @param int    $payout_id Row id.
	 * @param string $note      Optional note (e.g. transfer reference).
	 * @return bool
	 */
	public static function mark_paid( $payout_id, $note = '' ) {
		global $wpdb;
		$payouts = Havato_DB::table( 'payouts' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$ok = $wpdb->update(
			$payouts,
			array(
				'status'     => 'paid',
				'paid_at'    => havato_now(),
				'note'       => sanitize_text_field( $note ),
				'updated_at' => havato_now(),
			),
			array( 'id' => (int) $payout_id ),
			array( '%s', '%s', '%s', '%s' ),
			array( '%d' )
		);

		if ( false !== $ok ) {
			Havato_Logger::log( sprintf( 'Payout #%d marked as settled by administrator.', (int) $payout_id ), 'success' );
			return true;
		}

		return false;
	}

	/**
	 * Add display helpers to a ledger row.
	 *
	 * @param array $row Raw row.
	 * @return array
	 */
	private static function format_row( $row ) {
		$row['gross_amount']      = (int) $row['gross_amount'];
		$row['commission_amount'] = (int) $row['commission_amount'];
		$row['venue_amount']      = (int) $row['venue_amount'];
		$row['gross_label']       = havato_price_pair( $row['gross_amount'] );
		$row['commission_label']  = havato_price_pair( $row['commission_amount'] );
		$row['share_label']       = havato_price_pair( $row['venue_amount'] );
		$row['period_label']      = self::period_label( $row['period'] );
		return $row;
	}

	/**
	 * Localized label for a YYYY-MM period.
	 *
	 * @param string $period Period.
	 * @return array{fa:string,en:string}
	 */
	private static function period_label( $period ) {
		$parts = explode( '-', (string) $period );
		if ( 2 !== count( $parts ) ) {
			return array( 'fa' => (string) $period, 'en' => (string) $period );
		}

		$date = $period . '-01';
		list( $jy, $jm ) = Havato_Jalali::to_jalali( (int) $parts[0], (int) $parts[1], 1 );

		return array(
			'fa' => Havato_Jalali::$months_fa[ $jm ] . ' ' . Havato_Jalali::fa_digits( $jy ),
			'en' => gmdate( 'F Y', strtotime( $date ) ),
		);
	}
}
