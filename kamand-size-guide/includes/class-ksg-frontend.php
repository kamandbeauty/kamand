<?php
/**
 * نمایش جدول راهنمای سایز در صفحهٔ محصول و بارگذاری استایل/اسکریپت.
 *
 * @package KamandSizeGuide
 */

defined( 'ABSPATH' ) || exit;

/**
 * بخش نمایش فروشگاه.
 */
class KSG_Frontend {

	/**
	 * نسخهٔ یکتا.
	 *
	 * @var KSG_Frontend|null
	 */
	private static $instance = null;

	/**
	 * راهنمای آمادهٔ محصول جاری (کش درون‌درخواستی).
	 *
	 * @var array|null
	 */
	private $cached = null;

	/**
	 * دریافت نسخهٔ یکتا.
	 *
	 * @return KSG_Frontend
	 */
	public static function instance() {
		if ( null === self::$instance ) {
			self::$instance = new self();
		}

		return self::$instance;
	}

	/**
	 * ثبت هوک‌ها.
	 */
	private function __construct() {
		add_action( 'wp_enqueue_scripts', array( $this, 'maybe_enqueue' ), 20 );

		$location = self::display_location();

		add_action( $location['hook'], array( $this, 'render_for_current_product' ), $location['priority'] );
	}

	/**
	 * هوک و اولویت محل نمایش.
	 *
	 * @return array{hook:string,priority:int}
	 */
	public static function display_location() {
		$map = array(
			'after_add_to_cart' => array(
				'hook'     => 'woocommerce_after_add_to_cart_form',
				'priority' => 10,
			),
			'after_summary'     => array(
				'hook'     => 'woocommerce_after_single_product_summary',
				'priority' => 8,
			),
			'after_tabs'        => array(
				'hook'     => 'woocommerce_after_single_product_summary',
				'priority' => 25,
			),
		);

		$selected = (string) KSG_Settings::value( 'display_location' );

		return isset( $map[ $selected ] ) ? $map[ $selected ] : $map['after_add_to_cart'];
	}

	/**
	 * راهنمای محصول جاری را یک‌بار محاسبه و کش می‌کند.
	 *
	 * @return array
	 */
	private function current_guides() {
		if ( null === $this->cached ) {
			$product_id    = get_the_ID();
			$this->cached  = $product_id ? KSG_Products::resolve_guides( $product_id ) : array();
		}

		return $this->cached;
	}

	/**
	 * بارگذاری دارایی‌ها فقط در صورت نیاز.
	 *
	 * @return void
	 */
	public function maybe_enqueue() {
		if ( ! function_exists( 'is_product' ) || ! is_product() ) {
			return;
		}

		$guides = $this->current_guides();

		if ( array() === $guides ) {
			return;
		}

		$settings = KSG_Settings::all();

		wp_register_style( 'ksg-frontend', KSG_PLUGIN_URL . 'assets/css/frontend.css', array(), KSG_VERSION );
		wp_enqueue_style( 'ksg-frontend' );

		wp_add_inline_style(
			'ksg-frontend',
			sprintf(
				'.ksg{--ksg-accent:%1$s;--ksg-accent-strong:%2$s;--ksg-accent-soft:%3$s;--ksg-accent-line:%4$s;--ksg-radius:%5$dpx;}',
				esc_attr( $settings['accent_color'] ),
				esc_attr( self::darken( $settings['accent_color'], 18 ) ),
				esc_attr( self::rgba( $settings['accent_color'], 0.09 ) ),
				esc_attr( self::rgba( $settings['accent_color'], 0.32 ) ),
				absint( $settings['radius'] )
			)
		);

		wp_register_script( 'ksg-frontend', KSG_PLUGIN_URL . 'assets/js/frontend.js', array(), KSG_VERSION, true );
		wp_localize_script(
			'ksg-frontend',
			'ksgFrontend',
			array(
				'persianDigits' => (bool) $settings['persian_digits'],
				'cmLabel'       => __( 'سانتی‌متر', 'kamand-size-guide' ),
				'inchLabel'     => __( 'اینچ', 'kamand-size-guide' ),
				'closeLabel'    => __( 'بستن', 'kamand-size-guide' ),
				'expandLabel'   => __( 'نمایش بزرگ‌تر', 'kamand-size-guide' ),
				'collapseLabel' => __( 'بازگشت به صفحه', 'kamand-size-guide' ),
				'sizeHint'      => __( 'سایز انتخاب‌شدهٔ شما', 'kamand-size-guide' ),
			)
		);
		wp_enqueue_script( 'ksg-frontend' );
	}

	/**
	 * خروجی چاپ جدول برای محصول جاری.
	 *
	 * @return void
	 */
	public function render_for_current_product() {
		if ( ! is_singular( 'product' ) ) {
			return;
		}

		$guides = $this->current_guides();

		if ( array() === $guides ) {
			return;
		}

		echo self::get_html( $guides, array( 'product_id' => get_the_ID() ) ); // phpcs:ignore WordPress.Security.EscapeOutput -- خروجی کامل escape شده است.
	}

	/**
	 * ساخت HTML کامل بخش راهنمای سایز.
	 *
	 * @param array $guides فهرست راهنماها.
	 * @param array $args   آرگومان‌های اختیاری.
	 * @return string
	 */
	public static function get_html( $guides, $args = array() ) {
		$guides = array_values(
			array_filter(
				(array) $guides,
				static function ( $guide ) {
					return isset( $guide['table'] ) && KSG_Guides::table_is_valid( $guide['table'] );
				}
			)
		);

		if ( array() === $guides ) {
			return '';
		}

		$settings     = KSG_Settings::all();
		$product_id   = isset( $args['product_id'] ) ? absint( $args['product_id'] ) : 0;
		$block_id     = 'ksg-' . ( $product_id ? $product_id : wp_rand( 1000, 9999 ) );
		$show_units   = (bool) $settings['show_unit_toggle'];
		$allow_expand = (bool) $settings['allow_expand'];
		$title        = isset( $args['title'] ) && '' !== $args['title'] ? $args['title'] : $settings['title'];
		$has_variants = self::product_has_size_variations( $product_id );

		$default_unit = 'cm';
		foreach ( $guides as $guide ) {
			$default_unit = $guide['table']['unit'];
			break;
		}

		$config = array(
			'blockId'       => $block_id,
			'defaultUnit'   => $default_unit,
			'showUnits'     => $show_units,
			'persianDigits' => (bool) $settings['persian_digits'],
			'matchVariation'=> (bool) $settings['highlight_variation'] && $has_variants,
			'cmLabel'       => __( 'سانتی‌متر', 'kamand-size-guide' ),
			'inchLabel'     => __( 'اینچ', 'kamand-size-guide' ),
		);

		ob_start();
		?>
		<div class="ksg" id="<?php echo esc_attr( $block_id ); ?>" data-ksg="<?php echo esc_attr( wp_json_encode( $config ) ); ?>">
			<div class="ksg__inner">
				<header class="ksg__head">
					<div class="ksg__heading">
						<span class="ksg__badge" aria-hidden="true">
							<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8h18v8H3z"/><path d="M7 8v3M11 8v4M15 8v3M19 8v4"/></svg>
						</span>
						<span class="ksg__titles">
							<span class="ksg__title"><?php echo esc_html( $title ); ?></span>
							<?php if ( ! empty( $settings['subtitle'] ) ) : ?>
								<span class="ksg__subtitle"><?php echo esc_html( $settings['subtitle'] ); ?></span>
							<?php endif; ?>
						</span>
					</div>

					<div class="ksg__tools">
						<?php if ( $show_units ) : ?>
							<div class="ksg__switch" role="group" aria-label="<?php esc_attr_e( 'واحد اندازه‌گیری', 'kamand-size-guide' ); ?>">
								<button type="button" class="ksg__switch-btn is-on" data-ksg-unit="cm"><?php esc_html_e( 'سانتی‌متر', 'kamand-size-guide' ); ?></button>
								<button type="button" class="ksg__switch-btn" data-ksg-unit="inch"><?php esc_html_e( 'اینچ', 'kamand-size-guide' ); ?></button>
							</div>
						<?php endif; ?>

						<?php if ( $allow_expand ) : ?>
							<button type="button" class="ksg__expand" data-ksg-expand>
								<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7"/></svg>
								<span><?php esc_html_e( 'نمایش بزرگ‌تر', 'kamand-size-guide' ); ?></span>
							</button>
						<?php endif; ?>
					</div>
				</header>

				<?php if ( count( $guides ) > 1 ) : ?>
					<div class="ksg__tabs" role="tablist" aria-label="<?php esc_attr_e( 'راهنماهای سایز', 'kamand-size-guide' ); ?>">
						<?php foreach ( $guides as $index => $guide ) : ?>
							<button type="button" role="tab" id="<?php echo esc_attr( $block_id . '-tab-' . $index ); ?>" class="ksg__tab<?php echo 0 === $index ? ' is-on' : ''; ?>" aria-selected="<?php echo 0 === $index ? 'true' : 'false'; ?>" aria-controls="<?php echo esc_attr( $block_id . '-panel-' . $index ); ?>" data-ksg-tab="<?php echo (int) $index; ?>">
								<?php echo esc_html( $guide['title'] ); ?>
							</button>
						<?php endforeach; ?>
					</div>
				<?php endif; ?>

				<?php foreach ( $guides as $index => $guide ) : ?>
					<div class="ksg__panel<?php echo 0 === $index ? ' is-on' : ''; ?>" id="<?php echo esc_attr( $block_id . '-panel-' . $index ); ?>" role="tabpanel" <?php echo 0 === $index ? '' : 'hidden'; ?> aria-labelledby="<?php echo esc_attr( $block_id . '-tab-' . $index ); ?>" data-ksg-unit="<?php echo esc_attr( $guide['table']['unit'] ); ?>">
						<div class="ksg__scroller" tabindex="0">
							<?php echo self::render_table( $guide['table'], $guide['title'] ); // phpcs:ignore WordPress.Security.EscapeOutput ?>
						</div>

						<?php echo self::render_extras( $guide['table'], (bool) $settings['show_tips'] ); // phpcs:ignore WordPress.Security.EscapeOutput ?>
					</div>
				<?php endforeach; ?>

				<footer class="ksg__foot">
					<?php if ( $has_variants && $settings['highlight_variation'] ) : ?>
						<span class="ksg__hint" data-ksg-hint hidden>
							<span class="ksg__hint-dot" aria-hidden="true"></span>
							<span class="ksg__hint-text"><?php esc_html_e( 'ردیف برجسته، سایز انتخاب‌شدهٔ شماست.', 'kamand-size-guide' ); ?></span>
						</span>
					<?php endif; ?>

					<?php if ( $settings['show_print'] ) : ?>
						<button type="button" class="ksg__print" data-ksg-print>
							<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9V3h12v6M6 18H4v-6h16v6h-2M8 14h8v7H8z"/></svg>
							<span><?php esc_html_e( 'چاپ راهنما', 'kamand-size-guide' ); ?></span>
						</button>
					<?php endif; ?>
				</footer>
			</div>
		</div>
		<?php

		return (string) ob_get_clean();
	}

	/**
	 * ساخت HTML جدول.
	 *
	 * @param array  $table جدول.
	 * @param string $caption عنوان قابل‌دسترس جدول.
	 * @return string
	 */
	public static function render_table( $table, $caption = '' ) {
		$columns = isset( $table['columns'] ) ? (array) $table['columns'] : array();
		$rows    = isset( $table['rows'] ) ? (array) $table['rows'] : array();

		if ( array() === $columns || array() === $rows ) {
			return '';
		}

		$size_index = null;
		foreach ( $columns as $index => $column ) {
			if ( isset( $column['kind'] ) && 'size' === $column['kind'] ) {
				$size_index = $index;
				break;
			}
		}

		$html  = '<table class="ksg__table">';
		$html .= '<caption class="screen-reader-text">' . esc_html( $caption ? $caption : __( 'راهنمای سایز', 'kamand-size-guide' ) ) . '</caption>';
		$html .= '<thead><tr>';

		foreach ( $columns as $column ) {
			$kind = isset( $column['kind'] ) ? $column['kind'] : 'measure';
			$html .= sprintf(
				'<th scope="col" class="ksg__th ksg__th--%1$s">%2$s%3$s</th>',
				esc_attr( $kind ),
				esc_html( isset( $column['label'] ) ? $column['label'] : '' ),
				'measure' === $kind ? '<span class="ksg__unit-chip" data-ksg-unit-chip></span>' : ''
			);
		}

		$html .= '</tr></thead><tbody>';

		foreach ( $rows as $row ) {
			$values   = isset( $row['values'] ) ? (array) $row['values'] : array();
			$size_raw = '';

			if ( null !== $size_index && isset( $columns[ $size_index ] ) ) {
				$size_key = $columns[ $size_index ]['id'];
				$size_raw = isset( $values[ $size_key ] ) ? (string) $values[ $size_key ] : '';
			}

			$html .= sprintf(
				'<tr class="ksg__row"%s>',
				'' !== $size_raw ? ' data-ksg-size="' . esc_attr( self::normalize_size( $size_raw ) ) . '"' : ''
			);

			foreach ( $columns as $column ) {
				$key   = isset( $column['id'] ) ? $column['id'] : '';
				$kind  = isset( $column['kind'] ) ? $column['kind'] : 'measure';
				$value = isset( $values[ $key ] ) ? (string) $values[ $key ] : '';

				if ( $column === reset( $columns ) ) {
					$html .= sprintf(
						'<th scope="row" class="ksg__cell ksg__cell--head ksg__cell--%1$s">%2$s</th>',
						esc_attr( $kind ),
						esc_html( $value )
					);
					continue;
				}

				$raw = 'measure' === $kind ? self::latin_digits( $value ) : '';
				$has_numbers = 'measure' === $kind && 1 === preg_match( '/\d/', $raw );

				$html .= sprintf(
					'<td class="ksg__cell ksg__cell--%1$s"%2$s>%3$s</td>',
					esc_attr( $kind ),
					$has_numbers ? ' data-ksg-kind="measure" data-ksg-raw="' . esc_attr( $raw ) . '"' : '',
					esc_html( $value )
				);
			}

			$html .= '</tr>';
		}

		$html .= '</tbody></table>';

		return $html;
	}

	/**
	 * ساخت HTML تصویر، نکته‌ها و توضیح زیر جدول.
	 *
	 * @param array $table    جدول.
	 * @param bool  $show_tips آیا نکته‌ها نمایش داده شوند.
	 * @return string
	 */
	public static function render_extras( $table, $show_tips = true ) {
		$tips  = $show_tips && isset( $table['tips'] ) ? array_filter( (array) $table['tips'] ) : array();
		$note  = isset( $table['note'] ) ? trim( (string) $table['note'] ) : '';
		$image = isset( $table['image'] ) ? absint( $table['image'] ) : 0;

		if ( array() === $tips && '' === $note && ! $image ) {
			return '';
		}

		$html = '<div class="ksg__extras">';

		if ( $image ) {
			$image_html = wp_get_attachment_image( $image, 'medium', false, array( 'class' => 'ksg__image', 'loading' => 'lazy' ) );

			if ( $image_html ) {
				$html .= '<figure class="ksg__figure">' . $image_html . '<figcaption>' . esc_html__( 'نحوهٔ اندازه‌گیری', 'kamand-size-guide' ) . '</figcaption></figure>';
			}
		}

		if ( array() !== $tips || '' !== $note ) {
			$html .= '<div class="ksg__notes">';

			if ( array() !== $tips ) {
				$html .= '<ul class="ksg__tips">';
				foreach ( $tips as $tip ) {
					$html .= '<li>' . esc_html( $tip ) . '</li>';
				}
				$html .= '</ul>';
			}

			if ( '' !== $note ) {
				$html .= '<p class="ksg__note">' . esc_html( $note ) . '</p>';
			}

			$html .= '</div>';
		}

		$html .= '</div>';

		return $html;
	}

	/**
	 * تبدیل ارقام فارسی/عربی به لاتین.
	 *
	 * @param string $value مقدار ورودی.
	 * @return string
	 */
	public static function latin_digits( $value ) {
		$persian = array( '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹', '٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩' );
		$latin   = array( '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' );

		return str_replace( $persian, $latin, (string) $value );
	}

	/**
	 * نرمال‌سازی برچسب سایز برای مقایسه با مقدار انتخاب‌شده در فرم محصولات متغیر.
	 *
	 * @param string $value برچسب سایز.
	 * @return string
	 */
	public static function normalize_size( $value ) {
		$value = self::latin_digits( $value );
		$value = str_replace( array( 'ي', 'ك', '‌', "\xE2\x80\x8C" ), array( 'ی', 'ک', '', '' ), $value );
		$value = mb_strtolower( trim( $value ) );
		$value = preg_replace( '/\s+/', ' ', $value );

		return (string) $value;
	}

	/**
	 * آیا محصول متغیر است و صفت سایز دارد؟
	 *
	 * @param int $product_id شناسهٔ محصول.
	 * @return bool
	 */
	public static function product_has_size_variations( $product_id ) {
		if ( ! $product_id || ! function_exists( 'wc_get_product' ) ) {
			return false;
		}

		$product = wc_get_product( $product_id );

		if ( ! $product || ! $product->is_type( 'variable' ) ) {
			return false;
		}

		$slugs   = array_filter( array_map( 'trim', explode( ',', strtolower( (string) KSG_Settings::value( 'size_attributes' ) ) ) ) );
		$matches = array( 'size', 'pa_size', 'pa_اندازه', 'pa_سایز', 'اندازه', 'سایز' );
		$slugs   = array_merge( $matches, $slugs );

		foreach ( $product->get_variation_attributes() as $attribute => $terms ) {
			$name = strtolower( str_replace( 'attribute_', '', (string) $attribute ) );

			if ( in_array( $name, $slugs, true ) ) {
				return true;
			}
		}

		return false;
	}

	/**
	 * تبدیل HEX به rgba با شفافیت دلخواه.
	 *
	 * @param string $hex   رنگ HEX.
	 * @param float  $alpha شفافیت (۰ تا ۱).
	 * @return string
	 */
	public static function rgba( $hex, $alpha = 0.1 ) {
		$hex = ltrim( (string) $hex, '#' );

		if ( 3 === strlen( $hex ) ) {
			$hex = $hex[0] . $hex[0] . $hex[1] . $hex[1] . $hex[2] . $hex[2];
		}

		if ( 6 !== strlen( $hex ) || ! ctype_xdigit( $hex ) ) {
			return 'rgba(224, 68, 124, ' . (float) $alpha . ')';
		}

		return sprintf(
			'rgba(%d, %d, %d, %s)',
			hexdec( substr( $hex, 0, 2 ) ),
			hexdec( substr( $hex, 2, 2 ) ),
			hexdec( substr( $hex, 4, 2 ) ),
			rtrim( rtrim( number_format( (float) $alpha, 2, '.', '' ), '0' ), '.' )
		);
	}

	/**
	 * تیره‌تر کردن یک رنگ HEX.
	 *
	 * @param string $hex    رنگ HEX.
	 * @param int    $percent درصد تیرگی.
	 * @return string
	 */
	public static function darken( $hex, $percent = 15 ) {
		$hex = ltrim( (string) $hex, '#' );

		if ( 3 === strlen( $hex ) ) {
			$hex = $hex[0] . $hex[0] . $hex[1] . $hex[1] . $hex[2] . $hex[2];
		}

		if ( 6 !== strlen( $hex ) || ! ctype_xdigit( $hex ) ) {
			return '#c2185b';
		}

		$factor = max( 0, 100 - (int) $percent ) / 100;
		$red    = (int) round( hexdec( substr( $hex, 0, 2 ) ) * $factor );
		$green  = (int) round( hexdec( substr( $hex, 2, 2 ) ) * $factor );
		$blue   = (int) round( hexdec( substr( $hex, 4, 2 ) ) * $factor );

		return sprintf( '#%02x%02x%02x', min( 255, $red ), min( 255, $green ), min( 255, $blue ) );
	}
}
