<?php
/**
 * Lightweight Jalali (Persian / Shamsi) <-> Gregorian date conversion.
 *
 * Zero external dependency: the algorithm below is a compact PHP port of the
 * well known `jalaali-js` / `jalaali-php` implementation (MIT), vendored here
 * so the plugin never needs Composer or a heavy i18n library.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Jalali date helper.
 */
class Havato_Jalali {

	/**
	 * Persian month names.
	 *
	 * @var array
	 */
	public static $months_fa = array(
		1  => 'فروردین',
		2  => 'اردیبهشت',
		3  => 'خرداد',
		4  => 'تیر',
		5  => 'مرداد',
		6  => 'شهریور',
		7  => 'مهر',
		8  => 'آبان',
		9  => 'آذر',
		10 => 'دی',
		11 => 'بهمن',
		12 => 'اسفند',
	);

	/**
	 * Persian week day names, index 0 = Saturday.
	 *
	 * @var array
	 */
	public static $days_fa = array( 'شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه', 'جمعه' );

	/**
	 * Gregorian -> Jalali.
	 *
	 * @param int $gy Gregorian year.
	 * @param int $gm Gregorian month (1-12).
	 * @param int $gd Gregorian day.
	 * @return array{0:int,1:int,2:int} [jy, jm, jd]
	 */
	public static function to_jalali( $gy, $gm, $gd ) {
		return self::d2j( self::g2d( (int) $gy, (int) $gm, (int) $gd ) );
	}

	/**
	 * Jalali -> Gregorian.
	 *
	 * @param int $jy Jalali year.
	 * @param int $jm Jalali month (1-12).
	 * @param int $jd Jalali day.
	 * @return array{0:int,1:int,2:int} [gy, gm, gd]
	 */
	public static function to_gregorian( $jy, $jm, $jd ) {
		return self::d2g( self::j2d( (int) $jy, (int) $jm, (int) $jd ) );
	}

	/**
	 * Is the given Jalali year a leap year?
	 *
	 * @param int $jy Jalali year.
	 * @return bool
	 */
	public static function is_leap_jalali_year( $jy ) {
		$r = self::jal_cal( (int) $jy );
		return 0 === $r['leap'];
	}

	/**
	 * Number of days in a Jalali month.
	 *
	 * @param int $jy Jalali year.
	 * @param int $jm Jalali month.
	 * @return int
	 */
	public static function jalali_month_length( $jy, $jm ) {
		$jm = (int) $jm;
		if ( $jm <= 6 ) {
			return 31;
		}
		if ( $jm <= 11 ) {
			return 30;
		}
		return self::is_leap_jalali_year( $jy ) ? 30 : 29;
	}

	/**
	 * Format a MySQL/ISO datetime according to the requested locale.
	 *
	 * @param string $mysql_datetime Y-m-d or Y-m-d H:i:s.
	 * @param string $lang           'fa' or 'en'.
	 * @param bool   $with_time      Append H:i.
	 * @param bool   $short          Numeric short format instead of long month names.
	 * @return string
	 */
	public static function format( $mysql_datetime, $lang = 'fa', $with_time = false, $short = false ) {
		$parts = self::parse( $mysql_datetime );
		if ( ! $parts ) {
			return '';
		}

		list( $gy, $gm, $gd, $time ) = $parts;

		if ( 'fa' === $lang ) {
			list( $jy, $jm, $jd ) = self::to_jalali( $gy, $gm, $gd );
			if ( $short ) {
				$out = self::fa_digits( sprintf( '%04d/%02d/%02d', $jy, $jm, $jd ) );
			} else {
				$out = self::fa_digits( $jd ) . ' ' . self::$months_fa[ $jm ] . ' ' . self::fa_digits( $jy );
			}
			if ( $with_time ) {
				$out .= ' — ' . self::fa_digits( $time );
			}
			return $out;
		}

		// Gregorian output: build it from the parsed parts (never from a
		// timestamp) so the stored wall-clock date is preserved regardless of
		// the server timezone.
		$months = array( 1 => 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' );

		$out = $short
			? sprintf( '%04d-%02d-%02d', $gy, $gm, $gd )
			: $gd . ' ' . $months[ $gm ] . ' ' . $gy;

		if ( $with_time ) {
			$out .= ' — ' . $time;
		}
		return $out;
	}

	/**
	 * Split a MySQL date/datetime into [Y, m, d, "H:i"] without any timezone
	 * conversion. Values stored by WordPress are already in site-local time.
	 *
	 * @param string $value Date or datetime string.
	 * @return array|false
	 */
	private static function parse( $value ) {
		$value = trim( (string) $value );
		if ( '' === $value || '0000-00-00' === substr( $value, 0, 10 ) ) {
			return false;
		}

		if ( ! preg_match( '/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?/', $value, $m ) ) {
			// Fall back to strtotime for exotic inputs, staying in server time.
			$ts = strtotime( $value );
			if ( false === $ts ) {
				return false;
			}
			return array( (int) gmdate( 'Y', $ts ), (int) gmdate( 'n', $ts ), (int) gmdate( 'j', $ts ), gmdate( 'H:i', $ts ) );
		}

		$gy = (int) $m[1];
		$gm = (int) $m[2];
		$gd = (int) $m[3];

		if ( $gm < 1 || $gm > 12 || $gd < 1 || $gd > 31 ) {
			return false;
		}

		$time = isset( $m[4] ) ? $m[4] . ':' . $m[5] : '00:00';

		return array( $gy, $gm, $gd, $time );
	}

	/**
	 * Localized week day name for a date.
	 *
	 * @param string $mysql_datetime Date string.
	 * @param string $lang           Locale.
	 * @return string
	 */
	public static function week_day( $mysql_datetime, $lang = 'fa' ) {
		$parts = self::parse( $mysql_datetime );
		if ( ! $parts ) {
			return '';
		}

		// Derive the weekday straight from the Julian Day Number so no
		// timezone can shift it: JDN % 7 == 0 is a Monday.
		$jdn = self::g2d( $parts[0], $parts[1], $parts[2] );
		$dow = self::mod( $jdn, 7 ); // 0 = Monday … 6 = Sunday.

		if ( 'fa' !== $lang ) {
			$en = array( 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday' );
			return $en[ $dow ];
		}

		// Persian week starts on Saturday (index 5 of the Monday-based array).
		$fa_index = ( $dow + 2 ) % 7;
		return self::$days_fa[ $fa_index ];
	}

	/**
	 * Convert latin digits to Persian digits.
	 *
	 * @param string|int $value Value.
	 * @return string
	 */
	public static function fa_digits( $value ) {
		$latin   = array( '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' );
		$persian = array( '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹' );
		return str_replace( $latin, $persian, (string) $value );
	}

	/**
	 * Convert Persian/Arabic digits back to latin digits.
	 *
	 * @param string $value Value.
	 * @return string
	 */
	public static function en_digits( $value ) {
		$persian = array( '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹' );
		$arabic  = array( '٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩' );
		$latin   = array( '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' );
		return str_replace( array_merge( $persian, $arabic ), array_merge( $latin, $latin ), (string) $value );
	}

	/* ---------------------------------------------------------------------
	 * Internal algorithm (jalaali-js port)
	 * ------------------------------------------------------------------ */

	/**
	 * Jalali calendar calculation.
	 *
	 * @param int $jy Jalali year.
	 * @return array{leap:int,gy:int,march:int}
	 */
	private static function jal_cal( $jy ) {
		$breaks = array( -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178 );

		$bl        = count( $breaks );
		$gy        = $jy + 621;
		$leap_j    = -14;
		$jp        = $breaks[0];
		$jump      = 0;

		if ( $jy < $jp || $jy >= $breaks[ $bl - 1 ] ) {
			// Out of supported range: fall back to the nearest boundary logic.
			$jy = max( $jp, min( $jy, $breaks[ $bl - 1 ] - 1 ) );
		}

		for ( $i = 1; $i < $bl; $i++ ) {
			$jm   = $breaks[ $i ];
			$jump = $jm - $jp;
			if ( $jy < $jm ) {
				break;
			}
			$leap_j = $leap_j + self::div( $jump, 33 ) * 8 + self::div( self::mod( $jump, 33 ), 4 );
			$jp     = $jm;
		}

		$n = $jy - $jp;

		$leap_j = $leap_j + self::div( $n, 33 ) * 8 + self::div( self::mod( $n, 33 ) + 3, 4 );
		if ( 4 === self::mod( $jump, 33 ) && $jump - $n === 4 ) {
			$leap_j++;
		}

		$leap_g = self::div( $gy, 4 ) - self::div( ( self::div( $gy, 100 ) + 1 ) * 3, 4 ) - 150;
		$march  = 20 + $leap_j - $leap_g;

		if ( $jump - $n < 6 ) {
			$n = $n - $jump + self::div( $jump + 4, 33 ) * 33;
		}

		$leap = self::mod( self::mod( $n + 1, 33 ) - 1, 4 );
		if ( -1 === $leap ) {
			$leap = 4;
		}

		return array(
			'leap'  => $leap,
			'gy'    => $gy,
			'march' => $march,
		);
	}

	/**
	 * Jalali date to Julian Day Number.
	 *
	 * @param int $jy Year.
	 * @param int $jm Month.
	 * @param int $jd Day.
	 * @return int
	 */
	private static function j2d( $jy, $jm, $jd ) {
		$r = self::jal_cal( $jy );
		return self::g2d( $r['gy'], 3, $r['march'] ) + ( $jm - 1 ) * 31 - self::div( $jm, 7 ) * ( $jm - 7 ) + $jd - 1;
	}

	/**
	 * Julian Day Number to Jalali date.
	 *
	 * @param int $jdn Julian day number.
	 * @return array
	 */
	private static function d2j( $jdn ) {
		$gy   = self::d2g( $jdn )[0];
		$jy   = $gy - 621;
		$r    = self::jal_cal( $jy );
		$jdn1 = self::g2d( $gy, 3, $r['march'] );

		$k = $jdn - $jdn1;
		if ( $k >= 0 ) {
			if ( $k <= 185 ) {
				$jm = 1 + self::div( $k, 31 );
				$jd = self::mod( $k, 31 ) + 1;
				return array( $jy, $jm, $jd );
			}
			$k -= 186;
		} else {
			$jy--;
			$k += 179;
			if ( 1 === $r['leap'] ) {
				$k++;
			}
		}

		$jm = 7 + self::div( $k, 30 );
		$jd = self::mod( $k, 30 ) + 1;

		return array( $jy, $jm, $jd );
	}

	/**
	 * Gregorian date to Julian Day Number.
	 *
	 * @param int $gy Year.
	 * @param int $gm Month.
	 * @param int $gd Day.
	 * @return int
	 */
	private static function g2d( $gy, $gm, $gd ) {
		$d = self::div( ( $gy + self::div( $gm - 8, 6 ) + 100100 ) * 1461, 4 )
			+ self::div( 153 * self::mod( $gm + 9, 12 ) + 2, 5 )
			+ $gd - 34840408;

		$d = $d - self::div( self::div( $gy + 100100 + self::div( $gm - 8, 6 ), 100 ) * 3, 4 ) + 752;

		return (int) $d;
	}

	/**
	 * Julian Day Number to Gregorian date.
	 *
	 * @param int $jdn Julian day number.
	 * @return array
	 */
	private static function d2g( $jdn ) {
		$j  = 4 * $jdn + 139361631;
		$j  = $j + self::div( self::div( 4 * $jdn + 183187720, 146097 ) * 3, 4 ) * 4 - 3908;
		$i  = self::div( self::mod( $j, 1461 ), 4 ) * 5 + 308;
		$gd = self::div( self::mod( $i, 153 ), 5 ) + 1;
		$gm = self::mod( self::div( $i, 153 ), 12 ) + 1;
		$gy = self::div( $j, 1461 ) - 100100 + self::div( 8 - $gm, 6 );

		return array( (int) $gy, (int) $gm, (int) $gd );
	}

	/**
	 * Integer division truncated toward zero.
	 *
	 * IMPORTANT: the reference implementation (jalaali-js) relies on the `~~`
	 * operator, i.e. truncation toward zero — NOT floor. Using floor() here
	 * silently shifts every date by up to a year for negative intermediates,
	 * so the (int) cast (which truncates in PHP) is deliberate.
	 *
	 * @param int|float $a Numerator.
	 * @param int|float $b Denominator.
	 * @return int
	 */
	private static function div( $a, $b ) {
		return (int) ( $a / $b );
	}

	/**
	 * Remainder matching the truncating division above.
	 *
	 * @param int|float $a Numerator.
	 * @param int|float $b Denominator.
	 * @return int
	 */
	private static function mod( $a, $b ) {
		return (int) ( $a - (int) ( $a / $b ) * $b );
	}
}
