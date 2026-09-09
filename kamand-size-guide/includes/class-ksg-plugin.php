<?php
/**
 * هستهٔ افزونه: بارگذاری بخش‌ها، ثبت هوک‌ها و بررسی پیش‌نیازها.
 *
 * @package KamandSizeGuide
 */

defined( 'ABSPATH' ) || exit;

/**
 * کلاس اصلی افزونه.
 */
final class KSG_Plugin {

	/**
	 * نسخهٔ یکتای کلاس.
	 *
	 * @var KSG_Plugin|null
	 */
	private static $instance = null;

	/**
	 * دریافت نسخهٔ یکتا (Singleton).
	 *
	 * @return KSG_Plugin
	 */
	public static function instance() {
		if ( null === self::$instance ) {
			self::$instance = new self();
		}

		return self::$instance;
	}

	/**
	 * سازنده: ثبت هوک‌ها.
	 */
	private function __construct() {
		$this->load_textdomain();

		// بخش‌هایی که به ووکامرس نیاز ندارند همیشه فعال‌اند.
		KSG_Guides::instance();
		KSG_Settings::instance();

		if ( ! self::woocommerce_is_active() ) {
			add_action( 'admin_notices', array( __CLASS__, 'woocommerce_missing_notice' ) );

			return;
		}

		KSG_Products::instance();
		KSG_Frontend::instance();
		KSG_Shortcode::instance();
	}

	/**
	 * بارگذاری فایل ترجمه.
	 *
	 * @return void
	 */
	private function load_textdomain() {
		add_action(
			'init',
			static function () {
				load_plugin_textdomain( 'kamand-size-guide', false, dirname( plugin_basename( KSG_PLUGIN_FILE ) ) . '/languages' );
			}
		);
	}

	/**
	 * آیا ووکامرس فعال است؟
	 *
	 * @return bool
	 */
	public static function woocommerce_is_active() {
		return class_exists( 'WooCommerce' ) || did_action( 'woocommerce_loaded' );
	}

	/**
	 * هشدار نبود ووکامرس در پیشخوان.
	 *
	 * @return void
	 */
	public static function woocommerce_missing_notice() {
		if ( ! current_user_can( 'activate_plugins' ) ) {
			return;
		}

		printf(
			'<div class="notice notice-warning"><p>%s</p></div>',
			esc_html__( 'افزونهٔ «راهنمای سایز کمند» برای نمایش جدول زیر دکمهٔ خرید به ووکامرس نیاز دارد. لطفاً ووکامرس را فعال کنید.', 'kamand-size-guide' )
		);
	}

	/**
	 * کارهای زمان فعال‌سازی افزونه.
	 *
	 * @return void
	 */
	public static function activate() {
		KSG_Guides::register_post_type();

		// بازنشانی پیوندهای یکتا برای نوع نوشتهٔ تازه.
		if ( function_exists( 'flush_rewrite_rules' ) ) {
			flush_rewrite_rules();
		}

		KSG_Settings::ensure_defaults();
	}

	/**
	 * کارهای زمان غیرفعال‌سازی افزونه.
	 *
	 * @return void
	 */
	public static function deactivate() {
		if ( function_exists( 'flush_rewrite_rules' ) ) {
			flush_rewrite_rules();
		}
	}

	/**
	 * دسترسی سریع به تنظیمات افزونه.
	 *
	 * @return array
	 */
	public static function settings() {
		return KSG_Settings::all();
	}
}
