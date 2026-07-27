<?php
/**
 * Shared helper functions.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Current MySQL datetime in site timezone.
 *
 * @return string
 */
function havato_now() {
	return current_time( 'mysql' );
}

/**
 * Generate a short unique id for varchar primary keys.
 *
 * @param string $prefix Prefix, e.g. 'v', 'e', 'g'.
 * @return string
 */
function havato_uid( $prefix = 'h' ) {
	return $prefix . '_' . strtolower( wp_generate_password( 12, false, false ) );
}

/**
 * Decode a JSON column into an array, never returning null.
 *
 * @param mixed $raw Raw column value.
 * @return array
 */
function havato_json( $raw ) {
	if ( is_array( $raw ) ) {
		return $raw;
	}
	if ( ! is_string( $raw ) || '' === trim( $raw ) ) {
		return array();
	}
	$decoded = json_decode( $raw, true );
	return is_array( $decoded ) ? $decoded : array();
}

/**
 * Get the Havato role of a user.
 *
 * @param int|WP_User|null $user User or id.
 * @return string 'gatherer' | 'cafe_owner' | 'admin' | 'guest'
 */
function havato_user_role( $user = null ) {
	if ( is_numeric( $user ) ) {
		$user = get_user_by( 'id', (int) $user );
	}
	if ( ! $user instanceof WP_User ) {
		$user = wp_get_current_user();
	}
	if ( ! $user || ! $user->exists() ) {
		return 'guest';
	}
	if ( in_array( 'cafe_owner', (array) $user->roles, true ) ) {
		return 'cafe_owner';
	}
	if ( user_can( $user, 'manage_options' ) ) {
		return 'admin';
	}
	if ( in_array( 'gatherer', (array) $user->roles, true ) ) {
		return 'gatherer';
	}
	return 'gatherer';
}

/**
 * Avatar URL with a deterministic gradient fallback.
 *
 * @param int $user_id User id.
 * @return string
 */
function havato_avatar( $user_id ) {
	$custom = get_user_meta( (int) $user_id, 'havato_avatar', true );
	if ( $custom ) {
		return esc_url_raw( $custom );
	}
	return get_avatar_url( (int) $user_id, array( 'size' => 128, 'default' => 'mystery' ) );
}

/**
 * Display name for the app (never leaks the e-mail).
 *
 * @param int $user_id User id.
 * @return string
 */
function havato_display_name( $user_id ) {
	$user = get_user_by( 'id', (int) $user_id );
	if ( ! $user ) {
		return Havato_I18N::t( 'app_name' );
	}
	$name = trim( $user->display_name );
	if ( '' === $name || is_email( $name ) ) {
		$name = trim( $user->first_name . ' ' . $user->last_name );
	}
	if ( '' === $name ) {
		$name = ucfirst( preg_replace( '/@.*/', '', $user->user_login ) );
	}
	return $name;
}

/**
 * Format a price for the active language.
 *
 * @param int         $amount Amount in Toman.
 * @param string|null $lang   Language.
 * @return string
 */
function havato_price( $amount, $lang = null ) {
	$lang   = $lang ? $lang : Havato_I18N::current_lang();
	$amount = (int) $amount;
	if ( $amount <= 0 ) {
		return Havato_I18N::t( 'free', $lang );
	}
	$formatted = number_format( $amount );
	if ( 'fa' === $lang ) {
		return Havato_Jalali::fa_digits( $formatted ) . ' ' . Havato_I18N::t( 'toman', $lang );
	}
	return $formatted . ' ' . Havato_I18N::t( 'toman', $lang );
}

/**
 * Localized date formatting shortcut.
 *
 * @param string      $date      MySQL date/datetime.
 * @param string|null $lang      Language.
 * @param bool        $with_time Include time.
 * @return string
 */
function havato_date( $date, $lang = null, $with_time = false ) {
	$lang = $lang ? $lang : Havato_I18N::current_lang();
	return Havato_Jalali::format( $date, $lang, $with_time );
}

/**
 * Both localized variants of a date, for the client-side instant switch.
 *
 * @param string $date      MySQL date/datetime.
 * @param bool   $with_time Include the time part.
 * @return array{fa:string,en:string}
 */
function havato_date_pair( $date, $with_time = false ) {
	return array(
		'fa' => Havato_Jalali::format( $date, 'fa', $with_time ),
		'en' => Havato_Jalali::format( $date, 'en', $with_time ),
	);
}

/**
 * Both localized variants of a price.
 *
 * @param int $amount Amount.
 * @return array{fa:string,en:string}
 */
function havato_price_pair( $amount ) {
	return array(
		'fa' => havato_price( $amount, 'fa' ),
		'en' => havato_price( $amount, 'en' ),
	);
}

/**
 * Is user A blocked by user B (in either direction)?
 *
 * Hard constraint used by matching, friendship, gallery and private chat.
 *
 * @param int $a First user.
 * @param int $b Second user.
 * @return bool
 */
function havato_is_blocked( $a, $b ) {
	$a = (int) $a;
	$b = (int) $b;
	if ( ! $a || ! $b || $a === $b ) {
		return false;
	}

	global $wpdb;
	$table = Havato_DB::table( 'user_profiles' );

	// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	$rows = $wpdb->get_results( $wpdb->prepare( "SELECT user_id, blocklist_json FROM $table WHERE user_id IN (%d,%d)", $a, $b ), ARRAY_A );

	foreach ( (array) $rows as $row ) {
		$list  = array_map( 'intval', havato_json( $row['blocklist_json'] ) );
		$other = ( (int) $row['user_id'] === $a ) ? $b : $a;
		if ( in_array( $other, $list, true ) ) {
			return true;
		}
	}

	return false;
}

/**
 * Friendship status between two users.
 *
 * @param int $a Viewer.
 * @param int $b Target.
 * @return string 'none' | 'pending_out' | 'pending_in' | 'accepted' | 'rejected'
 */
function havato_friend_status( $a, $b ) {
	$a = (int) $a;
	$b = (int) $b;
	if ( ! $a || ! $b || $a === $b ) {
		return 'none';
	}

	global $wpdb;
	$table = Havato_DB::table( 'friends' );

	// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	$row = $wpdb->get_row(
		$wpdb->prepare(
			"SELECT * FROM $table WHERE (user_id=%d AND friend_id=%d) OR (user_id=%d AND friend_id=%d) ORDER BY id DESC LIMIT 1",
			$a,
			$b,
			$b,
			$a
		),
		ARRAY_A
	);

	if ( ! $row ) {
		return 'none';
	}
	if ( 'accepted' === $row['status'] ) {
		return 'accepted';
	}
	if ( 'pending' === $row['status'] ) {
		return ( (int) $row['user_id'] === $a ) ? 'pending_out' : 'pending_in';
	}
	return 'rejected';
}

/**
 * Are two users confirmed friends?
 *
 * @param int $a First user.
 * @param int $b Second user.
 * @return bool
 */
function havato_are_friends( $a, $b ) {
	return 'accepted' === havato_friend_status( $a, $b );
}

/**
 * Fetch (and lazily create) a Havato personality profile row.
 *
 * @param int $user_id User id.
 * @return array
 */
function havato_get_profile( $user_id ) {
	global $wpdb;
	$user_id = (int) $user_id;
	$table   = Havato_DB::table( 'user_profiles' );

	// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	$row = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $table WHERE user_id=%d", $user_id ), ARRAY_A );

	if ( ! $row ) {
		$row = array(
			'user_id'                  => $user_id,
			'age'                      => 0,
			'gender'                   => '',
			'country'                  => '',
			'city'                     => '',
			'city_neighborhood'        => '',
			'personality_extroversion' => 5,
			'personality_talkative'    => 5,
			'personality_vibe'         => 'fun',
			'personality_interests'    => '[]',
			'rating_score'             => 5,
			'rating_count'             => 0,
			'no_show_count'            => 0,
			'attended_count'           => 0,
			'blocklist_json'           => '[]',
			'completed'                => 0,
			'updated_at'               => havato_now(),
		);
	}

	$row['interests'] = havato_json( isset( $row['personality_interests'] ) ? $row['personality_interests'] : '' );
	$row['blocklist'] = array_map( 'intval', havato_json( isset( $row['blocklist_json'] ) ? $row['blocklist_json'] : '' ) );

	return $row;
}

/**
 * Predefined interest tags (bilingual).
 *
 * @return array
 */
function havato_interest_tags() {
	return array(
		'music'    => array( 'fa' => 'موسیقی', 'en' => 'Music' ),
		'cinema'   => array( 'fa' => 'سینما', 'en' => 'Cinema' ),
		'books'    => array( 'fa' => 'کتاب', 'en' => 'Books' ),
		'startup'  => array( 'fa' => 'استارتاپ', 'en' => 'Startups' ),
		'tech'     => array( 'fa' => 'تکنولوژی', 'en' => 'Technology' ),
		'travel'   => array( 'fa' => 'سفر', 'en' => 'Travel' ),
		'sports'   => array( 'fa' => 'ورزش', 'en' => 'Sports' ),
		'art'      => array( 'fa' => 'هنر', 'en' => 'Art' ),
		'food'     => array( 'fa' => 'آشپزی', 'en' => 'Food' ),
		'gaming'   => array( 'fa' => 'بازی', 'en' => 'Gaming' ),
		'philo'    => array( 'fa' => 'فلسفه', 'en' => 'Philosophy' ),
		'business' => array( 'fa' => 'کسب‌وکار', 'en' => 'Business' ),
	);
}

/**
 * Supported countries and their cities.
 *
 * Single source of truth: the personality test, the venue settings screen and
 * the city filter all read this list, so adding a city later means editing
 * one array.
 *
 * @return array
 */
function havato_locations() {
	return array(
		'ir' => array(
			'label'  => array( 'fa' => 'ایران', 'en' => 'Iran' ),
			'cities' => array(
				'tehran'  => array( 'fa' => 'تهران', 'en' => 'Tehran' ),
				'isfahan' => array( 'fa' => 'اصفهان', 'en' => 'Isfahan' ),
			),
		),
		'tr' => array(
			'label'  => array( 'fa' => 'ترکیه', 'en' => 'Turkey' ),
			'cities' => array(
				'istanbul' => array( 'fa' => 'استانبول', 'en' => 'Istanbul' ),
			),
		),
	);
}

/**
 * Is this a country we operate in?
 *
 * @param string $country Country key.
 * @return bool
 */
function havato_valid_country( $country ) {
	return array_key_exists( (string) $country, havato_locations() );
}

/**
 * Does the given city belong to the given country?
 *
 * @param string $country Country key.
 * @param string $city    City key.
 * @return bool
 */
function havato_valid_city( $country, $city ) {
	$all = havato_locations();
	return isset( $all[ (string) $country ]['cities'][ (string) $city ] );
}

/**
 * Bilingual label for a city key.
 *
 * @param string $city City key.
 * @return array{fa:string,en:string}
 */
function havato_city_label( $city ) {
	foreach ( havato_locations() as $country ) {
		if ( isset( $country['cities'][ (string) $city ] ) ) {
			return $country['cities'][ (string) $city ];
		}
	}
	return array( 'fa' => '', 'en' => '' );
}

/**
 * Sanitize a menu payload coming from the owner portal.
 *
 * @param mixed $items Raw items.
 * @return array
 */
function havato_sanitize_menu( $items ) {
	$items = is_array( $items ) ? $items : havato_json( $items );
	$clean = array();

	foreach ( $items as $item ) {
		if ( ! is_array( $item ) ) {
			continue;
		}
		$name = isset( $item['name'] ) ? sanitize_text_field( $item['name'] ) : '';
		if ( '' === $name ) {
			continue;
		}
		$clean[] = array(
			'name'  => $name,
			'price' => isset( $item['price'] ) ? (int) $item['price'] : 0,
			'desc'  => isset( $item['desc'] ) ? sanitize_textarea_field( $item['desc'] ) : '',
			'image' => isset( $item['image'] ) ? esc_url_raw( $item['image'] ) : '',
		);
	}

	return $clean;
}

/**
 * Whether WooCommerce is active and usable.
 *
 * @return bool
 */
function havato_woo_active() {
	return class_exists( 'WooCommerce' ) && function_exists( 'WC' );
}
