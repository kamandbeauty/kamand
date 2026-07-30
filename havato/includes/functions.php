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
function havato_price( $amount, $lang = null, $country = '' ) {
	$lang   = $lang ? $lang : Havato_I18N::current_lang();
	$amount = (int) $amount;
	if ( $amount <= 0 ) {
		return Havato_I18N::t( 'free', $lang );
	}

	$formatted = number_format( $amount );
	if ( 'fa' === $lang ) {
		$formatted = Havato_Jalali::fa_digits( $formatted );
	}

	return $formatted . ' ' . havato_currency_label( $country, $lang );
}

/**
 * Currency of a café, by the country it trades in.
 *
 * A price belongs to the till, not to the reader: an Istanbul café charges
 * Lira whether the menu is being read in Persian, English or Turkish. Reading
 * it off the interface language would have shown Toman to a Persian visitor
 * looking at a Turkish café.
 *
 * @param string      $country Country key ('ir', 'tr', …).
 * @param string|null $lang    Language to label it in.
 * @return string
 */
function havato_currency_label( $country, $lang = null ) {
	$lang    = $lang ? $lang : Havato_I18N::current_lang();
	$country = strtolower( (string) $country );

	$map = apply_filters(
		'havato_country_currencies',
		array(
			'ir' => 'toman',
			'tr' => 'lira',
		)
	);

	// An unknown country falls back to the platform's home currency rather
	// than printing a bare number with no unit at all.
	$key = isset( $map[ $country ] ) ? $map[ $country ] : 'toman';

	return Havato_I18N::t( $key, $lang );
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
 * Decode a chat line into a per-language map.
 *
 * System messages are stored as a JSON object keyed by language. Everything a
 * guest types is plain text and must be returned untouched — including text
 * that merely looks like JSON, which is why only system rows are decoded.
 *
 * Rows written before v1.21.0 hold one glued-together bilingual string; those
 * are returned as-is in every language rather than being reformatted, so old
 * conversations keep reading exactly as they did.
 *
 * @param string $raw       Stored message text.
 * @param bool   $is_system Whether the row is a system line.
 * @return array Language map, always containing every supported language.
 */
function havato_message_pair( $raw, $is_system = false ) {
	$langs = array_keys( Havato_I18N::languages() );
	$out   = array();

	$decoded = $is_system ? json_decode( (string) $raw, true ) : null;

	foreach ( $langs as $lang ) {
		if ( is_array( $decoded ) && isset( $decoded[ $lang ] ) && is_string( $decoded[ $lang ] ) ) {
			$out[ $lang ] = $decoded[ $lang ];
			continue;
		}
		if ( is_array( $decoded ) && isset( $decoded['en'] ) && is_string( $decoded['en'] ) ) {
			$out[ $lang ] = $decoded['en'];
			continue;
		}
		$out[ $lang ] = (string) $raw;
	}

	return $out;
}

/**
 * Flatten a chat line for a screen that shows one language (the admin archive).
 *
 * @param string $raw       Stored message text.
 * @param bool   $is_system Whether the row is a system line.
 * @param string $lang      Language to render.
 * @return string
 */
function havato_message_text( $raw, $is_system = false, $lang = null ) {
	$lang = $lang ? $lang : Havato_I18N::current_lang();
	$pair = havato_message_pair( $raw, $is_system );
	return isset( $pair[ $lang ] ) ? $pair[ $lang ] : reset( $pair );
}

/**
 * Every localized variant of a price.
 *
 * @param int    $amount  Amount.
 * @param string $country Country of the café that charges it.
 * @return array Language map.
 */
function havato_price_pair( $amount, $country = '' ) {
	$out = array();
	foreach ( array_keys( Havato_I18N::languages() ) as $lang ) {
		$out[ $lang ] = havato_price( $amount, $lang, $country );
	}
	return $out;
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
			'personality_extroversion' => 5,
			'personality_talkative'    => 5,
			'personality_openness'     => 5,
			'personality_humor'        => 5,
			'personality_energy'       => 5,
			'personality_planning'     => 5,
			'personality_empathy'      => 5,
			'personality_vibe'         => 'fun',
			'personality_interests'    => '[]',
			'rating_score'             => 5,
			'rating_count'             => 0,
			'no_show_count'            => 0,
			'empty_seat_count'         => 0,
			'penalty_points'           => 0,
			'phone'                    => '',
			'attended_count'           => 0,
			'blocklist_json'           => '[]',
			'completed'                => 0,
			'updated_at'               => havato_now(),
		);
	}

	// Traits added in DB 1.7.0. A row written before the upgrade ran simply
	// has no such key, and every caller reads them unconditionally, so give
	// them the neutral midpoint rather than letting them read as 0 (which the
	// matcher would score as "extremely introverted").
	foreach ( array( 'extroversion', 'talkative', 'openness', 'humor', 'energy', 'planning', 'empathy' ) as $havato_trait ) {
		$havato_key = 'personality_' . $havato_trait;
		if ( ! isset( $row[ $havato_key ] ) || '' === $row[ $havato_key ] || null === $row[ $havato_key ] ) {
			$row[ $havato_key ] = 5;
		}
	}

	// Columns added in DB 1.10.0. Same reasoning: a row written before the
	// upgrade has no such key, and havato_effective_rating() reads
	// penalty_points on every profile render.
	foreach ( array( 'no_show_count' => 0, 'empty_seat_count' => 0, 'penalty_points' => 0, 'phone' => '' ) as $havato_col => $havato_default ) {
		if ( ! isset( $row[ $havato_col ] ) || null === $row[ $havato_col ] ) {
			$row[ $havato_col ] = $havato_default;
		}
	}

	$row['interests'] = havato_json( isset( $row['personality_interests'] ) ? $row['personality_interests'] : '' );
	$row['blocklist'] = array_map( 'intval', havato_json( isset( $row['blocklist_json'] ) ? $row['blocklist_json'] : '' ) );

	return $row;
}

/**
 * International dialling prefix of a country we operate in.
 *
 * @param string $country Country key.
 * @return string e.g. "+98", or '' when unknown.
 */
function havato_dial_code( $country ) {
	$all = havato_locations();
	$key = (string) $country;
	return isset( $all[ $key ]['dial'] ) ? $all[ $key ]['dial'] : '';
}

/**
 * Normalise a phone number to E.164-ish "+<dial><national>".
 *
 * Guests type their number in whatever shape they know it — "0912…",
 * "+98912…", "0098912…", with spaces or dashes. All of those must end up as
 * one canonical string, otherwise the same person looks like several.
 *
 * @param string $raw     Whatever the user typed.
 * @param string $country Selected country key, used for the prefix.
 * @return string Normalised number, or '' when it cannot be salvaged.
 */
function havato_normalize_phone( $raw, $country ) {
	// Persian/Arabic-Indic digits first, or the whole thing looks empty.
	$raw = Havato_Jalali::en_digits( (string) $raw );
	$raw = trim( $raw );
	if ( '' === $raw ) {
		return '';
	}

	$dial = havato_dial_code( $country );
	$cc   = ltrim( $dial, '+' );

	// Keep digits only; remember whether it was already international.
	$plus   = ( 0 === strpos( $raw, '+' ) );
	$digits = preg_replace( '/\D+/', '', $raw );
	if ( '' === $digits ) {
		return '';
	}

	// "0098…" is the same as "+98…".
	if ( ! $plus && $cc && 0 === strpos( $digits, '00' . $cc ) ) {
		$digits = substr( $digits, 2 );
		$plus   = true;
	}

	if ( $plus || ( $cc && 0 === strpos( $digits, $cc ) && strlen( $digits ) > strlen( $cc ) + 6 ) ) {
		// Already carries the country code.
		$national = $cc && 0 === strpos( $digits, $cc ) ? substr( $digits, strlen( $cc ) ) : $digits;
	} else {
		$national = $digits;
	}

	// Domestic trunk zero is dropped once the country code is attached.
	$national = ltrim( $national, '0' );

	if ( strlen( $national ) < 6 || strlen( $national ) > 14 ) {
		return '';
	}

	return ( $dial ? $dial : '+' ) . $national;
}

/**
 * Behaviour score actually shown and matched on.
 *
 * `rating_score` is the peer-feedback average and is rewritten wholesale by
 * recalculate_rating(); reliability penalties therefore live in their own
 * column and are subtracted here, at read time, so the two can never
 * overwrite one another.
 *
 * @param array $profile Profile row.
 * @return float 0..5
 */
function havato_effective_rating( $profile ) {
	$base    = isset( $profile['rating_score'] ) ? (float) $profile['rating_score'] : 5.0;
	$penalty = isset( $profile['penalty_points'] ) ? (float) $profile['penalty_points'] : 0.0;
	$floor   = (float) Havato_Settings::get( 'penalty_floor', 1 );

	return max( $floor, min( 5.0, $base - $penalty ) );
}

/**
 * Is this account banned from the platform?
 *
 * Stored as user meta rather than deleting the account, so the person's
 * history stays intact for moderation and the decision is reversible.
 *
 * @param int $user_id User id.
 * @return bool
 */
function havato_is_banned( $user_id ) {
	$user_id = (int) $user_id;
	if ( ! $user_id ) {
		return false;
	}
	return '1' === (string) get_user_meta( $user_id, 'havato_banned', true );
}

/**
 * Ban or reinstate an account.
 *
 * @param int  $user_id User id.
 * @param bool $banned  True to ban.
 */
function havato_set_banned( $user_id, $banned ) {
	$user_id = (int) $user_id;
	if ( ! $user_id ) {
		return;
	}

	if ( $banned ) {
		update_user_meta( $user_id, 'havato_banned', '1' );
		update_user_meta( $user_id, 'havato_banned_at', havato_now() );
		// End every active session immediately.
		$sessions = WP_Session_Tokens::get_instance( $user_id );
		$sessions->destroy_all();
	} else {
		delete_user_meta( $user_id, 'havato_banned' );
		delete_user_meta( $user_id, 'havato_banned_at' );
	}
}

/**
 * Words that mark a message for moderator review.
 *
 * Deliberately a review signal, not a censor: nothing is blocked or altered
 * and the sender is never told. The list is filterable so a site can tune it
 * without touching the plugin.
 *
 * @return array Lower-case terms.
 */
function havato_profanity_terms() {
	$terms = array(
		// Persian
		'کیر', 'کس', 'کون', 'جنده', 'کصکش', 'کسکش', 'جاکش', 'مادرجنده',
		'حرومزاده', 'حرامزاده', 'بیناموس', 'بی‌ناموس', 'گاییدم', 'گایید',
		'کونی', 'ممه', 'لاشی', 'عوضی', 'دیوث', 'قرمساق', 'پدرسگ', 'خارکسه',
		'گوه', 'ریدم', 'شاش', 'اوبی', 'ساک زدن',
		// English
		'fuck', 'fucking', 'fucker', 'motherfucker', 'shit', 'bullshit',
		'bitch', 'bastard', 'asshole', 'cunt', 'dick', 'pussy', 'whore',
		'slut', 'faggot', 'nigger', 'wanker', 'prick', 'twat',
		// Turkish
		'amk', 'aq', 'sik', 'sikeyim', 'siktir', 'orospu', 'piç', 'göt',
		'yarrak', 'amcık', 'kahpe', 'pezevenk', 'ibne', 'oç',
	);

	/**
	 * Adjust the review word list.
	 *
	 * @param array $terms Lower-case terms.
	 */
	$terms = apply_filters( 'havato_profanity_terms', $terms );

	return array_values( array_unique( array_filter( array_map( 'strval', (array) $terms ) ) ) );
}

/**
 * Does a message contain anything worth a moderator's attention?
 *
 * Matching is deliberately simple and forgiving: text is lower-cased, Arabic
 * variants of Persian letters are folded, and common letter-for-symbol
 * substitutions (@ for a, 0 for o…) are undone, so "f*ck" and "sh1t" still
 * register. False positives only add a flag in the admin panel, so a slightly
 * eager match is far cheaper than a missed one.
 *
 * @param string $text Message text.
 * @return string The first term matched, or '' when clean.
 */
function havato_profanity_hit( $text ) {
	$text = (string) $text;
	if ( '' === trim( $text ) ) {
		return '';
	}

	$haystack = function_exists( 'mb_strtolower' ) ? mb_strtolower( $text, 'UTF-8' ) : strtolower( $text );

	// Persian text is routinely typed with Arabic ي/ك; fold them so one entry
	// in the list covers both spellings.
	$haystack = strtr(
		$haystack,
		array(
			'ي' => 'ی',
			'ك' => 'ک',
			'ۀ' => 'ه',
			'ة' => 'ه',
			'‌' => '', // zero-width non-joiner
			'‏' => '',
			'‎' => '',
		)
	);

	// Undo the usual letter-for-symbol substitutions.
	$decoded = strtr(
		$haystack,
		array(
			'@' => 'a',
			'$' => 's',
			'0' => 'o',
			'1' => 'i',
			'3' => 'e',
			'4' => 'a',
			'5' => 's',
			'7' => 't',
		)
	);

	// Separators inserted to dodge a filter ("f.u.c.k", "s h i t") are
	// collapsed. A marker is left where they were so a word boundary still
	// exists there — deleting them outright glued the word to its neighbour
	// and defeated the boundary check below.
	$collapsed = preg_replace( '/[*._\-\s]+/u', "\x01", $decoded );
	$collapsed = str_replace( "\x01", '', $collapsed );

	// The same text with the separators kept as boundaries.
	$spaced = preg_replace( '/[*._\-\s]+/u', ' ', $decoded );

	// Did the writer split a word up to dodge a filter? Two signals, both of
	// which ordinary prose does not produce:
	//   - punctuation wedged between two letters ("f.u.c.k", "f**k");
	//   - three or more single letters separated one by one ("b i t c h").
	// Plain spacing between whole words is deliberately NOT a signal.
	$obfuscated = (bool) preg_match( '/[^\W\d_][*._\-]+[^\W\d_]/u', $decoded )
		|| (bool) preg_match( '/(?:^|\s)[^\W\d_](?:[*._\-\s]+[^\W\d_]){2,}(?:\s|$)/u', $decoded );

	// A censored vowel ("f*ck") vanishes with the symbol, so also compare
	// against a vowel-free form.
	$devowelled = preg_replace( '/[aeiou]/', '', $collapsed );

	foreach ( havato_profanity_terms() as $term ) {
		$needle = function_exists( 'mb_strtolower' ) ? mb_strtolower( $term, 'UTF-8' ) : strtolower( $term );
		if ( '' === $needle ) {
			continue;
		}

		$flat = preg_replace( '/[\s._\-]+/u', '', $needle );

		// Plain text, and the separator-normalised form.
		if ( havato_term_in_text( $needle, $haystack )
			|| havato_term_in_text( $flat, $spaced ) ) {
			return $term;
		}

		// Only when the writer actually broke a word up ("f.u.c.k", "s h i t")
		// is the glued form consulted, and then as a plain substring. Gating
		// it on $obfuscated is what keeps innocent words such as "Shitake"
		// clean: they contain no intra-word separators, so they never reach
		// this branch.
		if ( $obfuscated && '' !== $flat && false !== strpos( $collapsed, $flat ) ) {
			return $term;
		}

		// "f*ck" style: only for longer Latin terms, so short words do not
		// collide once their vowels are gone.
		// Same gate for a censored vowel: only when the writer inserted a
		// symbol mid-word, and then as a substring, since removing vowels
		// destroys the word boundaries a regex would need.
		if ( $obfuscated && preg_match( '/^[a-z]{5,}$/', $flat ) ) {
			$short = preg_replace( '/[aeiou]/', '', $flat );
			if ( strlen( $short ) >= 3 && false !== strpos( $devowelled, $short ) ) {
				return $term;
			}
		}
	}

	return '';
}

/**
 * Whole-word search that also works for Persian.
 *
 * A plain substring test flags innocent words that merely contain a rude one
 * ("Scunthorpe", "Shitake"), so Latin terms are matched on word boundaries.
 * \b is unreliable around Arabic-script characters, so Persian terms keep the
 * substring test: Persian compounds and clitics are written without spaces,
 * and there a missed insult costs more than an occasional extra flag.
 *
 * @param string $needle   Lower-case term.
 * @param string $haystack Lower-case text.
 * @return bool
 */
function havato_term_in_text( $needle, $haystack ) {
	if ( '' === $needle || '' === $haystack ) {
		return false;
	}

	// Latin-only term: require a word boundary.
	if ( preg_match( '/^[a-z0-9]+$/', $needle ) ) {
		return (bool) preg_match( '/(?<![a-z0-9])' . preg_quote( $needle, '/' ) . '(?![a-z0-9])/u', $haystack );
	}

	return false !== strpos( $haystack, $needle );
}

/**
 * Clamp free text to a sane length before it is stored.
 *
 * `sanitize_textarea_field()` strips tags but imposes no size limit, so a
 * scripted client could post megabytes into a TEXT column on every request.
 * Everything user-authored goes through here first.
 *
 * @param string $text Sanitised text.
 * @param int    $max  Maximum characters.
 * @return string
 */
function havato_clamp_text( $text, $max = 2000 ) {
	$text = trim( (string) $text );
	$max  = max( 1, (int) $max );

	if ( function_exists( 'mb_substr' ) ) {
		return mb_substr( $text, 0, $max );
	}
	return substr( $text, 0, $max );
}

/**
 * Most seats one guest may book for a single gathering.
 *
 * @return int
 */
function havato_max_seats() {
	$max = (int) apply_filters( 'havato_max_seats', defined( 'HAVATO_MAX_SEATS' ) ? HAVATO_MAX_SEATS : 3 );
	return max( 1, $max );
}

/**
 * How many hours before a gathering it stops accepting new guests.
 *
 * A table is only worth sitting at if the matcher can still seat people
 * sensibly and everyone has time to travel. Booking ten minutes before the
 * doors open helps nobody, so the listing closes ahead of the start.
 *
 * @return int Hours.
 */
function havato_booking_cutoff_hours() {
	$hours = (int) Havato_Settings::get( 'booking_cutoff_hours', 5 );
	$hours = (int) apply_filters( 'havato_booking_cutoff_hours', $hours );
	return max( 0, $hours );
}

/**
 * The earliest start time a gathering may still have to be listed.
 *
 * Returned as a MySQL datetime in the site's own timezone, so it can be
 * compared against the event's own date and time columns without either side
 * drifting to UTC.
 *
 * @return string
 */
function havato_booking_cutoff() {
	$now = strtotime( havato_now() );
	return gmdate( 'Y-m-d H:i:s', $now + ( havato_booking_cutoff_hours() * HOUR_IN_SECONDS ) );
}

/**
 * Predefined interest tags (bilingual).
 *
 * @return array
 */
function havato_interest_tags() {
	return array(
		'music'      => array( 'fa' => 'موسیقی', 'en' => 'Music', 'tr' => 'Müzik' ),
		'cinema'     => array( 'fa' => 'سینما', 'en' => 'Cinema', 'tr' => 'Sinema' ),
		'series'     => array( 'fa' => 'سریال', 'en' => 'TV series', 'tr' => 'Diziler' ),
		'books'      => array( 'fa' => 'کتاب', 'en' => 'Books', 'tr' => 'Kitap' ),
		'writing'    => array( 'fa' => 'نویسندگی', 'en' => 'Writing', 'tr' => 'Yazarlık' ),
		'poetry'     => array( 'fa' => 'شعر و ادبیات', 'en' => 'Poetry & literature', 'tr' => 'Şiir ve edebiyat' ),
		'art'        => array( 'fa' => 'هنر', 'en' => 'Art', 'tr' => 'Sanat' ),
		'photo'      => array( 'fa' => 'عکاسی', 'en' => 'Photography', 'tr' => 'Fotoğrafçılık' ),
		'theatre'    => array( 'fa' => 'تئاتر', 'en' => 'Theatre', 'tr' => 'Tiyatro' ),
		'startup'    => array( 'fa' => 'استارتاپ', 'en' => 'Startups', 'tr' => 'Girişimcilik' ),
		'business'   => array( 'fa' => 'کسب‌وکار', 'en' => 'Business', 'tr' => 'İş dünyası' ),
		'marketing'  => array( 'fa' => 'بازاریابی', 'en' => 'Marketing', 'tr' => 'Pazarlama' ),
		'tech'       => array( 'fa' => 'تکنولوژی', 'en' => 'Technology', 'tr' => 'Teknoloji' ),
		'programming' => array( 'fa' => 'برنامه‌نویسی', 'en' => 'Programming', 'tr' => 'Yazılım' ),
		'ai'         => array( 'fa' => 'هوش مصنوعی', 'en' => 'AI', 'tr' => 'Yapay zekâ' ),
		'science'    => array( 'fa' => 'علم', 'en' => 'Science', 'tr' => 'Bilim' ),
		'philo'      => array( 'fa' => 'فلسفه', 'en' => 'Philosophy', 'tr' => 'Felsefe' ),
		'psychology' => array( 'fa' => 'روان‌شناسی', 'en' => 'Psychology', 'tr' => 'Psikoloji' ),
		'history'    => array( 'fa' => 'تاریخ', 'en' => 'History', 'tr' => 'Tarih' ),
		'language'   => array( 'fa' => 'زبان‌آموزی', 'en' => 'Languages', 'tr' => 'Yabancı dil' ),
		'travel'     => array( 'fa' => 'سفر', 'en' => 'Travel', 'tr' => 'Seyahat' ),
		'nature'     => array( 'fa' => 'طبیعت‌گردی', 'en' => 'Nature & hiking', 'tr' => 'Doğa ve yürüyüş' ),
		'sports'     => array( 'fa' => 'ورزش', 'en' => 'Sports', 'tr' => 'Spor' ),
		'football'   => array( 'fa' => 'فوتبال', 'en' => 'Football', 'tr' => 'Futbol' ),
		'fitness'    => array( 'fa' => 'تناسب اندام', 'en' => 'Fitness', 'tr' => 'Fitness' ),
		'yoga'       => array( 'fa' => 'یوگا و مدیتیشن', 'en' => 'Yoga & meditation', 'tr' => 'Yoga ve meditasyon' ),
		'food'       => array( 'fa' => 'آشپزی', 'en' => 'Cooking', 'tr' => 'Yemek yapmak' ),
		'coffee'     => array( 'fa' => 'قهوه', 'en' => 'Coffee', 'tr' => 'Kahve' ),
		'gaming'     => array( 'fa' => 'بازی ویدیویی', 'en' => 'Video games', 'tr' => 'Video oyunları' ),
		'boardgames' => array( 'fa' => 'بازی رومیزی', 'en' => 'Board games', 'tr' => 'Kutu oyunları' ),
		'pets'       => array( 'fa' => 'حیوانات خانگی', 'en' => 'Pets', 'tr' => 'Evcil hayvanlar' ),
		'volunteer'  => array( 'fa' => 'کار داوطلبانه', 'en' => 'Volunteering', 'tr' => 'Gönüllülük' ),
		'fashion'    => array( 'fa' => 'مد و استایل', 'en' => 'Fashion', 'tr' => 'Moda' ),
		'cars'       => array( 'fa' => 'خودرو', 'en' => 'Cars', 'tr' => 'Otomobil' ),
		'crafts'     => array( 'fa' => 'کاردستی', 'en' => 'Crafts & DIY', 'tr' => 'El işi' ),
		'finance'    => array( 'fa' => 'سرمایه‌گذاری', 'en' => 'Investing', 'tr' => 'Yatırım' ),
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
			'label'  => array( 'fa' => 'ایران', 'en' => 'Iran', 'tr' => 'İran' ),
			'dial'   => '+98',
			'cities' => array(
				'tehran'  => array( 'fa' => 'تهران', 'en' => 'Tehran', 'tr' => 'Tahran', 'lat' => 35.7219, 'lng' => 51.3347, 'zoom' => 12 ),
				'isfahan' => array( 'fa' => 'اصفهان', 'en' => 'Isfahan', 'tr' => 'İsfahan', 'lat' => 32.6539, 'lng' => 51.6660, 'zoom' => 12 ),
			),
		),
		'tr' => array(
			'label'  => array( 'fa' => 'ترکیه', 'en' => 'Turkey', 'tr' => 'Türkiye' ),
			'dial'   => '+90',
			'cities' => array(
				'istanbul' => array( 'fa' => 'استانبول', 'en' => 'Istanbul', 'tr' => 'İstanbul', 'lat' => 41.0082, 'lng' => 28.9784, 'zoom' => 11 ),
			),
		),
	);
}

/**
 * Map centre for a city key.
 *
 * The map used to open on the admin's global default for everyone, so a
 * guest in Istanbul was shown Tehran. Falls back to that default only when
 * the city is unknown.
 *
 * @param string $city City key.
 * @return array|null array{lat:float,lng:float,zoom:int} or null.
 */
function havato_city_center( $city ) {
	foreach ( havato_locations() as $country ) {
		if ( isset( $country['cities'][ (string) $city ]['lat'] ) ) {
			$c = $country['cities'][ (string) $city ];
			return array(
				'lat'  => (float) $c['lat'],
				'lng'  => (float) $c['lng'],
				'zoom' => isset( $c['zoom'] ) ? (int) $c['zoom'] : 12,
			);
		}
	}
	return null;
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
			$c = $country['cities'][ (string) $city ];
			// Return ONLY the language keys: the row also carries lat/lng/zoom
			// and handing the whole thing to the UI printed "[object Object]".
			return array(
				'fa' => isset( $c['fa'] ) ? $c['fa'] : '',
				'en' => isset( $c['en'] ) ? $c['en'] : '',
				'tr' => isset( $c['tr'] ) ? $c['tr'] : ( isset( $c['en'] ) ? $c['en'] : '' ),
			);
		}
	}
	return array( 'fa' => '', 'en' => '', 'tr' => '' );
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

	// The whole menu lands in one longtext column, so bound both the number
	// of rows and the length of each field. Without this an owner could post
	// an arbitrarily large payload on every save.
	$max_items = (int) apply_filters( 'havato_max_menu_items', 200 );

	foreach ( $items as $item ) {
		if ( count( $clean ) >= $max_items ) {
			break;
		}
		if ( ! is_array( $item ) ) {
			continue;
		}
		$name = isset( $item['name'] ) ? havato_clamp_text( sanitize_text_field( $item['name'] ), 120 ) : '';
		if ( '' === $name ) {
			continue;
		}
		$clean[] = array(
			'name'  => $name,
			'price' => isset( $item['price'] ) ? max( 0, (int) $item['price'] ) : 0,
			'desc'  => isset( $item['desc'] ) ? havato_clamp_text( sanitize_textarea_field( $item['desc'] ), 300 ) : '',
			'image' => isset( $item['image'] ) ? esc_url_raw( $item['image'] ) : '',
		);
	}

	return $clean;
}

