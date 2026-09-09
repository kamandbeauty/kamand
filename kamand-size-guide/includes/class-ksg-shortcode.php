<?php
/**
 * شورت‌کد نمایش راهنمای سایز در هر جای محتوا.
 *
 * @package KamandSizeGuide
 */

defined( 'ABSPATH' ) || exit;

/**
 * شورت‌کد [ksg_size_guide].
 */
class KSG_Shortcode {

	/**
	 * نسخهٔ یکتا.
	 *
	 * @var KSG_Shortcode|null
	 */
	private static $instance = null;

	/**
	 * دریافت نسخهٔ یکتا.
	 *
	 * @return KSG_Shortcode
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
		add_shortcode( 'ksg_size_guide', array( $this, 'render' ) );
	}

	/**
	 * خروجی شورت‌کد.
	 *
	 * مثال‌ها:
	 * [ksg_size_guide]
	 * [ksg_size_guide product="123"]
	 * [ksg_size_guide guide="45" title="راهنمای سایز کفش"]
	 *
	 * @param array $atts ویژگی‌های شورت‌کد.
	 * @return string
	 */
	public function render( $atts ) {
		$atts = shortcode_atts(
			array(
				'product' => 0,
				'guide'   => 0,
				'title'   => '',
			),
			(array) $atts,
			'ksg_size_guide'
		);

		$guides = array();

		// وقتی شناسهٔ راهنما صریحاً داده شده، به راهنمای محصول برنمی‌گردیم.
		if ( ! empty( $atts['guide'] ) ) {
			$guide_id = absint( $atts['guide'] );
			$table    = KSG_Guides::get_table( $guide_id );

			if ( ! KSG_Guides::table_is_valid( $table ) ) {
				return '';
			}

			$guides[] = array(
				'id'    => $guide_id,
				'title' => KSG_Guides::get_title( $guide_id ),
				'table' => $table,
			);
		}

		if ( array() === $guides ) {
			$product_id = ! empty( $atts['product'] ) ? absint( $atts['product'] ) : get_the_ID();
			$guides     = $product_id ? KSG_Products::resolve_guides( $product_id ) : array();
		}

		if ( array() === $guides ) {
			return '';
		}

		// اطمینان از بارگذاری استایل و اسکریپت وقتی شورت‌کد بیرون از صفحهٔ محصول استفاده می‌شود.
		if ( ! wp_style_is( 'ksg-frontend', 'enqueued' ) && ! wp_style_is( 'ksg-frontend', 'done' ) ) {
			wp_register_style( 'ksg-frontend', KSG_PLUGIN_URL . 'assets/css/frontend.css', array(), KSG_VERSION );
			wp_enqueue_style( 'ksg-frontend' );
			wp_register_script( 'ksg-frontend', KSG_PLUGIN_URL . 'assets/js/frontend.js', array(), KSG_VERSION, true );
			wp_enqueue_script( 'ksg-frontend' );
		}

		return KSG_Frontend::get_html(
			$guides,
			array(
				'product_id' => ! empty( $atts['product'] ) ? absint( $atts['product'] ) : 0,
				'title'      => $atts['title'],
			)
		);
	}
}
