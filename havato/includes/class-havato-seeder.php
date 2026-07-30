<?php
/**
 * Demo content generator (admin-triggered, never automatic).
 *
 * Everything created here is flagged `is_demo = 1`, so the whole set can be
 * removed again with one button without touching a single real café. Real
 * venues created through the owner portal or the bulk importer are never
 * flagged and are therefore never deleted by the cleanup.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Seeder.
 */
class Havato_Seeder {

	/**
	 * The demo café directory: Tehran, Isfahan and Istanbul.
	 *
	 * @return array
	 */
	public static function catalogue() {
		return array(

			/* ---------------------------------------------------- Tehran */
			array( 'name' => 'کافه طهرون', 'city' => 'tehran', 'lat' => 35.70057, 'lng' => 51.41239, 'address' => 'تهران' ),
			array( 'name' => 'کافه دیاموند', 'city' => 'tehran', 'lat' => 35.71779, 'lng' => 51.40986, 'address' => 'تهران' ),
			array( 'name' => 'کافه پارادیزو', 'city' => 'tehran', 'lat' => 35.72458, 'lng' => 51.43144, 'address' => 'تهران' ),
			array( 'name' => 'چای بار', 'city' => 'tehran', 'lat' => 35.79442, 'lng' => 51.46066, 'address' => 'تهران' ),
			array( 'name' => 'کافه مکس', 'city' => 'tehran', 'lat' => 35.76340, 'lng' => 51.47490, 'address' => 'تهران' ),
			array( 'name' => 'کافه نایت لند', 'city' => 'tehran', 'lat' => 35.69931, 'lng' => 51.41888, 'address' => 'تهران' ),
			array( 'name' => 'کافه پارت', 'city' => 'tehran', 'lat' => 35.70784, 'lng' => 51.39216, 'address' => 'تهران' ),
			array( 'name' => 'کافه ناتور', 'city' => 'tehran', 'lat' => 35.71383, 'lng' => 51.40157, 'address' => 'تهران' ),
			array( 'name' => 'کافه رد', 'city' => 'tehran', 'lat' => 35.75766, 'lng' => 51.37353, 'address' => 'تهران' ),
			array( 'name' => 'کافه چای', 'city' => 'tehran', 'lat' => 35.77541, 'lng' => 51.43225, 'address' => 'تهران' ),

			/* --------------------------------------------------- Isfahan */
			array( 'name' => 'کافه عمو حسن', 'city' => 'isfahan', 'lat' => 32.66031, 'lng' => 51.67757, 'address' => 'اصفهان' ),
			array( 'name' => 'کافه مسو قالی', 'city' => 'isfahan', 'lat' => 32.65889, 'lng' => 51.67546, 'address' => 'اصفهان' ),
			array( 'name' => 'کافه دالون', 'city' => 'isfahan', 'lat' => 32.63478, 'lng' => 51.65529, 'address' => 'اصفهان' ),
			array( 'name' => 'کافه لوتوس', 'city' => 'isfahan', 'lat' => 32.63375, 'lng' => 51.68584, 'address' => 'اصفهان' ),
			array( 'name' => 'کافه سفر', 'city' => 'isfahan', 'lat' => 32.64056, 'lng' => 51.66898, 'address' => 'اصفهان' ),
			array( 'name' => 'کافه ناروان', 'city' => 'isfahan', 'lat' => 32.66018, 'lng' => 51.67663, 'address' => 'اصفهان' ),
			array( 'name' => 'کافه لفته', 'city' => 'isfahan', 'lat' => 32.66020, 'lng' => 51.67630, 'address' => 'اصفهان' ),
			array( 'name' => 'کافه بالکن سفید', 'city' => 'isfahan', 'lat' => 32.66012, 'lng' => 51.67705, 'address' => 'اصفهان' ),
			array( 'name' => 'پیس کافه', 'city' => 'isfahan', 'lat' => 32.66008, 'lng' => 51.67672, 'address' => 'اصفهان' ),
			array( 'name' => 'بلو استار کافه', 'city' => 'isfahan', 'lat' => 32.63634, 'lng' => 51.65989, 'address' => 'اصفهان' ),

			/* -------------------------------------------------- Istanbul */
			array( 'name' => 'Petra Roasting Co. Gayrettepe', 'city' => 'istanbul', 'lat' => 41.0679, 'lng' => 29.0067, 'address' => 'Gayrettepe, Istanbul' ),
			array( 'name' => 'Karabatak', 'city' => 'istanbul', 'lat' => 41.0258, 'lng' => 28.9768, 'address' => 'Karaköy, Istanbul' ),
			array( 'name' => 'Mandabatmaz', 'city' => 'istanbul', 'lat' => 41.0338, 'lng' => 28.9773, 'address' => 'Beyoğlu, Istanbul' ),
			array( 'name' => "Walter's Coffee Roastery", 'city' => 'istanbul', 'lat' => 40.9908, 'lng' => 29.0304, 'address' => 'Moda, Kadıköy, Istanbul' ),
			array( 'name' => 'Kronotrop', 'city' => 'istanbul', 'lat' => 41.0332, 'lng' => 28.9779, 'address' => 'Beyoğlu, Istanbul' ),
			array( 'name' => 'Journey', 'city' => 'istanbul', 'lat' => 41.0311, 'lng' => 28.9828, 'address' => 'Cihangir, Istanbul' ),
			array( 'name' => 'MOC Istanbul', 'city' => 'istanbul', 'lat' => 41.0828, 'lng' => 29.0126, 'address' => 'Nişantaşı, Istanbul' ),
			array( 'name' => "Fazıl Bey'in Türk Kahvesi", 'city' => 'istanbul', 'lat' => 40.9899, 'lng' => 29.0262, 'address' => 'Kadıköy, Istanbul' ),
			array( 'name' => 'Pierre Loti Cafe', 'city' => 'istanbul', 'lat' => 41.0534, 'lng' => 28.9339, 'address' => 'Eyüpsultan, Istanbul' ),
			array( 'name' => 'Cafe Privato', 'city' => 'istanbul', 'lat' => 41.0250, 'lng' => 28.9736, 'address' => 'Galata, Istanbul' ),
		);
	}

	/**
	 * Sample menus, rotated across the demo cafés — keyed by country.
	 *
	 * Prices are stored as plain numbers and rendered in the café's own
	 * currency, so a Turkish café must carry Lira-sized figures. Rotating one
	 * shared list would have priced an Istanbul filter coffee at 95,000 Lira.
	 *
	 * @param string $country Country key ('ir', 'tr').
	 * @return array
	 */
	private static function sample_menus( $country = 'ir' ) {
		$menus = array(
			// Toman, for Iranian cafés.
			'ir' => array(
				array(
					array( 'name' => 'اسپرسو دوبل', 'price' => 65000, 'desc' => 'قهوه ترکیبی عربیکا', 'image' => '' ),
					array( 'name' => 'لته وانیلی', 'price' => 92000, 'desc' => '', 'image' => '' ),
					array( 'name' => 'چیزکیک نیویورکی', 'price' => 148000, 'desc' => 'سرو با سس تمشک', 'image' => '' ),
				),
				array(
					array( 'name' => 'فلت وایت', 'price' => 110000, 'desc' => '', 'image' => '' ),
					array( 'name' => 'ماچا لاته', 'price' => 135000, 'desc' => 'ماچای درجه یک ژاپنی', 'image' => '' ),
				),
				array(
					array( 'name' => 'قهوه ترک', 'price' => 70000, 'desc' => 'سرو با لوکوم', 'image' => '' ),
					array( 'name' => 'قهوه دمی', 'price' => 95000, 'desc' => 'تک‌خاستگاه', 'image' => '' ),
					array( 'name' => 'چیزکیک', 'price' => 150000, 'desc' => '', 'image' => '' ),
				),
			),
			// Lira, for Turkish cafés.
			'tr' => array(
				array(
					array( 'name' => 'Türk Kahvesi', 'price' => 70, 'desc' => 'Lokum ile servis edilir', 'image' => '' ),
					array( 'name' => 'Filtre Kahve', 'price' => 95, 'desc' => 'Tek çeşit çekirdek', 'image' => '' ),
					array( 'name' => 'Cheesecake', 'price' => 150, 'desc' => '', 'image' => '' ),
				),
				array(
					array( 'name' => 'Flat White', 'price' => 110, 'desc' => '', 'image' => '' ),
					array( 'name' => 'Matcha Latte', 'price' => 135, 'desc' => 'Japon matcha', 'image' => '' ),
				),
				array(
					array( 'name' => 'Double Espresso', 'price' => 65, 'desc' => 'Arabica harmanı', 'image' => '' ),
					array( 'name' => 'Sahlep', 'price' => 90, 'desc' => 'Tarçınlı', 'image' => '' ),
					array( 'name' => 'Baklava', 'price' => 120, 'desc' => 'Antep fıstıklı', 'image' => '' ),
				),
			),
		);

		return isset( $menus[ $country ] ) ? $menus[ $country ] : $menus['ir'];
	}

	/**
	 * Create the demo directory.
	 *
	 * Every row is flagged `is_demo = 1` so it can be removed later. Cafés that
	 * already exist (same name + city) are skipped, so running this twice does
	 * not duplicate anything.
	 *
	 * @return array{ok:bool,message:string}
	 */
	public static function run() {
		global $wpdb;
		Havato_DB::ensure_tables();

		$venues_t = Havato_DB::table( 'venues' );
		$events_t = Havato_DB::table( 'events' );
		$tables_t = Havato_DB::table( 'venue_tables' );
		$et_t     = Havato_DB::table( 'event_tables' );

		$tiers   = array( 'low', 'medium', 'high' );
		$themes  = array( 'موسیقی', 'کتاب', 'استارتاپ', 'Board games', 'Film' );

		// Paired with $themes by index, so a "کتاب" evening gets the book
		// subject rather than a random one.
		$subjects = array(
			array(
				'title' => 'شب موسیقی و گفتگو',
				'desc'  => 'یک عصر آرام برای حرف زدن درباره موسیقی؛ هرکس یک آهنگ می‌آورد و درباره‌اش می‌گوید. لازم نیست چیزی بلد باشید، فقط گوش دادن هم کافی است.',
			),
			array(
				'title' => 'باشگاه کتاب',
				'desc'  => 'درباره کتابی که این ماه خوانده‌اید حرف بزنید و پیشنهاد تازه بگیرید. اگر کتابی نخوانده‌اید هم بیایید؛ فهرست خواندنی‌تان پر می‌شود.',
			),
			array(
				'title' => 'میز استارتاپ',
				'desc'  => 'دورهمی آدم‌هایی که روی ایده یا کسب‌وکاری کار می‌کنند. جای پیچ دادن نیست؛ جای پرسیدن سؤال‌های سختی است که خودتان از خودتان نمی‌پرسید.',
			),
			array(
				'title' => 'شب بازی‌های رومیزی',
				'desc'  => 'بازی‌ها روی میز هست و قاعده‌ها را سر جا یاد می‌گیرید. بهترین راه برای آشنا شدن وقتی حرف زدن با غریبه سخت است.',
			),
			array(
				'title' => 'قرار فیلم‌بازها',
				'desc'  => 'یک فیلم را بهانه می‌کنیم برای گفتگو. طرفدار سینمای هنری باشید یا فیلم‌های پرفروش، هر دو سر این میز جا دارند.',
			),
		);

		$created_venues = 0;
		$created_events = 0;
		$skipped        = 0;

		foreach ( self::catalogue() as $index => $sample ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$exists = $wpdb->get_var(
				$wpdb->prepare( "SELECT id FROM $venues_t WHERE name = %s AND city = %s LIMIT 1", $sample['name'], $sample['city'] )
			);
			if ( $exists ) {
				$skipped++;
				continue;
			}

			$venue_id = havato_uid( 'v' );
			$tier     = $tiers[ $index % 3 ];
			$country  = ( 'istanbul' === $sample['city'] ) ? 'tr' : 'ir';

			// Menu prices are meaningless without a currency, and the currency
			// comes from the café's country — so pick the matching price list.
			$menus = self::sample_menus( $country );

			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->insert(
				$venues_t,
				array(
					'id'           => $venue_id,
					'name'         => $sample['name'],
					'manager_name' => '',
					'country'      => $country,
					'city'         => $sample['city'],
					'address'      => $sample['address'],
					'lat'          => $sample['lat'],
					'lng'          => $sample['lng'],
					'image'        => '',
					'budget_tier'  => $tier,
					'verified'     => 1,
					'manager_id'   => 0,
					'quiet_hours'  => '10:00 - 16:00',
					'menu_json'    => wp_json_encode( havato_sanitize_menu( $menus[ $index % count( $menus ) ] ) ),
					'is_demo'      => 1,
					'created_at'   => havato_now(),
				),
				array( '%s', '%s', '%s', '%s', '%s', '%s', '%f', '%f', '%s', '%s', '%d', '%d', '%s', '%s', '%d', '%s' )
			);

			$created_venues++;

			// Give each demo café a little furniture: two 4-seaters and a 6.
			$table_ids = array();
			foreach ( array( 1 => 4, 2 => 4, 3 => 6 ) as $number => $seats ) {
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->insert(
					$tables_t,
					array(
						'venue_id'     => $venue_id,
						'table_number' => $number,
						'label'        => '',
						'seats'        => $seats,
						'quantity'     => 1,
						'active'       => 1,
						'created_at'   => havato_now(),
					),
					array( '%s', '%d', '%s', '%d', '%d', '%d', '%s' )
				);
				$table_ids[ (int) $wpdb->insert_id ] = $seats;
			}

			// Two upcoming events per café.
			for ( $d = 1; $d <= 2; $d++ ) {
				$event_id = havato_uid( 'e' );
				$date     = gmdate( 'Y-m-d', strtotime( '+' . ( $d + ( $index % 5 ) ) . ' days', current_time( 'timestamp' ) ) );
				$time     = ( 0 === $d % 2 ) ? '19:30:00' : '18:00:00';

				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->insert(
					$events_t,
					array(
						'id'           => $event_id,
						'venue_id'     => $venue_id,
						// Demo events used to carry an empty title, so the card
						// showed only the theme and every evening at a café
						// looked identical. Give each one a real subject.
						'title'        => $subjects[ ( $index + $d ) % count( $subjects ) ]['title'],
						'theme'        => $themes[ ( $index + $d ) % count( $themes ) ],
						'description'  => $subjects[ ( $index + $d ) % count( $subjects ) ]['desc'],
						'image'        => '',
						'event_date'   => $date,
						'event_time'   => $time,
						'budget_tier'  => $tier,
						'max_capacity' => 14,
						'status'       => 'open',
						'is_demo'      => 1,
						'created_at'   => havato_now(),
					),
					// 13 columns, 13 formats — see the note in owner_create_event().
					array( '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%d', '%s', '%d', '%s' )
				);

				// Attach the café's tables to the event.
				foreach ( $table_ids as $tid => $seats ) {
					// phpcs:ignore WordPress.DB.DirectDatabaseQuery
					$wpdb->insert(
						$et_t,
						array(
							'event_id' => $event_id,
							'table_id' => $tid,
							'seats'    => $seats,
							'quantity' => 1,
						),
						array( '%s', '%d', '%d', '%d' )
					);
				}

				$created_events++;
			}
		}

		Havato_Logger::log(
			sprintf( 'Demo content generated: %d venues, %d events (%d skipped).', $created_venues, $created_events, $skipped ),
			'success'
		);

		return array(
			'ok'      => true,
			'message' => sprintf(
				Havato_I18N::t( 'demo_created' ),
				$created_venues,
				$created_events,
				$skipped
			),
		);
	}

	/**
	 * How much demo content currently exists.
	 *
	 * @return array{venues:int,events:int}
	 */
	public static function stats() {
		global $wpdb;
		Havato_DB::ensure_tables();

		$venues_t = Havato_DB::table( 'venues' );
		$events_t = Havato_DB::table( 'events' );

		return array(
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			'venues' => (int) $wpdb->get_var( "SELECT COUNT(*) FROM $venues_t WHERE is_demo = 1" ),
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			'events' => (int) $wpdb->get_var( "SELECT COUNT(*) FROM $events_t WHERE is_demo = 1" ),
		);
	}

	/**
	 * Remove every trace of the demo content.
	 *
	 * Only rows flagged `is_demo = 1` are touched, so a real café that a real
	 * owner registered — even in the same city — is left completely alone.
	 * Related rows (tables, registrations, groups, chats) are cleaned up too,
	 * otherwise the database would keep orphans pointing at deleted events.
	 *
	 * @return array{ok:bool,message:string}
	 */
	public static function purge() {
		global $wpdb;
		Havato_DB::ensure_tables();

		$venues_t = Havato_DB::table( 'venues' );
		$events_t = Havato_DB::table( 'events' );
		$tables_t = Havato_DB::table( 'venue_tables' );
		$et_t     = Havato_DB::table( 'event_tables' );
		$regs_t   = Havato_DB::table( 'event_registrations' );
		$groups_t = Havato_DB::table( 'groups' );
		$gm_t     = Havato_DB::table( 'group_members' );
		$chats_t  = Havato_DB::table( 'chats' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$venue_ids = $wpdb->get_col( "SELECT id FROM $venues_t WHERE is_demo = 1" );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$event_ids = $wpdb->get_col( "SELECT id FROM $events_t WHERE is_demo = 1" );

		if ( empty( $venue_ids ) && empty( $event_ids ) ) {
			return array( 'ok' => false, 'message' => Havato_I18N::t( 'demo_none' ) );
		}

		$venues_removed = count( $venue_ids );
		$events_removed = count( $event_ids );

		if ( ! empty( $event_ids ) ) {
			$ph = implode( ',', array_fill( 0, count( $event_ids ), '%s' ) );

			// Groups belonging to those events, so their members and chat go too.
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$group_ids = $wpdb->get_col(
				$wpdb->prepare( "SELECT id FROM $groups_t WHERE event_id IN ($ph)", $event_ids )
			);

			if ( ! empty( $group_ids ) ) {
				$gph = implode( ',', array_fill( 0, count( $group_ids ), '%s' ) );
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
				$wpdb->query( $wpdb->prepare( "DELETE FROM $gm_t WHERE group_id IN ($gph)", $group_ids ) );
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
				$wpdb->query( $wpdb->prepare( "DELETE FROM $chats_t WHERE group_id IN ($gph)", $group_ids ) );
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
				$wpdb->query( $wpdb->prepare( "DELETE FROM $groups_t WHERE id IN ($gph)", $group_ids ) );
			}

			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$wpdb->query( $wpdb->prepare( "DELETE FROM $regs_t WHERE event_id IN ($ph)", $event_ids ) );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$wpdb->query( $wpdb->prepare( "DELETE FROM $et_t WHERE event_id IN ($ph)", $event_ids ) );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$wpdb->query( $wpdb->prepare( "DELETE FROM $events_t WHERE id IN ($ph)", $event_ids ) );
		}

		if ( ! empty( $venue_ids ) ) {
			$vph = implode( ',', array_fill( 0, count( $venue_ids ), '%s' ) );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$wpdb->query( $wpdb->prepare( "DELETE FROM $tables_t WHERE venue_id IN ($vph)", $venue_ids ) );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$wpdb->query( $wpdb->prepare( "DELETE FROM $venues_t WHERE id IN ($vph)", $venue_ids ) );
		}

		Havato_Logger::log(
			sprintf( 'Demo content removed: %d venues, %d events.', $venues_removed, $events_removed ),
			'warn'
		);

		return array(
			'ok'      => true,
			'message' => sprintf( Havato_I18N::t( 'demo_removed' ), $venues_removed, $events_removed ),
		);
	}
}
