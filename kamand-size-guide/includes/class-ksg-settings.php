<?php
/**
 * تنظیمات عمومی افزونه و صفحهٔ مدیریت آن.
 *
 * @package KamandSizeGuide
 */

defined( 'ABSPATH' ) || exit;

/**
 * تنظیمات افزونه.
 */
class KSG_Settings {

	const OPTION_KEY = 'ksg_settings';

	/**
	 * نسخهٔ یکتا.
	 *
	 * @var KSG_Settings|null
	 */
	private static $instance = null;

	/**
	 * کش تنظیمات درون‌درخواستی.
	 *
	 * @var array|null
	 */
	private static $cache = null;

	/**
	 * دریافت نسخهٔ یکتا.
	 *
	 * @return KSG_Settings
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
		add_action( 'admin_menu', array( $this, 'register_page' ), 25 );
		add_action( 'admin_init', array( $this, 'register_settings' ) );
		add_action( 'admin_post_ksg_create_sample', array( $this, 'handle_create_sample' ) );
	}

	/**
	 * مقدارهای پیش‌فرض.
	 *
	 * @return array
	 */
	public static function defaults() {
		return array(
			'title'               => __( 'راهنمای سایز', 'kamand-size-guide' ),
			'subtitle'            => __( 'برای انتخاب دقیق‌تر، اندازهٔ بدن خود را با جدول زیر مقایسه کنید.', 'kamand-size-guide' ),
			'accent_color'        => '#e0447c',
			'radius'              => 18,
			'display_location'    => 'after_add_to_cart',
			'show_unit_toggle'    => 1,
			'allow_expand'        => 1,
			'show_tips'           => 1,
			'show_print'          => 1,
			'persian_digits'      => 1,
			'highlight_variation' => 1,
			'auto_category'       => 1,
			'default_guide_id'    => 0,
			'size_attributes'     => 'size,pa_size',
		);
	}

	/**
	 * اطمینان از وجود گزینهٔ تنظیمات در پایگاه‌داده.
	 *
	 * @return void
	 */
	public static function ensure_defaults() {
		if ( false === get_option( self::OPTION_KEY, false ) ) {
			add_option( self::OPTION_KEY, self::defaults(), '', false );
		}
	}

	/**
	 * خواندن همهٔ تنظیمات.
	 *
	 * @return array
	 */
	public static function all() {
		if ( null === self::$cache ) {
			$stored      = get_option( self::OPTION_KEY, array() );
			self::$cache = wp_parse_args( is_array( $stored ) ? $stored : array(), self::defaults() );
		}

		return self::$cache;
	}

	/**
	 * خواندن یک تنظیم.
	 *
	 * @param string $key     کلید تنظیم.
	 * @param mixed  $default مقدار پیش‌فرض اختیاری.
	 * @return mixed
	 */
	public static function value( $key, $default = null ) {
		$settings = self::all();

		return array_key_exists( $key, $settings ) ? $settings[ $key ] : $default;
	}

	/**
	 * پاک‌سازی فرم تنظیمات.
	 *
	 * @param array $input ورودی فرم.
	 * @return array
	 */
	public static function sanitize( $input ) {
		$input    = is_array( $input ) ? $input : array();
		$defaults = self::defaults();
		$clean    = array();

		$clean['title']    = mb_substr( sanitize_text_field( isset( $input['title'] ) ? (string) $input['title'] : '' ), 0, 60 );
		$clean['title']    = '' !== $clean['title'] ? $clean['title'] : $defaults['title'];
		$clean['subtitle'] = mb_substr( sanitize_text_field( isset( $input['subtitle'] ) ? (string) $input['subtitle'] : '' ), 0, 140 );

		$color = isset( $input['accent_color'] ) ? sanitize_hex_color( (string) $input['accent_color'] ) : '';
		$clean['accent_color'] = $color ? $color : $defaults['accent_color'];

		$radius         = isset( $input['radius'] ) ? absint( $input['radius'] ) : $defaults['radius'];
		$clean['radius'] = min( 40, max( 0, $radius ) );

		$location = isset( $input['display_location'] ) ? sanitize_key( (string) $input['display_location'] ) : '';
		$allowed  = array( 'after_add_to_cart', 'after_summary', 'after_tabs' );
		$clean['display_location'] = in_array( $location, $allowed, true ) ? $location : $defaults['display_location'];

		foreach ( array( 'show_unit_toggle', 'allow_expand', 'show_tips', 'show_print', 'persian_digits', 'highlight_variation', 'auto_category' ) as $flag ) {
			$clean[ $flag ] = empty( $input[ $flag ] ) ? 0 : 1;
		}

		$clean['default_guide_id'] = isset( $input['default_guide_id'] ) ? absint( $input['default_guide_id'] ) : 0;

		if ( $clean['default_guide_id'] && KSG_Guides::POST_TYPE !== get_post_type( $clean['default_guide_id'] ) ) {
			$clean['default_guide_id'] = 0;
		}

		$attributes = isset( $input['size_attributes'] ) ? (string) $input['size_attributes'] : '';
		$attributes = array_filter( array_map( 'trim', explode( ',', $attributes ) ) );
		$attributes = array_map(
			static function ( $attribute ) {
				return sanitize_title( $attribute );
			},
			$attributes
		);
		$clean['size_attributes'] = implode( ',', array_slice( array_unique( $attributes ), 0, 10 ) );

		self::$cache = $clean;

		return $clean;
	}

	/**
	 * ثبت صفحهٔ تنظیمات.
	 *
	 * @return void
	 */
	public function register_page() {
		$parent = class_exists( 'WooCommerce' ) ? 'woocommerce' : 'options-general.php';

		add_submenu_page(
			$parent,
			__( 'راهنمای سایز کمند', 'kamand-size-guide' ),
			__( 'راهنمای سایز', 'kamand-size-guide' ),
			'manage_woocommerce',
			'ksg-settings',
			array( $this, 'render_page' )
		);
	}

	/**
	 * ثبت تنظیمات در Settings API.
	 *
	 * @return void
	 */
	public function register_settings() {
		register_setting(
			'ksg_settings_group',
			self::OPTION_KEY,
			array(
				'type'              => 'array',
				'sanitize_callback' => array( __CLASS__, 'sanitize' ),
				'default'           => self::defaults(),
			)
		);
	}

	/**
	 * ساخت راهنمای نمونه از پیشخوان.
	 *
	 * @return void
	 */
	public function handle_create_sample() {
		if ( ! current_user_can( 'manage_woocommerce' ) ) {
			wp_die( esc_html__( 'اجازهٔ انجام این کار را ندارید.', 'kamand-size-guide' ) );
		}

		check_admin_referer( 'ksg_create_sample' );

		$guide_id = KSG_Guides::create_sample();

		wp_safe_redirect(
			add_query_arg(
				array(
					'page'     => 'ksg-settings',
					'ksg-done' => $guide_id ? 'sample' : 'error',
				),
				admin_url( ( class_exists( 'WooCommerce' ) ? 'admin.php' : 'options-general.php' ) )
			)
		);
		exit;
	}

	/**
	 * رندر صفحهٔ تنظیمات.
	 *
	 * @return void
	 */
	public function render_page() {
		if ( ! current_user_can( 'manage_woocommerce' ) ) {
			wp_die( esc_html__( 'اجازهٔ دسترسی ندارید.', 'kamand-size-guide' ) );
		}

		$settings = self::all();
		$choices  = KSG_Guides::get_choices();

		wp_enqueue_style( 'wp-color-picker' );
		wp_enqueue_style( 'ksg-admin', KSG_PLUGIN_URL . 'assets/css/admin.css', array(), KSG_VERSION );
		wp_enqueue_script( 'wp-color-picker' );
		wp_add_inline_script(
			'wp-color-picker',
			"jQuery(function($){ $('.ksg-color').wpColorPicker(); });"
		);

		if ( isset( $_GET['ksg-done'] ) && 'sample' === $_GET['ksg-done'] ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended -- فقط نمایش پیام.
			printf(
				'<div class="notice notice-success is-dismissible"><p>%s</p></div>',
				esc_html__( 'راهنمای نمونه ساخته شد. حالا می‌توانید آن را به‌عنوان راهنمای پیش‌فرض فروشگاه انتخاب کنید یا در محصولات استفاده کنید.', 'kamand-size-guide' )
			);
		}

		$locations = array(
			'after_add_to_cart' => __( 'زیر دکمهٔ «افزودن به سبد خرید» (پیشنهادی)', 'kamand-size-guide' ),
			'after_summary'     => __( 'بالای تب‌های توضیحات محصول', 'kamand-size-guide' ),
			'after_tabs'        => __( 'زیر تب‌های توضیحات محصول', 'kamand-size-guide' ),
		);
		?>
		<div class="wrap ksg-settings">
			<h1 class="wp-heading-inline"><?php esc_html_e( 'تنظیمات راهنمای سایز کمند', 'kamand-size-guide' ); ?></h1>

			<p class="ksg-intro">
				<?php esc_html_e( 'این افزونه جدول راهنمای سایز هر محصول را با ظاهری تمیز و واکنش‌گرا دقیقاً زیر دکمهٔ خرید نمایش می‌دهد. راهنماها را از منوی «راهنمای سایز» بسازید و در این صفحه رفتار نمایش را تنظیم کنید.', 'kamand-size-guide' ); ?>
			</p>

			<form method="post" action="options.php" class="ksg-settings-form">
				<?php settings_fields( 'ksg_settings_group' ); ?>

				<table class="form-table" role="presentation">
					<tbody>
						<tr>
							<th scope="row"><label for="ksg_title"><?php esc_html_e( 'عنوان بخش', 'kamand-size-guide' ); ?></label></th>
							<td><input type="text" id="ksg_title" class="regular-text" name="<?php echo esc_attr( self::OPTION_KEY ); ?>[title]" value="<?php echo esc_attr( $settings['title'] ); ?>" /></td>
						</tr>
						<tr>
							<th scope="row"><label for="ksg_subtitle"><?php esc_html_e( 'زیرعنوان', 'kamand-size-guide' ); ?></label></th>
							<td>
								<input type="text" id="ksg_subtitle" class="large-text" name="<?php echo esc_attr( self::OPTION_KEY ); ?>[subtitle]" value="<?php echo esc_attr( $settings['subtitle'] ); ?>" />
								<p class="description"><?php esc_html_e( 'اگر خالی بگذارید، زیرعنوانی نمایش داده نمی‌شود.', 'kamand-size-guide' ); ?></p>
							</td>
						</tr>
						<tr>
							<th scope="row"><label for="ksg_accent"><?php esc_html_e( 'رنگ اصلی', 'kamand-size-guide' ); ?></label></th>
							<td><input type="text" id="ksg_accent" class="ksg-color" name="<?php echo esc_attr( self::OPTION_KEY ); ?>[accent_color]" value="<?php echo esc_attr( $settings['accent_color'] ); ?>" /></td>
						</tr>
						<tr>
							<th scope="row"><label for="ksg_radius"><?php esc_html_e( 'گردی گوشه‌ها', 'kamand-size-guide' ); ?></label></th>
							<td><input type="number" min="0" max="40" id="ksg_radius" name="<?php echo esc_attr( self::OPTION_KEY ); ?>[radius]" value="<?php echo esc_attr( $settings['radius'] ); ?>" class="small-text" /> px</td>
						</tr>
						<tr>
							<th scope="row"><label for="ksg_location"><?php esc_html_e( 'محل نمایش', 'kamand-size-guide' ); ?></label></th>
							<td>
								<select id="ksg_location" name="<?php echo esc_attr( self::OPTION_KEY ); ?>[display_location]">
									<?php foreach ( $locations as $value => $label ) : ?>
										<option value="<?php echo esc_attr( $value ); ?>" <?php selected( $settings['display_location'], $value ); ?>><?php echo esc_html( $label ); ?></option>
									<?php endforeach; ?>
								</select>
							</td>
						</tr>
						<tr>
							<th scope="row"><label for="ksg_default_guide"><?php esc_html_e( 'راهنمای پیش‌فرض فروشگاه', 'kamand-size-guide' ); ?></label></th>
							<td>
								<select id="ksg_default_guide" name="<?php echo esc_attr( self::OPTION_KEY ); ?>[default_guide_id]">
									<option value="0"><?php esc_html_e( '— بدون پیش‌فرض —', 'kamand-size-guide' ); ?></option>
									<?php foreach ( $choices as $id => $title ) : ?>
										<option value="<?php echo esc_attr( $id ); ?>" <?php selected( (int) $settings['default_guide_id'], (int) $id ); ?>><?php echo esc_html( $title ); ?></option>
									<?php endforeach; ?>
								</select>
								<p class="description"><?php esc_html_e( 'برای محصولاتی که راهنمای اختصاصی ندارند و دسته‌بندی‌شان هم راهنمای پیش‌فرض ندارد.', 'kamand-size-guide' ); ?></p>
							</td>
						</tr>
						<tr>
							<th scope="row"><label for="ksg_size_attributes"><?php esc_html_e( 'شناسهٔ صفت سایز', 'kamand-size-guide' ); ?></label></th>
							<td>
								<input type="text" id="ksg_size_attributes" class="regular-text code" name="<?php echo esc_attr( self::OPTION_KEY ); ?>[size_attributes]" value="<?php echo esc_attr( $settings['size_attributes'] ); ?>" />
								<p class="description"><?php esc_html_e( 'نام صفت‌هایی که «سایز» محصول متغیر هستند، جداشده با کاما. از این صفت برای برجسته‌کردن خودکار ردیف مناسب استفاده می‌شود.', 'kamand-size-guide' ); ?></p>
							</td>
						</tr>
						<tr>
							<th scope="row"><?php esc_html_e( 'گزینه‌های نمایش', 'kamand-size-guide' ); ?></th>
							<td>
								<?php
								$flags = array(
									'show_unit_toggle'    => __( 'نمایش کلید تبدیل سانتی‌متر/اینچ', 'kamand-size-guide' ),
									'allow_expand'        => __( 'دکمهٔ «نمایش بزرگ‌تر» و پنجرهٔ تمام‌صفحه', 'kamand-size-guide' ),
									'show_tips'           => __( 'نمایش نکته‌های اندازه‌گیری و توضیح راهنما', 'kamand-size-guide' ),
									'show_print'          => __( 'دکمهٔ چاپ راهنما', 'kamand-size-guide' ),
									'persian_digits'      => __( 'نمایش اعداد با رقم فارسی', 'kamand-size-guide' ),
									'highlight_variation' => __( 'برجسته‌کردن خودکار ردیفِ سایز انتخاب‌شده در محصولات متغیر', 'kamand-size-guide' ),
									'auto_category'       => __( 'استفاده از راهنمای پیش‌فرض دسته‌بندی محصول', 'kamand-size-guide' ),
								);

								foreach ( $flags as $key => $label ) {
									printf(
										'<label class="ksg-radio"><input type="checkbox" name="%1$s[%2$s]" value="1" %3$s /> <span>%4$s</span></label><br />',
										esc_attr( self::OPTION_KEY ),
										esc_attr( $key ),
										checked( (int) $settings[ $key ], 1, false ),
										esc_html( $label )
									);
								}
								?>
							</td>
						</tr>
					</tbody>
				</table>

				<?php submit_button( __( 'ذخیرهٔ تنظیمات', 'kamand-size-guide' ) ); ?>
			</form>

			<div class="ksg-card">
				<h2><?php esc_html_e( 'راهنمای نمونه', 'kamand-size-guide' ); ?></h2>
				<p><?php esc_html_e( 'برای دیدن سریع نتیجه، یک راهنمای سایز نمونه با اندازه‌های پوشاک بسازید و سپس آن را به‌عنوان پیش‌فرض فروشگاه انتخاب کنید.', 'kamand-size-guide' ); ?></p>
				<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
					<?php wp_nonce_field( 'ksg_create_sample' ); ?>
					<input type="hidden" name="action" value="ksg_create_sample" />
					<?php submit_button( __( 'ساخت راهنمای نمونه', 'kamand-size-guide' ), 'secondary', 'submit', false ); ?>
				</form>
			</div>
		</div>
		<?php
	}
}
