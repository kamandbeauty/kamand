<?php
/**
 * Demo content generator (admin-triggered, never automatic).
 *
 * Creates a few verified cafés with menus and a week of open events so that a
 * brand new install shows a working product instead of empty screens.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Seeder.
 */
class Havato_Seeder {

	/**
	 * Run the seeder (idempotent-ish: skips when venues already exist).
	 *
	 * @return array{ok:bool,message:string}
	 */
	public static function run() {
		global $wpdb;
		Havato_DB::ensure_tables();

		$venues_t = Havato_DB::table( 'venues' );
		$events_t = Havato_DB::table( 'events' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$count = (int) $wpdb->get_var( "SELECT COUNT(*) FROM $venues_t" );
		if ( $count > 0 ) {
			return array( 'ok' => false, 'message' => 'Demo content skipped — venues already exist.' );
		}

		$samples = array(
			array(
				'fa'      => 'کافه لمیز',
				'manager' => 'سارا محمدی',
				'city'    => 'tehran',
				'en'    => 'Lamiz Coffee',
				'addr'  => 'تهران، خیابان ولیعصر، نرسیده به پارک ساعی',
				'lat'   => 35.7448,
				'lng'   => 51.4092,
				'tier'  => 'medium',
				'quiet' => '10:00 - 16:00',
				'menu'  => array(
					array( 'name' => 'اسپرسو دوبل', 'price' => 65000, 'desc' => 'قهوه ترکیبی عربیکا', 'image' => '' ),
					array( 'name' => 'لته وانیلی', 'price' => 92000, 'desc' => '', 'image' => '' ),
					array( 'name' => 'چیزکیک نیویورکی', 'price' => 148000, 'desc' => 'سرو با سس تمشک', 'image' => '' ),
				),
			),
			array(
				'fa'      => 'کافه واوموشن',
				'manager' => 'امیر رضایی',
				'city'    => 'tehran',
				'en'    => 'Wawmotion Café',
				'addr'  => 'تهران، سعادت‌آباد، بلوار دریا',
				'lat'   => 35.7796,
				'lng'   => 51.3705,
				'tier'  => 'high',
				'quiet' => '11:00 - 15:00',
				'menu'  => array(
					array( 'name' => 'فلت وایت', 'price' => 110000, 'desc' => '', 'image' => '' ),
					array( 'name' => 'ماچا لاته', 'price' => 135000, 'desc' => 'ماچای درجه یک ژاپنی', 'image' => '' ),
				),
			),
			array(
				'fa'      => 'کافه‌کتاب مانا',
				'manager' => 'نگار حسینی',
				'city'    => 'isfahan',
				'en'    => 'Mana Book Café',
				'addr'  => 'تهران، انقلاب، خیابان ۱۲ فروردین',
				'lat'   => 35.7008,
				'lng'   => 51.3944,
				'tier'  => 'low',
				'quiet' => '09:00 - 13:00',
				'menu'  => array(
					array( 'name' => 'دمنوش به و دارچین', 'price' => 55000, 'desc' => '', 'image' => '' ),
					array( 'name' => 'کیک خانگی روز', 'price' => 78000, 'desc' => '', 'image' => '' ),
				),
			),
		);

		$created_events = 0;

		foreach ( $samples as $index => $sample ) {
			$venue_id = havato_uid( 'v' );

			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->insert(
				$venues_t,
				array(
					'id'           => $venue_id,
					'name'         => $sample['fa'],
					'manager_name' => $sample['manager'],
					'country'      => 'ir',
					'city'         => $sample['city'],
					'address'      => $sample['addr'],
					'lat'          => $sample['lat'],
					'lng'          => $sample['lng'],
					'image'        => '',
					'budget_tier'  => $sample['tier'],
					'verified'     => 1,
					'manager_id'   => 0,
					'quiet_hours'  => $sample['quiet'],
					'menu_json'    => wp_json_encode( havato_sanitize_menu( $sample['menu'] ) ),
					'created_at'   => havato_now(),
				),
				array( '%s', '%s', '%s', '%s', '%s', '%s', '%f', '%f', '%s', '%s', '%d', '%d', '%s', '%s', '%s' )
			);

			$prices = array( 'low' => 45000, 'medium' => 75000, 'high' => 120000 );

			for ( $d = 1; $d <= 3; $d++ ) {
				$date = gmdate( 'Y-m-d', strtotime( '+' . ( $d + $index ) . ' days', current_time( 'timestamp' ) ) );
				$time = array( '18:00:00', '19:30:00', '20:30:00' )[ $d % 3 ];

				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->insert(
					$events_t,
					array(
						'id'           => havato_uid( 'e' ),
						'venue_id'     => $venue_id,
						'title'        => '',
						'event_date'   => $date,
						'event_time'   => $time,
						'budget_tier'  => $sample['tier'],
						'price'        => $prices[ $sample['tier'] ],
						'max_capacity' => 4 + ( $d % 3 ) * 2,
						'status'       => 'open',
						'created_at'   => havato_now(),
					),
					array( '%s', '%s', '%s', '%s', '%s', '%s', '%d', '%d', '%s', '%s' )
				);

				$created_events++;
			}
		}

		Havato_Logger::log( sprintf( 'Demo content generated: %d venues, %d events.', count( $samples ), $created_events ), 'success' );

		return array(
			'ok'      => true,
			'message' => sprintf( 'Demo content created: %d venues and %d events.', count( $samples ), $created_events ),
		);
	}
}
