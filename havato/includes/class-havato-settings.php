<?php
/**
 * Central settings registry (defaults + typed getters).
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Options wrapper.
 */
class Havato_Settings {

	const OPTION = 'havato_settings';

	/**
	 * Cached settings.
	 *
	 * @var array|null
	 */
	private static $cache = null;

	/**
	 * Register the option so it can be autoloaded.
	 */
	public static function init() {
		add_action( 'admin_init', array( __CLASS__, 'install_defaults' ) );
	}

	/**
	 * Default values for every setting.
	 *
	 * @return array
	 */
	public static function defaults() {
		return array(
			// Matching formula (section 7).
			'w_age_penalty'        => 3,     // Points removed per year above the 5-year gap.
			'w_age_threshold'      => 5,     // Free age gap.
			'w_intro_extro'        => 10,    // Introvert x extrovert bonus.
			'w_ambivert'           => 15,    // Two balanced ambiverts.
			'w_speaker_listener'   => 20,    // Speaker (7+) x listener (4-).
			'w_two_talkers'        => -15,   // Two talkative people.
			'w_two_quiet'          => -15,   // Two quiet people.
			'w_shared_interest'    => 10,    // Per shared interest.
			'w_same_vibe'          => 15,    // Same conversation vibe.
			'w_opposite_vibe'      => -10,   // Opposite vibe.
			'w_rating'             => 8,     // Weight of the behaviour-score term.

			// Traits from the longer personality test. Kept small on purpose:
			// they refine the ordering the criteria above establish rather
			// than competing with them.
			'w_trait_humor'        => 6,     // Similar sense of humour.
			'w_trait_energy'       => 6,     // Similar preferred atmosphere.
			'w_trait_empathy'      => 5,     // At least one strong listener present.

			'w_gender_balance'     => 20,    // Weight of the soft gender-balance term.
			'gender_balance_on'    => 1,     // Toggle the gender balance criterion.
			'w_location'           => 60,    // Admin sliders (venue proximity).
			'w_time'               => 45,    // Suggested time weight.
			'w_density'            => 30,    // Venue density weight.

			// Cron & lifecycle.
			'cron_lead_hours'      => 2,     // Force matching N hours before the event.
			'auto_complete_hours'  => 3,     // Mark event completed N hours after start.

			// Google sign-in.
			'google_client_id'     => '',
			'google_client_secret' => '',

			// Locale.
			'default_lang'         => 'fa',
			'allow_lang_switch'    => 1,
			'map_center_lat'       => 35.7219,
			'map_center_lng'       => 51.3347,
			'map_zoom'             => 12,

			// Moderation.
			'photo_auto_approve'   => 1,
		);
	}

	/**
	 * Persist defaults for any missing key.
	 */
	public static function install_defaults() {
		$saved   = get_option( self::OPTION, array() );
		$saved   = is_array( $saved ) ? $saved : array();
		$merged  = array_merge( self::defaults(), $saved );
		if ( $merged !== $saved ) {
			update_option( self::OPTION, $merged );
			self::$cache = $merged;
		}

		if ( ! get_option( 'havato_default_lang' ) ) {
			update_option( 'havato_default_lang', $merged['default_lang'] );
		}
	}

	/**
	 * All settings.
	 *
	 * @return array
	 */
	public static function all() {
		if ( null === self::$cache ) {
			$saved       = get_option( self::OPTION, array() );
			self::$cache = array_merge( self::defaults(), is_array( $saved ) ? $saved : array() );
		}
		return self::$cache;
	}

	/**
	 * Read one setting.
	 *
	 * @param string $key     Key.
	 * @param mixed  $default Fallback.
	 * @return mixed
	 */
	public static function get( $key, $default = null ) {
		$all = self::all();
		if ( array_key_exists( $key, $all ) ) {
			return $all[ $key ];
		}
		return $default;
	}

	/**
	 * Write settings (partial update).
	 *
	 * @param array $values Key => value pairs.
	 * @return array Updated settings.
	 */
	public static function update( array $values ) {
		$all = self::all();
		foreach ( $values as $key => $value ) {
			if ( ! array_key_exists( $key, self::defaults() ) ) {
				continue;
			}
			$all[ $key ] = self::sanitize( $key, $value );
		}
		update_option( self::OPTION, $all );
		self::$cache = $all;

		if ( isset( $values['default_lang'] ) ) {
			update_option( 'havato_default_lang', $all['default_lang'] );
		}

		return $all;
	}

	/**
	 * Type-aware sanitizer.
	 *
	 * @param string $key   Setting key.
	 * @param mixed  $value Raw value.
	 * @return mixed
	 */
	private static function sanitize( $key, $value ) {
		switch ( $key ) {
			case 'google_client_id':
			case 'google_client_secret':
				return sanitize_text_field( (string) $value );
			case 'default_lang':
				return Havato_I18N::sanitize_lang( $value );
			case 'map_center_lat':
			case 'map_center_lng':
				return (float) $value;
			default:
				// Everything else is an integer weight / toggle / amount.
				return (int) $value;
		}
	}
}
