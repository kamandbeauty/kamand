<?php
/**
 * آزمون‌های smoke افزونهٔ راهنمای سایز ووکامرس (استودیو جاوید).
 *
 * اجرا: php tests/run-tests.php
 *
 * @package KamandSizeGuide\Tests
 */

define( 'KSG_TESTS', true );

error_reporting( E_ALL );
ini_set( 'display_errors', '1' );

// هر هشدار یا نوتیس در مسیر اجرای افزونه = شکست آزمون.
set_error_handler(
	static function ( $severity, $message, $file, $line ) {
		if ( ! ( error_reporting() & $severity ) ) {
			return false;
		}

		throw new ErrorException( $message, 0, $severity, $file, $line );
	}
);

// خروجی را جمع می‌کنیم تا بتوان هم چاپ کرد و هم در فایل نوشت (--log=PATH).
ob_start();

register_shutdown_function(
	static function () {
		while ( ob_get_level() > 0 ) {
			echo ob_get_clean();
		}
	}
);

require_once __DIR__ . '/bootstrap.php';
require_once dirname( __DIR__ ) . '/kamand-size-guide/kamand-size-guide.php';

$tests   = 0;
$passed  = 0;
$failed  = array();

function assert_true( $condition, $label ) {
	global $tests, $passed, $failed;

	++$tests;

	if ( $condition ) {
		++$passed;
		echo "  ✓ {$label}\n";

		return;
	}

	$failed[] = $label;
	echo "  ✗ {$label}\n";
}

function assert_same( $expected, $actual, $label ) {
	assert_true( $expected === $actual, $label . ( $expected === $actual ? '' : ' (انتظار: ' . var_export( $expected, true ) . ' — دریافت: ' . var_export( $actual, true ) . ')' ) );
}

function assert_contains( $haystack, $needle, $label ) {
	assert_true( false !== strpos( (string) $haystack, $needle ), $label . ( false !== strpos( (string) $haystack, $needle ) ? '' : ' (یافت نشد: ' . $needle . ')' ) );
}

function assert_not_contains( $haystack, $needle, $label ) {
	assert_true( false === strpos( (string) $haystack, $needle ), $label . ( false === strpos( (string) $haystack, $needle ) ? '' : ' (نباید وجود داشت: ' . $needle . ')' ) );
}

function section( $title ) {
	echo "\n{$title}\n";
}

/* ------------------------------------------------------------------ */
section( '۱) بارگذاری افزونه' );

do_action( 'plugins_loaded' );
do_action( 'init' );

assert_true( class_exists( 'KSG_Plugin' ), 'کلاس KSG_Plugin بارگذاری شد' );
assert_true( defined( 'KSG_VERSION' ), 'ثابت KSG_VERSION تعریف شد' );
assert_same( 'ksg_size_guide', KSG_POST_TYPE, 'نام نوع نوشتهٔ راهنما' );
assert_true( isset( $GLOBALS['ksg_test']['post_types']['ksg_size_guide'] ), 'نوع نوشتهٔ راهنمای سایز ثبت شد' );
assert_true( isset( $GLOBALS['ksg_test']['shortcodes']['ksg_size_guide'] ), 'شورت‌کد [ksg_size_guide] ثبت شد' );
assert_true(
	isset( $GLOBALS['ksg_test']['hooks']['actions']['woocommerce_after_add_to_cart_form'] ),
	'هوک woocommerce_after_add_to_cart_form (زیر دکمهٔ خرید) ثبت شد'
);

/* ------------------------------------------------------------------ */
section( '۲) پاک‌سازی دادهٔ جدول' );

$dirty = array(
	'unit'    => 'meter',
	'columns' => array(
		array( 'id' => 'c1', 'label' => '  سایز  ', 'kind' => 'size' ),
		array( 'id' => 'c2', 'label' => '<b>دور سینه</b>', 'kind' => 'unknown' ),
		array( 'id' => 'c3', 'label' => '', 'kind' => 'note' ),
	),
	'rows'    => array(
		array( 'id' => 'r1', 'values' => array( 'c1' => ' M ', 'c2' => '<script>92</script>', 'c3' => '۳۸ ایران' ) ),
		array( 'id' => 'r2', 'values' => array( 'c1' => '', 'c2' => '', 'c3' => '' ) ),
		array( 'values' => array( 'c1' => 'L', 'c2' => '98', 'c3' => '۴۰ ایران' ) ),
		'not-an-array',
	),
	'tips'    => array( 'نکتهٔ اول', '   ', 'نکتهٔ دوم' ),
	'note'    => "تلورانس\nدوخت",
	'image'   => '12abc',
);

$clean = KSG_Guides::sanitize_table( $dirty );

assert_same( 'cm', $clean['unit'], 'واحد نامعتبر به سانتی‌متر تبدیل شد' );
assert_same( 3, count( $clean['columns'] ), 'تعداد ستون‌های پاک‌سازی‌شده' );
assert_same( 'سایز', $clean['columns'][0]['label'], 'عنوان ستون trim شد' );
assert_same( 'دور سینه', $clean['columns'][1]['label'], 'تگ HTML از عنوان ستون حذف شد' );
assert_same( 'measure', $clean['columns'][1]['kind'], 'نوع نامعتبر ستون به measure تبدیل شد' );
assert_same( 'ستون 3', $clean['columns'][2]['label'], 'برای ستون بدون عنوان، عنوان پیش‌فرض ساخته شد' );
assert_same( 2, count( $clean['rows'] ), 'ردیف کاملاً خالی حذف شد' );
assert_same( 'M', $clean['rows'][0]['values'][ $clean['columns'][0]['id'] ], 'مقدار سلول trim شد' );
assert_same( '92', $clean['rows'][0]['values'][ $clean['columns'][1]['id'] ], 'تگ script از سلول حذف شد' );
assert_same( array( 'نکتهٔ اول', 'نکتهٔ دوم' ), $clean['tips'], 'نکته‌های خالی حذف شدند' );
assert_same( 12, $clean['image'], 'شناسهٔ تصویر به عدد صحیح تبدیل شد' );
assert_true( KSG_Guides::table_is_valid( $clean ), 'جدول پاک‌سازی‌شده معتبر است' );

$json_input = wp_json_encode(
	array(
		'unit'    => 'inch',
		'columns' => array( array( 'id' => 'c1', 'label' => 'سایز', 'kind' => 'size' ) ),
		'rows'    => array( array( 'id' => 'r1', 'values' => array( 'c1' => 'M' ) ) ),
	)
);

$from_json = KSG_Guides::sanitize_table( $json_input );
assert_same( 'inch', $from_json['unit'], 'ورودی JSON رشته‌ای درست خوانده شد' );
assert_same( 'M', $from_json['rows'][0]['values']['c1'], 'مقدار ردیف از ورودی JSON' );

$forced = KSG_Guides::sanitize_table(
	array(
		'columns' => array( array( 'id' => 'c1', 'label' => 'دور سینه', 'kind' => 'measure' ) ),
		'rows'    => array( array( 'values' => array( 'c1' => '92' ) ) ),
	)
);
assert_same( 'size', $forced['columns'][0]['kind'], 'در نبود ستون سایز، ستون اول به «سایز» تبدیل شد' );

$empty = KSG_Guides::sanitize_table( 'not-json' );
assert_true( ! KSG_Guides::table_is_valid( $empty ), 'ورودی نامعتبر جدول نامعتبر می‌سازد' );

$duplicate_ids = KSG_Guides::sanitize_table(
	array(
		'columns' => array(
			array( 'id' => 'c1', 'label' => 'سایز', 'kind' => 'size' ),
			array( 'id' => 'c1', 'label' => 'دور کمر', 'kind' => 'measure' ),
		),
		'rows'    => array( array( 'values' => array( 'c1' => 'M', 'c2' => '74' ) ) ),
	)
);
assert_true( $duplicate_ids['columns'][0]['id'] !== $duplicate_ids['columns'][1]['id'], 'شناسهٔ تکراری ستون یکتا شد' );
assert_same( 'M', $duplicate_ids['rows'][0]['values'][ $duplicate_ids['columns'][0]['id'] ], 'مقدار ستون با شناسهٔ اصلی ورودی خوانده شد' );

$list_rows = KSG_Guides::sanitize_table(
	array(
		'columns' => array(
			array( 'id' => 'c1', 'label' => 'سایز', 'kind' => 'size' ),
			array( 'id' => 'c2', 'label' => 'دور سینه', 'kind' => 'measure' ),
		),
		'rows'    => array( array( 'values' => array( 'M', '92' ) ) ),
	)
);
assert_same( 'M', $list_rows['rows'][0]['values']['c1'], 'ردیف با فهرست سادهٔ مقادیر (ورودی CSV) خوانده شد' );
assert_same( '92', $list_rows['rows'][0]['values']['c2'], 'مقدار دوم فهرست ساده در ستون دوم نشست' );

/* ------------------------------------------------------------------ */
section( '۳) تشخیص راهنمای محصول' );

ksg_test_reset();
ksg_test_add_post( 50, 'راهنمای پوشاک' );
ksg_test_add_post( 51, 'راهنمای کفش' );

update_post_meta(
	50,
	KSG_Guides::META_KEY,
	array(
		'unit'    => 'cm',
		'columns' => array(
			array( 'id' => 'c_size', 'label' => 'سایز', 'kind' => 'size' ),
			array( 'id' => 'c_bust', 'label' => 'دور سینه', 'kind' => 'measure' ),
		),
		'rows'    => array(
			array( 'id' => 'r_s', 'values' => array( 'c_size' => 'S', 'c_bust' => '۸۶' ) ),
			array( 'id' => 'r_m', 'values' => array( 'c_size' => 'M', 'c_bust' => '92' ) ),
		),
		'tips'    => array( 'اندازه‌ها بدون لباس ضخیم گرفته شود.' ),
		'note'    => 'تلورانس ۲ سانتی‌متر',
		'image'   => 0,
	)
);

update_post_meta(
	51,
	KSG_Guides::META_KEY,
	array(
		'unit'    => 'cm',
		'columns' => array(
			array( 'id' => 'c_size', 'label' => 'سایز', 'kind' => 'size' ),
			array( 'id' => 'c_len', 'label' => 'طول پا', 'kind' => 'measure' ),
		),
		'rows'    => array( array( 'id' => 'r_42', 'values' => array( 'c_size' => '۴۲', 'c_len' => '26.5' ) ) ),
		'tips'    => array(),
		'note'    => '',
		'image'   => 0,
	)
);

// حالت اختصاصی با دو راهنما (تب‌ها).
update_post_meta( 101, KSG_Products::META_MODE, 'custom' );
update_post_meta( 101, KSG_Products::META_GUIDES, array( 50, 51 ) );

$guides = KSG_Products::resolve_guides( 101 );
assert_same( 2, count( $guides ), 'دو راهنمای اختصاصی محصول پیدا شد' );
assert_same( 'راهنمای پوشاک', $guides[0]['title'], 'عنوان راهنمای اول' );

// حالت none.
update_post_meta( 102, KSG_Products::META_MODE, 'none' );
assert_same( array(), KSG_Products::resolve_guides( 102 ), 'محصول بدون راهنما هیچ خروجی ندارد' );

// جدول اختصاصی درون‌خطی وقتی راهنمای آماده انتخاب نشده.
update_post_meta( 103, KSG_Products::META_MODE, 'custom' );
update_post_meta( 103, KSG_Products::META_GUIDES, array() );
update_post_meta(
	103,
	KSG_Products::META_INLINE,
	array(
		'unit'    => 'cm',
		'columns' => array( array( 'id' => 'c1', 'label' => 'سایز', 'kind' => 'size' ) ),
		'rows'    => array( array( 'id' => 'r1', 'values' => array( 'c1' => 'Free' ) ) ),
	)
);
$inline = KSG_Products::resolve_guides( 103 );
assert_same( 1, count( $inline ), 'جدول اختصاصی محصول به‌عنوان راهنما برگردانده شد' );
assert_same( 0, $inline[0]['id'], 'راهنمای درون‌خطی شناسه ندارد' );

// ارث‌بری از دسته‌بندی.
ksg_test_add_term( 7, 'پوشاک زنانه', 0 );
ksg_test_add_term( 8, 'مانتو', 7 );
update_term_meta( 8, KSG_Products::TERM_META_KEY, 51 );
$GLOBALS['ksg_test']['term_of_post'][104] = array( 8 );

update_post_meta( 104, KSG_Products::META_MODE, 'inherit' );
$from_category = KSG_Products::resolve_guides( 104 );
assert_same( 1, count( $from_category ), 'راهنمای دسته‌بندی برای محصول پیدا شد' );
assert_same( 'راهنمای کفش', $from_category[0]['title'], 'عنوان راهنمای ارث‌بری‌شده از دسته' );

// ارث‌بری از پیش‌فرض فروشگاه وقتی دسته راهنما ندارد.
$GLOBALS['ksg_test']['term_of_post'][105] = array();
update_post_meta( 105, KSG_Products::META_MODE, 'inherit' );
$GLOBALS['ksg_test']['options']['ksg_settings'] = array( 'default_guide_id' => 50 );

// کش تنظیمات باید بازنشانی شود.
$reflection = new ReflectionClass( 'KSG_Settings' );
$cache      = $reflection->getProperty( 'cache' );
$cache->setAccessible( true );
$cache->setValue( null, null );

$from_global = KSG_Products::resolve_guides( 105 );
assert_same( 'راهنمای پوشاک', $from_global[0]['title'], 'راهنمای پیش‌فرض فروشگاه اعمال شد' );

/* ------------------------------------------------------------------ */
section( '۴) خروجی HTML زیر دکمهٔ خرید' );

ksg_test_reset();
ksg_test_add_post( 60, 'راهنمای پوشاک' );
update_post_meta(
	60,
	KSG_Guides::META_KEY,
	array(
		'unit'    => 'cm',
		'columns' => array(
			array( 'id' => 'c_size', 'label' => 'سایز', 'kind' => 'size' ),
			array( 'id' => 'c_bust', 'label' => 'دور سینه', 'kind' => 'measure' ),
			array( 'id' => 'c_note', 'label' => 'مناسب برای', 'kind' => 'note' ),
		),
		'rows'    => array(
			array( 'id' => 'r_s', 'values' => array( 'c_size' => 'S', 'c_bust' => '۸۶', 'c_note' => '۳۶ ایران' ) ),
			array( 'id' => 'r_m', 'values' => array( 'c_size' => 'M', 'c_bust' => '92', 'c_note' => '۳۸ ایران' ) ),
		),
		'tips'    => array( 'اندازه‌ها بدون لباس ضخیم گرفته شود.' ),
		'note'    => 'تلورانس ۲ سانتی‌متر',
		'image'   => 77,
	)
);

ksg_test_add_post( 61, 'راهنمای کفش' );
update_post_meta(
	61,
	KSG_Guides::META_KEY,
	array(
		'unit'    => 'cm',
		'columns' => array(
			array( 'id' => 'c_size', 'label' => 'سایز', 'kind' => 'size' ),
			array( 'id' => 'c_len', 'label' => 'طول پا', 'kind' => 'measure' ),
		),
		'rows'    => array( array( 'id' => 'r_42', 'values' => array( 'c_size' => '۴۲', 'c_len' => '26.5' ) ) ),
	)
);

update_post_meta( 101, KSG_Products::META_MODE, 'custom' );
update_post_meta( 101, KSG_Products::META_GUIDES, array( 60, 61 ) );

ksg_test_set_product( new KSG_Test_Product( 'variable', array( 'attribute_pa_size' => array( 's', 'm' ) ) ) );

KSG_Frontend::instance()->maybe_enqueue();

assert_same( 'enqueued', $GLOBALS['ksg_test']['hooks']['enqueued']['ksg-frontend'], 'استایل و اسکریپت فروشگاه بارگذاری شد' );
assert_true( isset( $GLOBALS['ksg_test']['hooks']['localized']['ksg-frontend'] ), 'دادهٔ اسکریپت (ksgFrontend) تزریق شد' );
assert_contains( $GLOBALS['ksg_test']['hooks']['inline']['ksg-frontend'], '--ksg-accent:#e0447c', 'رنگ اصلی در استایل درون‌خطی نشست' );
assert_contains( $GLOBALS['ksg_test']['hooks']['inline']['ksg-frontend'], '--ksg-accent-soft:rgba(224, 68, 124, 0.09)', 'متغیر نرم رنگ ساخته شد' );

ob_start();
do_action( 'woocommerce_after_add_to_cart_form' );
$html = ob_get_clean();

assert_contains( $html, '<div class="ksg"', 'بلوک راهنمای سایز چاپ شد' );
assert_contains( $html, 'id="ksg-101"', 'شناسهٔ بلوک از شناسهٔ محصول ساخته شد' );
assert_contains( $html, '<table class="ksg__table">', 'جدول راهنما ساخته شد' );
assert_contains( $html, '<th scope="col" class="ksg__th ksg__th--size">سایز', 'ستون سایز با scope=col' );
assert_contains( $html, '<th scope="row" class="ksg__cell ksg__cell--head', 'ستون اول ردیف‌ها سرستون ردیفی است' );
assert_contains( $html, 'data-ksg-raw="86"', 'رقم فارسی «۸۶» به رقم لاتین برای تبدیل ذخیره شد' );
assert_contains( $html, 'data-ksg-raw="26.5"', 'مقدار اعشاری برای تبدیل ذخیره شد' );
assert_contains( $html, 'data-ksg-size="42"', 'برچسب سایز فارسی «۴۲» نرمال شد' );
assert_contains( $html, 'data-ksg-size="m"', 'برچسب سایز M کوچک شد' );
assert_contains( $html, 'role="tablist"', 'چون دو راهنما هست، تب ساخته شد' );
assert_contains( $html, 'راهنمای کفش', 'عنوان راهنمای دوم در تب آمد' );
assert_contains( $html, 'data-ksg-expand', 'دکمهٔ نمایش بزرگ‌تر وجود دارد' );
assert_contains( $html, 'ksg__switch-btn', 'کلید تبدیل سانتی‌متر/اینچ وجود دارد' );
assert_contains( $html, 'img-77.jpg', 'تصویر راهنما نمایش داده شد' );
assert_contains( $html, 'اندازه‌ها بدون لباس ضخیم گرفته شود.', 'نکتهٔ اندازه‌گیری نمایش داده شد' );
assert_contains( $html, 'data-ksg-hint', 'راهنمای برجسته‌سازی سایز انتخاب‌شده هست' );
assert_contains( $html, 'class="ksg__credit">از استودیو جاوید', 'امضای استودیو جاوید زیر جدول چاپ شد' );

// خاموش‌کردن امضا از تنظیمات.
$GLOBALS['ksg_test']['options']['ksg_settings'] = array( 'show_credit' => 0 );
$settings_cache = ( new ReflectionClass( 'KSG_Settings' ) )->getProperty( 'cache' );
$settings_cache->setAccessible( true );
$settings_cache->setValue( null, null );

$credit_guides  = KSG_Products::resolve_guides( 101 );
$html_no_credit = KSG_Frontend::get_html( $credit_guides, array( 'product_id' => 101 ) );
assert_not_contains( $html_no_credit, 'ksg__credit', 'با خاموش‌کردن گزینه، امضا چاپ نمی‌شود' );
assert_contains( $html_no_credit, '<table class="ksg__table">', 'خود جدول بدون امضا همچنان چاپ می‌شود' );

unset( $GLOBALS['ksg_test']['options']['ksg_settings'] );
$settings_cache->setValue( null, null );
assert_not_contains( $html, '<script', 'بدون اسکریپت درون‌خطی در خروجی جدول' );

// پیکربندی JSON بلوک باید سالم باشد.
preg_match( '/data-ksg="([^"]+)"/', $html, $matches );
$config = json_decode( html_entity_decode( $matches[1], ENT_QUOTES, 'UTF-8' ), true );
assert_true( is_array( $config ), 'پیکربندی data-ksg به JSON سالم تبدیل می‌شود' );
assert_same( true, $config['matchVariation'], 'تطبیق خودکار سایز برای محصول متغیر فعال است' );
assert_same( 'cm', $config['defaultUnit'], 'واحد پیش‌فرض بلوک' );

// محصول بدون راهنما نباید چیزی چاپ کند.
update_post_meta( 101, KSG_Products::META_MODE, 'none' );
$reflection_frontend = new ReflectionClass( 'KSG_Frontend' );
$cached_prop         = $reflection_frontend->getProperty( 'cached' );
$cached_prop->setAccessible( true );
$cached_prop->setValue( KSG_Frontend::instance(), null );

ob_start();
do_action( 'woocommerce_after_add_to_cart_form' );
$empty_html = ob_get_clean();
assert_same( '', $empty_html, 'محصول بدون راهنما خروجی چاپ نمی‌کند' );

/* ------------------------------------------------------------------ */
section( '۵) توابع کمکی' );

assert_same( '46', KSG_Frontend::latin_digits( '۴۶' ), 'تبدیل رقم فارسی به لاتین' );
assert_same( 'm', KSG_Frontend::normalize_size( ' M ' ), 'نرمال‌سازی برچسب سایز لاتین' );
assert_same( 'سایز 42', KSG_Frontend::normalize_size( ' سایز  ۴۲ ' ), 'نرمال‌سازی برچسب سایز فارسی (رقم و فاصله)' );
assert_same( '42', KSG_Frontend::normalize_size( '۴۲' ), 'تبدیل رقم سایز فارسی برای تطبیق با فرم' );
assert_same( '#b33663', KSG_Frontend::darken( '#e0447c', 20 ), 'تیره‌کردن رنگ اصلی' );
assert_same( 'rgba(224, 68, 124, 0.5)', KSG_Frontend::rgba( '#e0447c', 0.5 ), 'ساخت rgba از HEX' );
assert_same( 'rgba(224, 68, 124, 0.1)', KSG_Frontend::rgba( 'zzz', 0.1 ), 'رنگ نامعتبر به مقدار امن برمی‌گردد' );
assert_true( KSG_Frontend::product_has_size_variations( 101 ), 'محصول متغیر با صفت سایز تشخیص داده شد' );
assert_same( 'woocommerce_after_add_to_cart_form', KSG_Frontend::display_location()['hook'], 'هوک پیش‌فرض محل نمایش (زیر دکمهٔ خرید)' );
assert_same( 10, KSG_Frontend::display_location()['priority'], 'اولویت هوک پیش‌فرض' );

/* ------------------------------------------------------------------ */
section( '۶) شورت‌کد' );

// محصول نمونه دوباره به حالت اختصاصی برگردانده می‌شود (در بخش قبل none شده بود).
update_post_meta( 101, KSG_Products::META_MODE, 'custom' );
update_post_meta( 101, KSG_Products::META_GUIDES, array( 60, 61 ) );

$html_shortcode = ksg_do_shortcode( 'ksg_size_guide', array( 'guide' => 60 ) );
assert_contains( $html_shortcode, '<table class="ksg__table">', 'شورت‌کد با شناسهٔ راهنما جدول چاپ می‌کند' );

$html_shortcode_product = ksg_do_shortcode( 'ksg_size_guide', array( 'product' => 101 ) );
assert_contains( $html_shortcode_product, '<div class="ksg"', 'شورت‌کد با شناسهٔ محصول جدول چاپ می‌کند' );

$html_shortcode_empty = ksg_do_shortcode( 'ksg_size_guide', array( 'guide' => 9999 ) );
assert_same( '', $html_shortcode_empty, 'شورت‌کد با راهنمای نامعتبر خالی است' );

/* ------------------------------------------------------------------ */
section( '۷) صفحهٔ تنظیمات پیشخوان' );

$settings_html = '';
ob_start();
KSG_Settings::instance()->render_page();
$settings_html = ob_get_clean();

assert_contains( $settings_html, 'ksg_settings[title]', 'فیلد عنوان در صفحهٔ تنظیمات' );
assert_contains( $settings_html, 'ksg_settings[display_location]', 'فیلد محل نمایش در صفحهٔ تنظیمات' );
assert_contains( $settings_html, 'ksg_create_sample', 'دکمهٔ ساخت راهنمای نمونه' );

$sanitized = KSG_Settings::sanitize(
	array(
		'title'            => '  راهنمای ما  ',
		'accent_color'     => 'red',
		'radius'           => 999,
		'display_location' => 'nowhere',
		'size_attributes'  => 'Size, pa_size , ,size',
		'default_guide_id' => 60,
		'show_print'       => '1',
	)
);

assert_same( 'راهنمای ما', $sanitized['title'], 'عنوان تنظیمات trim شد' );
assert_same( '#e0447c', $sanitized['accent_color'], 'رنگ نامعتبر به پیش‌فرض برگشت' );
assert_same( 40, $sanitized['radius'], 'گردی گوشه‌ها محدود شد' );
assert_same( 'after_add_to_cart', $sanitized['display_location'], 'محل نمایش نامعتبر به پیش‌فرض برگشت' );
assert_same( 'size,pa_size', $sanitized['size_attributes'], 'فهرست صفت سایز یکتا و تمیز شد' );
assert_same( 60, $sanitized['default_guide_id'], 'راهنمای پیش‌فرض معتبر پذیرفته شد' );
assert_same( 1, $sanitized['show_print'], 'کلید نمایش فعال ماند' );
assert_same( 0, $sanitized['show_tips'], 'کلیدهای بدون تیک خاموش شدند' );

/* ------------------------------------------------------------------ */
section( '۸) متاباکس محصول در پیشخوان' );

ksg_test_add_post( 101, 'مانتو بهاره', 'product' );
update_post_meta( 101, KSG_Products::META_MODE, 'custom' );
update_post_meta( 101, KSG_Products::META_GUIDES, array( 60 ) );

ob_start();
KSG_Products::instance()->render_meta_box( get_post( 101 ) );
$meta_html = ob_get_clean();

assert_contains( $meta_html, 'name="ksg_mode"', 'انتخاب حالت نمایش در متاباکس محصول' );
assert_contains( $meta_html, 'name="ksg_guide_ids[]"', 'فهرست انتخاب راهنماها در متاباکس' );
assert_contains( $meta_html, 'ksg-admin-json', 'فیلد JSON جدول اختصاصی' );
assert_contains( $meta_html, 'ksg_product_nonce', 'نانس امنیتی متاباکس' );

/* ------------------------------------------------------------------ */
echo "\n";
echo str_repeat( '─', 46 ) . "\n";

$exit_code = 0;

if ( array() === $failed ) {
	echo "همهٔ {$passed} بررسی از {$tests} مورد موفق بود ✅\n";
} else {
	$exit_code = 1;
	echo count( $failed ) . " مورد از {$tests} بررسی ناموفق بود ❌\n";
	foreach ( $failed as $label ) {
		echo " - {$label}\n";
	}
}

$log = ob_get_clean();
echo $log;

// نوشتن گزارش در فایل برای محیط‌هایی که خروجی استاندارد در دسترس نیست.
foreach ( array_slice( (array) $argv, 1 ) as $argument ) {
	if ( 0 === strpos( $argument, '--log=' ) ) {
		file_put_contents( substr( $argument, 6 ), $log ); // phpcs:ignore WordPress.WP.AlternativeFunctions
	}
}

exit( $exit_code );
