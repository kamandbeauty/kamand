<?php
/**
 * Theme registry: the whole app is repainted from one palette.
 *
 * Every colour the web-app uses is already a CSS custom property declared in
 * `#havato-app { --hv-… }`. A theme is therefore nothing more than a set of
 * values for those properties: switching one costs a handful of inline bytes
 * instead of a second stylesheet, and no extra HTTP request.
 *
 * Adding a theme in a future release means appending one entry to
 * `catalogue()` — or, from outside the plugin, hooking the `havato_themes`
 * filter. Both routes go through `normalize()`, so a third-party theme can
 * never produce a broken or unreadable palette.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Palette registry + CSS generator.
 */
class Havato_Themes {

	/**
	 * Option holding the active theme id.
	 */
	const OPTION = 'havato_theme';

	/**
	 * Option holding the custom palette (when the active theme is "custom").
	 */
	const CUSTOM_OPTION = 'havato_theme_custom';

	/**
	 * Fallback theme id.
	 */
	const FALLBACK = 'azure';

	/**
	 * Runtime cache.
	 *
	 * @var array|null
	 */
	private static $cache = null;

	/**
	 * Hooks.
	 */
	public static function init() {
		// Late enough to override the stylesheet, early enough for the app.
		add_action( 'wp_enqueue_scripts', array( __CLASS__, 'inject' ), 20 );
		add_action( 'admin_enqueue_scripts', array( __CLASS__, 'inject_admin' ), 20 );
	}

	/* =====================================================================
	 * Catalogue
	 * ================================================================== */

	/**
	 * Every built-in theme.
	 *
	 * `base` is the mid tone that carries white text — it drives the header,
	 * the bottom nav and every primary button, so it is the one value that
	 * must always clear WCAG AA against white. `accent` is deliberately a
	 * different hue so the FAB reads as a separate action rather than more
	 * of the same colour.
	 *
	 * @return array
	 */
	public static function catalogue() {
		$themes = array(
			'azure' => array(
				'label'      => array( 'fa' => 'آبی اَزور', 'en' => 'Azure Blue' ),
				'note'       => array(
					'fa' => 'آبی خالص و قابل اعتماد؛ نزدیک‌ترین حالت به هویت فعلی بدون رگه‌ی بنفش.',
					'en' => 'A true, trustworthy blue — closest to the current identity, without the violet cast.',
				),
				'light'      => '#2f74f7',
				'base'       => '#1552d8',
				'deep'       => '#0a2a6b',
				'ink'        => '#071b45',
				'accent'     => '#38a3ff',
				'accent_2'   => '#ff7a45',
				'canvas'     => '#eef1fb',
				'text'       => '#16204a',
				'text_soft'  => '#6b74a0',
			),
			'emerald' => array(
				'label'      => array( 'fa' => 'سبز زمردی', 'en' => 'Emerald' ),
				'note'       => array(
					'fa' => 'تازه، آرام و انسانی؛ کاملاً از فضای اپ‌های مالی فاصله می‌گیرد.',
					'en' => 'Fresh, calm and human — steps away from the fintech look entirely.',
				),
				'light'      => '#16b98d',
				'base'       => '#0b7a5e',
				'deep'       => '#053b2d',
				'ink'        => '#03291f',
				'accent'     => '#2fd0a0',
				'accent_2'   => '#f5a524',
				'canvas'     => '#edf7f3',
				'text'       => '#12312a',
				'text_soft'  => '#5f8078',
			),
			'espresso' => array(
				'label'      => array( 'fa' => 'اسپرسو', 'en' => 'Espresso' ),
				'note'       => array(
					'fa' => 'رنگ دانه‌ی قهوه و چوب؛ تنها پالتی که مستقیماً به کافه اشاره می‌کند.',
					'en' => 'Coffee bean and timber — the only palette that points straight at the café.',
				),
				'light'      => '#a3653f',
				'base'       => '#7a4a2e',
				'deep'       => '#31201a',
				'ink'        => '#241310',
				'accent'     => '#e08b4c',
				'accent_2'   => '#12a3a3',
				'canvas'     => '#f7f1ea',
				'text'       => '#33231c',
				'text_soft'  => '#8a7264',
			),
			'midnight' => array(
				'label'      => array( 'fa' => 'نیلی شب و کهربا', 'en' => 'Midnight & Amber' ),
				'note'       => array(
					'fa' => 'سرمه‌ای کم‌اشباع با لهجه‌ی کهربایی؛ بالاترین کنتراست و لوکس‌ترین حالت.',
					'en' => 'A desaturated navy lit by amber — the highest contrast and the most premium feel.',
				),
				'light'      => '#2c477f',
				'base'       => '#1c2f5e',
				'deep'       => '#0d1730',
				'ink'        => '#070d1c',
				'accent'     => '#f0a92b',
				'accent_2'   => '#38bdf8',
				'canvas'     => '#eff1f7',
				'text'       => '#141d33',
				'text_soft'  => '#6a7590',
			),
			'galaxy' => array(
				'label'      => array( 'fa' => 'کهکشان', 'en' => 'Galaxy', 'tr' => 'Galaksi' ),
				'note'       => array(
					'fa' => 'تم تیره‌ی بنفش با حال‌وهوای شب؛ کارت‌ها روشن‌تر از زمینه‌اند و متن‌ها روشن.',
					'en' => 'A deep violet night theme. Cards sit lighter than the page and the text is light.',
					'tr' => 'Derin mor bir gece teması. Kartlar sayfadan açık, yazılar açık renk.',
				),
				// Marked explicitly rather than left to the luminance test, so
				// the intent survives even if the canvas is edited later.
				'dark'       => true,
				'light'      => '#a855f7',
				'base'       => '#7c3aed',
				'deep'       => '#3b1a78',
				'ink'        => '#150a2e',
				'accent'     => '#c084fc',
				'accent_2'   => '#f0a92b',
				'canvas'     => '#0d0620',
				'card'       => '#1b1038',
				'text'       => '#f2edff',
				'text_soft'  => '#a99cc9',
			),
			'raspberry' => array(
				'label'      => array( 'fa' => 'تمشکی', 'en' => 'Raspberry', 'tr' => 'Ahududu' ),
				'note'       => array(
					'fa' => 'سرزنده و اشتهاآور، با لهجه‌ی بنفش؛ الهام‌گرفته از اپ‌های سفارش غذا.',
					'en' => 'Vivid and appetising, lifted by a violet accent — the food-delivery look.',
					'tr' => 'Canlı ve iştah açıcı, mor vurgulu — yemek uygulaması havası.',
				),
				'light'      => '#f0186e',
				'base'       => '#c81355',
				'deep'       => '#6d0a30',
				'ink'        => '#3d0519',
				'accent'     => '#5b4bd6',
				'accent_2'   => '#12b981',
				'canvas'     => '#fdf2f6',
				'text'       => '#3a1226',
				'text_soft'  => '#8d6274',
			),
			'coral' => array(
				'label'      => array( 'fa' => 'مرجانی غروب', 'en' => 'Sunset Coral' ),
				'note'       => array(
					'fa' => 'گرم‌ترین و اجتماعی‌ترین گزینه؛ حس آدم‌ها را منتقل می‌کند نه نرم‌افزار.',
					'en' => 'The warmest, most social option — it reads as people, not software.',
				),
				'light'      => '#f26a76',
				'base'       => '#c53a52',
				'deep'       => '#6b1830',
				'ink'        => '#3d0d1c',
				'accent'     => '#ff9068',
				'accent_2'   => '#17a2a2',
				'canvas'     => '#fdf0f1',
				'text'       => '#3a1622',
				'text_soft'  => '#946b74',
			),
		);

		/**
		 * Register additional themes.
		 *
		 * Anything added here shows up in the admin picker automatically.
		 *
		 * @param array $themes Theme id => definition.
		 */
		$themes = apply_filters( 'havato_themes', $themes );

		return is_array( $themes ) ? $themes : array();
	}

	/**
	 * Ids only.
	 *
	 * @return array
	 */
	public static function ids() {
		return array_keys( self::catalogue() );
	}

	/**
	 * Does a theme exist?
	 *
	 * @param string $id Theme id.
	 * @return bool
	 */
	public static function exists( $id ) {
		return array_key_exists( (string) $id, self::catalogue() );
	}

	/* =====================================================================
	 * Active theme
	 * ================================================================== */

	/**
	 * Currently selected theme id.
	 *
	 * @return string
	 */
	public static function current_id() {
		$id = (string) get_option( self::OPTION, self::FALLBACK );

		if ( 'custom' === $id ) {
			return 'custom';
		}

		// A theme removed by a deactivated add-on must not white-screen the
		// app: fall back rather than emitting empty custom properties.
		return self::exists( $id ) ? $id : self::FALLBACK;
	}

	/**
	 * Palette of the active theme, fully normalised.
	 *
	 * @return array
	 */
	public static function current() {
		if ( null !== self::$cache ) {
			return self::$cache;
		}

		$id = self::current_id();

		if ( 'custom' === $id ) {
			$saved = get_option( self::CUSTOM_OPTION, array() );
			$theme = self::normalize( is_array( $saved ) ? $saved : array() );
		} else {
			$all   = self::catalogue();
			$theme = self::normalize( $all[ $id ] );
		}

		self::$cache = $theme;
		return $theme;
	}

	/**
	 * Store the active theme.
	 *
	 * @param string $id     Theme id, or "custom".
	 * @param array  $custom Palette used when $id is "custom".
	 * @return string The id actually stored.
	 */
	public static function set( $id, array $custom = array() ) {
		$id = sanitize_key( $id );

		if ( 'custom' === $id ) {
			update_option( self::CUSTOM_OPTION, self::normalize( $custom ) );
		} elseif ( ! self::exists( $id ) ) {
			$id = self::FALLBACK;
		}

		update_option( self::OPTION, $id );
		self::$cache = null;

		return $id;
	}

	/* =====================================================================
	 * Normalising & colour maths
	 * ================================================================== */

	/**
	 * Fill in every key, clamp anything malformed.
	 *
	 * A theme arriving from the `havato_themes` filter or from the custom
	 * colour picker only has to supply `base`; everything else is derived, so
	 * a half-filled palette still renders a coherent app.
	 *
	 * @param array $theme Raw definition.
	 * @return array
	 */
	public static function normalize( array $theme ) {
		$base = self::hex( isset( $theme['base'] ) ? $theme['base'] : '', '#1552d8' );

		$out = array(
			'label'     => isset( $theme['label'] ) && is_array( $theme['label'] )
				? $theme['label']
				: array( 'fa' => 'سفارشی', 'en' => 'Custom' ),
			'note'      => isset( $theme['note'] ) && is_array( $theme['note'] )
				? $theme['note']
				: array( 'fa' => '', 'en' => '' ),
			'base'      => $base,
			'light'     => self::hex( isset( $theme['light'] ) ? $theme['light'] : '', self::lighten( $base, 0.18 ) ),
			'deep'      => self::hex( isset( $theme['deep'] ) ? $theme['deep'] : '', self::darken( $base, 0.42 ) ),
			'ink'       => self::hex( isset( $theme['ink'] ) ? $theme['ink'] : '', self::darken( $base, 0.62 ) ),
			'accent'    => self::hex( isset( $theme['accent'] ) ? $theme['accent'] : '', self::lighten( $base, 0.34 ) ),
			'accent_2'  => self::hex( isset( $theme['accent_2'] ) ? $theme['accent_2'] : '', '#f97316' ),
			'canvas'    => self::hex( isset( $theme['canvas'] ) ? $theme['canvas'] : '', self::tint( $base, 0.94 ) ),
			'text'      => self::hex( isset( $theme['text'] ) ? $theme['text'] : '', self::darken( $base, 0.7 ) ),
			'text_soft' => self::hex( isset( $theme['text_soft'] ) ? $theme['text_soft'] : '', self::mix( $base, '#7c8398', 0.7 ) ),
			// A dark palette inverts the surfaces: cards become lighter than
			// the page instead of white, and borders have to become visible.
			// Derived from the canvas rather than declared, so a custom theme
			// built from one colour gets it right without extra fields.
			'dark'      => isset( $theme['dark'] )
				? (bool) $theme['dark']
				: ( self::luminance( self::hex( isset( $theme['canvas'] ) ? $theme['canvas'] : '', '#eef1fb' ) ) < 0.4 ),
			'card'      => isset( $theme['card'] ) ? self::hex( $theme['card'], '' ) : '',
		);

		// Hard guarantee: white body text sits on `base` all over the app
		// (header, nav, primary buttons). If a supplied colour is too light
		// for that, darken it until it clears WCAG AA rather than shipping
		// an unreadable screen.
		$guard = 0;
		while ( self::contrast( '#ffffff', $out['base'] ) < 4.5 && $guard < 24 ) {
			$out['base'] = self::darken( $out['base'], 0.06 );
			$guard++;
		}

		// Keep the ramp ordered even after that correction.
		if ( self::luminance( $out['deep'] ) >= self::luminance( $out['base'] ) ) {
			$out['deep'] = self::darken( $out['base'], 0.4 );
		}
		if ( self::luminance( $out['ink'] ) >= self::luminance( $out['deep'] ) ) {
			$out['ink'] = self::darken( $out['deep'], 0.35 );
		}

		// Card surface. On a light theme this is plain white; on a dark one it
		// has to be LIGHTER than the canvas or every card would disappear into
		// the page. Only computed when the palette did not supply one.
		if ( '' === $out['card'] ) {
			$out['card'] = $out['dark']
				? self::lighten( $out['canvas'], 0.07 )
				: '#ffffff';
		}

		// Body text must clear AA against the surface it actually sits on —
		// the card, not the canvas. A dark theme that inherited a near-black
		// `text` would otherwise be unreadable on its own cards.
		$guard = 0;
		while ( self::contrast( $out['text'], $out['card'] ) < 4.5 && $guard < 24 ) {
			$out['text'] = $out['dark']
				? self::lighten( $out['text'], 0.08 )
				: self::darken( $out['text'], 0.08 );
			$guard++;
		}

		// Secondary text may recede, but 3:1 is the floor for it to stay legible.
		$guard = 0;
		while ( self::contrast( $out['text_soft'], $out['card'] ) < 3 && $guard < 24 ) {
			$out['text_soft'] = $out['dark']
				? self::lighten( $out['text_soft'], 0.08 )
				: self::darken( $out['text_soft'], 0.08 );
			$guard++;
		}

		return $out;
	}

	/**
	 * Validate a hex colour.
	 *
	 * @param string $value    Candidate.
	 * @param string $fallback Used when invalid.
	 * @return string
	 */
	public static function hex( $value, $fallback ) {
		$value = strtolower( trim( (string) $value ) );

		if ( preg_match( '/^#?([0-9a-f]{3})$/', $value, $m ) ) {
			$s = $m[1];
			return '#' . $s[0] . $s[0] . $s[1] . $s[1] . $s[2] . $s[2];
		}
		if ( preg_match( '/^#?([0-9a-f]{6})$/', $value, $m ) ) {
			return '#' . $m[1];
		}
		return $fallback;
	}

	/**
	 * Hex -> array(r,g,b).
	 *
	 * @param string $hex Colour.
	 * @return array
	 */
	private static function rgb( $hex ) {
		$hex = ltrim( self::hex( $hex, '#000000' ), '#' );
		return array(
			hexdec( substr( $hex, 0, 2 ) ),
			hexdec( substr( $hex, 2, 2 ) ),
			hexdec( substr( $hex, 4, 2 ) ),
		);
	}

	/**
	 * array(r,g,b) -> hex.
	 *
	 * @param array $rgb Channels.
	 * @return string
	 */
	private static function to_hex( array $rgb ) {
		$out = '#';
		foreach ( $rgb as $c ) {
			$c    = max( 0, min( 255, (int) round( $c ) ) );
			$out .= str_pad( dechex( $c ), 2, '0', STR_PAD_LEFT );
		}
		return $out;
	}

	/**
	 * Blend two colours.
	 *
	 * @param string $a      First colour.
	 * @param string $b      Second colour.
	 * @param float  $weight How much of $b (0..1).
	 * @return string
	 */
	public static function mix( $a, $b, $weight ) {
		$weight = max( 0, min( 1, (float) $weight ) );
		$ra     = self::rgb( $a );
		$rb     = self::rgb( $b );
		return self::to_hex(
			array(
				$ra[0] + ( $rb[0] - $ra[0] ) * $weight,
				$ra[1] + ( $rb[1] - $ra[1] ) * $weight,
				$ra[2] + ( $rb[2] - $ra[2] ) * $weight,
			)
		);
	}

	/**
	 * Toward white.
	 *
	 * @param string $hex    Colour.
	 * @param float  $amount 0..1.
	 * @return string
	 */
	public static function lighten( $hex, $amount ) {
		return self::mix( $hex, '#ffffff', $amount );
	}

	/**
	 * Toward black.
	 *
	 * @param string $hex    Colour.
	 * @param float  $amount 0..1.
	 * @return string
	 */
	public static function darken( $hex, $amount ) {
		return self::mix( $hex, '#000000', $amount );
	}

	/**
	 * A very pale wash of a colour, for page backgrounds.
	 *
	 * @param string $hex    Colour.
	 * @param float  $amount How close to white (0..1).
	 * @return string
	 */
	public static function tint( $hex, $amount ) {
		return self::mix( $hex, '#ffffff', $amount );
	}

	/**
	 * Relative luminance (WCAG 2.1).
	 *
	 * @param string $hex Colour.
	 * @return float
	 */
	public static function luminance( $hex ) {
		$rgb  = self::rgb( $hex );
		$lin  = array();
		foreach ( $rgb as $c ) {
			$c     = $c / 255;
			$lin[] = $c <= 0.03928 ? $c / 12.92 : pow( ( $c + 0.055 ) / 1.055, 2.4 );
		}
		return 0.2126 * $lin[0] + 0.7152 * $lin[1] + 0.0722 * $lin[2];
	}

	/**
	 * Contrast ratio between two colours (1..21).
	 *
	 * @param string $a First colour.
	 * @param string $b Second colour.
	 * @return float
	 */
	public static function contrast( $a, $b ) {
		$la = self::luminance( $a );
		$lb = self::luminance( $b );
		$hi = max( $la, $lb );
		$lo = min( $la, $lb );
		return ( $hi + 0.05 ) / ( $lo + 0.05 );
	}

	/**
	 * `rgba(r, g, b, a)` string for a hex colour.
	 *
	 * @param string $hex   Colour.
	 * @param float  $alpha Alpha.
	 * @return string
	 */
	private static function rgba( $hex, $alpha ) {
		$rgb = self::rgb( $hex );
		return sprintf( 'rgba(%d, %d, %d, %s)', $rgb[0], $rgb[1], $rgb[2], rtrim( rtrim( number_format( (float) $alpha, 3, '.', '' ), '0' ), '.' ) );
	}

	/* =====================================================================
	 * CSS
	 * ================================================================== */

	/**
	 * Custom-property block for a palette.
	 *
	 * Mirrors the token names already used by havato-app.css, so the
	 * stylesheet needs no per-theme rules at all. The `--hv-indigo*` names are
	 * kept even when the palette is brown or green: renaming them across
	 * ~1800 lines would risk missing one and leaving a stale colour behind.
	 *
	 * @param array $theme Normalised palette.
	 * @return string
	 */
	public static function css( array $theme ) {
		$t = self::normalize( $theme );

		$vars = array(
			'--hv-indigo'      => $t['base'],
			'--hv-indigo-2'    => $t['light'],
			'--hv-indigo-deep' => $t['deep'],
			'--hv-indigo-ink'  => $t['ink'],
			'--hv-blue'        => $t['accent'],
			'--hv-blue-soft'   => self::tint( $t['accent'], 0.9 ),
			'--hv-orange'      => $t['accent_2'],
			'--hv-orange-soft' => self::tint( $t['accent_2'], 0.9 ),
			'--hv-bg'          => $t['canvas'],
			'--hv-card'        => $t['card'],
			// The secondary surface sits between the canvas and the card.
			'--hv-card-2'      => $t['dark']
				? self::lighten( $t['canvas'], 0.12 )
				: self::tint( $t['base'], 0.96 ),
			'--hv-card-danger' => $t['dark']
				? self::mix( $t['card'], '#ff5470', 0.88 )
				: '#fffafa',
			// Invisible on a light theme, a faint glow on a dark one — cards
			// need an edge once they are no longer white on grey.
			'--hv-card-border' => $t['dark'] ? self::rgba( $t['light'], 0.28 ) : 'transparent',
			'--hv-text'        => $t['text'],
			'--hv-text-soft'   => $t['text_soft'],
			'--hv-line'        => $t['dark'] ? self::rgba( $t['light'], 0.22 ) : self::rgba( $t['base'], 0.1 ),
			'--hv-shadow-card' => '0 10px 30px ' . self::rgba( $t['ink'], 0.1 ),
			'--hv-shadow-soft' => '0 4px 16px ' . self::rgba( $t['ink'], 0.08 ),
			'--hv-shadow-fab'  => '0 12px 26px ' . self::rgba( $t['accent'], 0.45 ),
		);

		$out = '';
		foreach ( $vars as $name => $value ) {
			$out .= $name . ':' . $value . ';';
		}

		$css = '#havato-app{' . $out . '}';

		// Surfaces painted with literal gradients rather than tokens.
		$css .= '#havato-app .hv-header-bg,.hv-owner-auth .hv-auth-card{'
			. 'background:linear-gradient(135deg,' . $t['light'] . ' 0%,' . $t['base'] . ' 48%,' . $t['deep'] . ' 100%);}';
		$css .= '#havato-app .hv-profile-head{'
			. 'background:linear-gradient(135deg,' . $t['light'] . ',' . $t['base'] . ' 58%,' . $t['deep'] . ');}';
		$css .= '#havato-app .hv-authwall,.hv-owner-auth{'
			. 'background:linear-gradient(160deg,' . $t['light'] . ' 0%,' . $t['base'] . ' 50%,' . $t['ink'] . ' 100%);}';
		$css .= '#havato-app .hv-msg.is-mine,#havato-app .hv-btn-primary,#havato-app .hv-chip.is-active,'
			. '#havato-app .hv-choice.is-active{'
			. 'background:linear-gradient(120deg,' . $t['light'] . ',' . $t['base'] . ');}';
		$css .= '#havato-app .hv-btn-blue,#havato-app .hv-chat-send,#havato-app .hv-fab{'
			. 'background:linear-gradient(140deg,' . self::lighten( $t['accent'], 0.2 ) . ',' . $t['accent'] . ');}';
		// The bottom nav paints its surface on ::before with a literal
		// gradient (the SVG wave is only kept for its shadow), so it has to be
		// repainted explicitly or the nav would keep the old palette.
		$css .= '#havato-app .hv-bottom-nav::before{'
			. 'background:linear-gradient(135deg,' . self::lighten( $t['base'], 0.08 ) . ' 0%,' . $t['base'] . ' 55%,' . $t['deep'] . ' 100%);'
			. 'box-shadow:0 -8px 22px ' . self::rgba( $t['ink'], 0.26 ) . ';}';
		$css .= '#havato-app .hv-wave{filter:drop-shadow(0 -8px 22px ' . self::rgba( $t['ink'], 0.26 ) . ');}';
		$css .= '#havato-app .hv-wave-1{stop-color:' . self::lighten( $t['base'], 0.08 ) . ';}';
		$css .= '#havato-app .hv-wave-2{stop-color:' . $t['base'] . ';}';
		$css .= '#havato-app .hv-wave-3{stop-color:' . $t['deep'] . ';}';
		$css .= '#havato-app .hv-orb-1{background:radial-gradient(circle at 35% 35%,'
			. self::rgba( $t['accent'], 0.85 ) . ',' . self::rgba( $t['base'], 0.15 ) . ' 70%);}';
		$css .= '#havato-app .hv-orb-2{background:radial-gradient(circle at 60% 40%,'
			. self::rgba( $t['light'], 0.7 ) . ',' . self::rgba( $t['ink'], 0.08 ) . ' 72%);}';

		return $css;
	}

	/**
	 * CSS for the active theme.
	 *
	 * @return string
	 */
	public static function current_css() {
		return self::css( self::current() );
	}

	/**
	 * Attach the palette to the already-enqueued app stylesheet.
	 */
	public static function inject() {
		if ( ! wp_style_is( 'havato-app', 'enqueued' ) && ! wp_style_is( 'havato-app', 'registered' ) ) {
			return;
		}
		wp_add_inline_style( 'havato-app', self::current_css() );
	}

	/**
	 * Same, for the owner panel inside wp-admin.
	 */
	public static function inject_admin() {
		if ( ! wp_style_is( 'havato-admin', 'enqueued' ) && ! wp_style_is( 'havato-admin', 'registered' ) ) {
			return;
		}
		wp_add_inline_style( 'havato-admin', self::current_css() );
	}

	/**
	 * Swatches for the admin picker: the six colours worth showing.
	 *
	 * @param array $theme Palette.
	 * @return array
	 */
	public static function swatches( array $theme ) {
		$t = self::normalize( $theme );
		return array( $t['light'], $t['base'], $t['deep'], $t['accent'], $t['accent_2'], $t['canvas'] );
	}
}
