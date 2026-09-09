<?php
/**
 * ساخت صفحهٔ پیش‌نمایش ظاهری افزونه.
 *
 * این اسکریپت با همان کلاس‌های واقعی افزونه (KSG_Frontend) خروجی HTML را می‌سازد و
 * آن را در پوشهٔ demo/ می‌نویسد تا بدون وردپرس و ووکامرس بتوان ظاهر جدول را دید.
 *
 * اجرا: php tools/generate-demo.php [مسیر خروجی]
 *
 * @package KamandSizeGuide\Tools
 */

defined( 'KSG_DEMO' ) || define( 'KSG_DEMO', true );

error_reporting( E_ALL );
ini_set( 'display_errors', '1' );

require_once __DIR__ . '/../tests/bootstrap.php';
require_once dirname( __DIR__ ) . '/kamand-size-guide/kamand-size-guide.php';

do_action( 'plugins_loaded' );
do_action( 'init' );

// جداکنندهٔ «--» که برخی اجراکننده‌های CLI اضافه می‌کنند نادیده گرفته می‌شود.
$cli_args = array_values(
	array_filter(
		array_slice( (array) $argv, 1 ),
		static function ( $argument ) {
			return '--' !== $argument;
		}
	)
);

$output_dir = isset( $cli_args[0] ) ? rtrim( $cli_args[0], '/' ) : dirname( __DIR__ ) . '/demo';

if ( ! is_dir( $output_dir ) ) {
	mkdir( $output_dir, 0777, true );
}

if ( ! is_dir( $output_dir . '/assets' ) ) {
	mkdir( $output_dir . '/assets', 0777, true );
}

/* ------------------------------------------------------------------ */
/* دادهٔ نمونه                                                          */
/* ------------------------------------------------------------------ */

$clothing = array(
	'unit'    => 'cm',
	'columns' => array(
		array( 'id' => 'c_size', 'label' => 'سایز', 'kind' => 'size' ),
		array( 'id' => 'c_bust', 'label' => 'دور سینه', 'kind' => 'measure' ),
		array( 'id' => 'c_waist', 'label' => 'دور کمر', 'kind' => 'measure' ),
		array( 'id' => 'c_hip', 'label' => 'دور باسن', 'kind' => 'measure' ),
		array( 'id' => 'c_len', 'label' => 'قد لباس', 'kind' => 'measure' ),
		array( 'id' => 'c_note', 'label' => 'معادل ایران', 'kind' => 'note' ),
	),
	'rows'    => array(
		array( 'id' => 'r_s', 'values' => array( 'c_size' => 'S', 'c_bust' => '۸۶', 'c_waist' => '۶۸', 'c_hip' => '۹۲', 'c_len' => '۶۲', 'c_note' => '۳۶' ) ),
		array( 'id' => 'r_m', 'values' => array( 'c_size' => 'M', 'c_bust' => '۹۲', 'c_waist' => '۷۴', 'c_hip' => '۹۸', 'c_len' => '۶۴', 'c_note' => '۳۸' ) ),
		array( 'id' => 'r_l', 'values' => array( 'c_size' => 'L', 'c_bust' => '۹۸', 'c_waist' => '۸۰', 'c_hip' => '۱۰۴', 'c_len' => '۶۶', 'c_note' => '۴۰' ) ),
		array( 'id' => 'r_xl', 'values' => array( 'c_size' => 'XL', 'c_bust' => '۱۰۴', 'c_waist' => '۸۶', 'c_hip' => '۱۱۰', 'c_len' => '۶۸', 'c_note' => '۴۲' ) ),
		array( 'id' => 'r_2xl', 'values' => array( 'c_size' => '2XL', 'c_bust' => '۱۱۰', 'c_waist' => '۹۲', 'c_hip' => '۱۱۶', 'c_len' => '۷۰', 'c_note' => '۴۴' ) ),
	),
	'tips'    => array(
		'اندازه‌ها روی بدن و با متر خیاطی گرفته شده‌اند.',
		'اگر بین دو سایز هستید، سایز بزرگ‌تر را انتخاب کنید.',
		'تلورانس دوخت این کار تا ۲ سانتی‌متر است.',
	),
	'note'    => 'این مدل کمی آزاد دوخته شده؛ برای ظاهر جذب‌تر یک سایز کوچک‌تر بردارید.',
	'image'   => 0,
);

$shoes = array(
	'unit'    => 'cm',
	'columns' => array(
		array( 'id' => 'c_size', 'label' => 'سایز اروپایی', 'kind' => 'size' ),
		array( 'id' => 'c_foot', 'label' => 'طول پا', 'kind' => 'measure' ),
		array( 'id' => 'c_us', 'label' => 'معادل US', 'kind' => 'note' ),
	),
	'rows'    => array(
		array( 'id' => 'r_38', 'values' => array( 'c_size' => '۳۸', 'c_foot' => '24', 'c_us' => '6' ) ),
		array( 'id' => 'r_39', 'values' => array( 'c_size' => '۳۹', 'c_foot' => '24.7', 'c_us' => '7' ) ),
		array( 'id' => 'r_40', 'values' => array( 'c_size' => '۴۰', 'c_foot' => '25.4', 'c_us' => '8' ) ),
		array( 'id' => 'r_41', 'values' => array( 'c_size' => '۴۱', 'c_foot' => '26', 'c_us' => '9' ) ),
		array( 'id' => 'r_42', 'values' => array( 'c_size' => '۴۲', 'c_foot' => '26.7', 'c_us' => '10' ) ),
	),
	'tips'    => array(
		'پا را روی کاغذ بگذارید و از پاشنه تا نوک شست را اندازه بگیرید.',
	),
	'note'    => '',
	'image'   => 0,
);

$ring = array(
	'unit'    => 'cm',
	'columns' => array(
		array( 'id' => 'c_size', 'label' => 'سایز انگشتر', 'kind' => 'size' ),
		array( 'id' => 'c_dia', 'label' => 'قطر داخلی', 'kind' => 'measure' ),
		array( 'id' => 'c_cir', 'label' => 'دور انگشت', 'kind' => 'measure' ),
	),
	'rows'    => array(
		array( 'id' => 'r_5', 'values' => array( 'c_size' => '۵', 'c_dia' => '1.57', 'c_cir' => '4.93' ) ),
		array( 'id' => 'r_6', 'values' => array( 'c_size' => '۶', 'c_dia' => '1.65', 'c_cir' => '5.19' ) ),
		array( 'id' => 'r_7', 'values' => array( 'c_size' => '۷', 'c_dia' => '1.73', 'c_cir' => '5.44' ) ),
		array( 'id' => 'r_8', 'values' => array( 'c_size' => '۸', 'c_dia' => '1.81', 'c_cir' => '5.70' ) ),
	),
	'tips'    => array( 'اندازه‌گیری را در دمای اتاق انجام دهید؛ سرما انگشت را کوچک‌تر می‌کند.' ),
	'note'    => '',
	'image'   => 0,
);

ksg_test_add_post( 701, 'مانتو بهارهٔ لینن' );
update_post_meta( 701, KSG_Guides::META_KEY, $clothing );

ksg_test_add_post( 702, 'راهنمای سایز کفش' );
update_post_meta( 702, KSG_Guides::META_KEY, $shoes );

ksg_test_add_post( 703, 'راهنمای سایز انگشتر' );
update_post_meta( 703, KSG_Guides::META_KEY, $ring );

/* ------------------------------------------------------------------ */
/* رندر سه سناریو با همان کد افزونه                                     */
/* ------------------------------------------------------------------ */

// سناریوی ۱: محصول متغیر با دو راهنما (تب) و برجسته‌سازی سایز انتخاب‌شده.
ksg_test_set_product( new KSG_Test_Product( 'variable', array( 'attribute_pa_size' => array( 's', 'm', 'l' ) ) ) );
$GLOBALS['ksg_test']['context']['post_id'] = 1201;

$scenario_variable = KSG_Frontend::get_html(
	array(
		array( 'id' => 701, 'title' => 'راهنمای سایز پوشاک', 'table' => $clothing ),
		array( 'id' => 702, 'title' => 'راهنمای سایز کفش', 'table' => $shoes ),
	),
	array( 'product_id' => 1201 )
);

// سناریوی ۲: محصول ساده با یک راهنما.
ksg_test_set_product( new KSG_Test_Product( 'simple', array() ) );
$GLOBALS['ksg_test']['context']['post_id'] = 1202;

$scenario_simple = KSG_Frontend::get_html(
	array( array( 'id' => 703, 'title' => 'راهنمای سایز انگشتر', 'table' => $ring ) ),
	array( 'product_id' => 1202 )
);

$settings  = KSG_Settings::all();
$accent    = $settings['accent_color'];
$inline    = sprintf(
	'.ksg{--ksg-accent:%1$s;--ksg-accent-strong:%2$s;--ksg-accent-soft:%3$s;--ksg-accent-line:%4$s;--ksg-radius:%5$dpx;}',
	$accent,
	KSG_Frontend::darken( $accent, 18 ),
	KSG_Frontend::rgba( $accent, 0.09 ),
	KSG_Frontend::rgba( $accent, 0.32 ),
	absint( $settings['radius'] )
);
$localized = wp_json_encode(
	array(
		'persianDigits' => (bool) $settings['persian_digits'],
		'cmLabel'       => 'سانتی‌متر',
		'inchLabel'     => 'اینچ',
		'closeLabel'    => 'بستن',
		'expandLabel'   => 'نمایش بزرگ‌تر',
		'collapseLabel' => 'بازگشت به صفحه',
		'sizeHint'      => 'سایز انتخاب‌شدهٔ شما',
	)
);

$plugin_dir = dirname( __DIR__ ) . '/kamand-size-guide';
copy( $plugin_dir . '/assets/css/frontend.css', $output_dir . '/assets/frontend.css' );
copy( $plugin_dir . '/assets/js/frontend.js', $output_dir . '/assets/frontend.js' );

/* ------------------------------------------------------------------ */
/* صفحهٔ پیش‌نمایش                                                      */
/* ------------------------------------------------------------------ */

$html = <<<HTML
<!doctype html>
<html lang="fa" dir="rtl">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>پیش‌نمایش افزونهٔ راهنمای سایز کمند</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/rastikerdar/vazirmatn@v33.003/Vazirmatn-font-face.css" />
<link rel="stylesheet" href="assets/frontend.css" />
<style>
	{$inline}
	*{box-sizing:border-box}
	body{margin:0;padding:32px 16px 64px;background:#f6f7fb;color:#0f172a;
		font-family:Vazirmatn,"Segoe UI",Tahoma,sans-serif;line-height:1.8}
	.page{max-width:960px;margin:0 auto}
	.page-head{margin-bottom:28px}
	.page-head h1{margin:0 0 6px;font-size:22px}
	.page-head p{margin:0;color:#64748b;font-size:14px}
	.layout{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:24px;align-items:start}
	@media (max-width:900px){.layout{grid-template-columns:minmax(0,1fr)}}
	.product{background:#fff;border:1px solid rgba(15,23,42,.08);border-radius:20px;padding:20px;
		box-shadow:0 20px 40px -34px rgba(15,23,42,.5)}
	.product__media{height:210px;border-radius:14px;margin-bottom:16px;
		background:linear-gradient(135deg,#fbcfe8,#e9d5ff 55%,#bfdbfe)}
	.product__title{margin:0 0 4px;font-size:17px}
	.product__meta{font-size:12.5px;color:#64748b;margin-bottom:12px}
	.product__price{font-size:19px;font-weight:800;margin-bottom:14px}
	.product__price small{font-size:12px;font-weight:500;color:#64748b;margin-inline-start:6px}
	.variations{margin-bottom:14px}
	.variations label{display:block;font-size:12.5px;color:#475569;margin-bottom:6px}
	.variations select{width:100%;padding:10px 12px;border-radius:10px;border:1px solid rgba(15,23,42,.15);
		font:inherit;background:#fff}
	.add-to-cart{display:flex;gap:10px;align-items:center}
	.add-to-cart button{flex:1;padding:13px 18px;border:0;border-radius:12px;background:var(--ksg-accent);
		color:#fff;font:inherit;font-weight:700;cursor:pointer}
	.add-to-cart .wish{flex:0 0 auto;padding:13px 14px;border-radius:12px;border:1px solid rgba(15,23,42,.15);
		background:#fff;cursor:pointer}
	.note{margin-top:26px;padding:14px 16px;border-radius:14px;background:#fff;
		border:1px dashed rgba(15,23,42,.15);font-size:12.5px;color:#475569}
	code{background:#f1f5f9;padding:1px 6px;border-radius:6px;font-size:11.5px}
</style>
</head>
<body>
<div class="page">
	<header class="page-head">
		<h1>پیش‌نمایش افزونهٔ «راهنمای سایز کمند» برای ووکامرس</h1>
		<p>این صفحه خروجی واقعی <code>KSG_Frontend::get_html()</code> است؛ همان HTML و CSS و JavaScript که افزونه در صفحهٔ محصول چاپ می‌کند. جدول دقیقاً زیر دکمهٔ خرید قرار می‌گیرد.</p>
	</header>

	<div class="layout">
		<section>
			<article class="product">
				<div class="product__media" aria-hidden="true"></div>
				<h2 class="product__title">مانتو بهارهٔ لینن</h2>
				<p class="product__meta">کد کالا: KMD-1201 · موجود در انبار</p>
				<p class="product__price">۱٬۲۸۰٬۰۰۰ <small>تومان</small></p>

				<form class="variations variations_form cart" onsubmit="return false;">
					<div class="variations">
						<label for="demo-size">سایز</label>
						<select id="demo-size" name="attribute_pa_size">
							<option value="">یک گزینه انتخاب کنید…</option>
							<option value="s">S</option>
							<option value="m" selected>M</option>
							<option value="l">L</option>
							<option value="xl">XL</option>
						</select>
					</div>

					<div class="add-to-cart">
						<button type="submit">افزودن به سبد خرید</button>
						<span class="wish" aria-hidden="true">♡</span>
					</div>
				</form>

				{$scenario_variable}
			</article>

			<p class="note">در این نمونه سایز <strong>M</strong> از قبل انتخاب شده است؛ افزونه به‌صورت خودکار ردیف همان سایز را برجسته می‌کند. با تغییر سایز از فهرست بالا، ردیف برجسته جابه‌جا می‌شود. کلید «سانتی‌متر/اینچ» اعداد را واقعاً تبدیل می‌کند و «نمایش بزرگ‌تر» جدول را در پنجرهٔ بزرگ باز می‌کند.</p>
		</section>

		<section>
			<article class="product">
				<div class="product__media" aria-hidden="true" style="background:linear-gradient(135deg,#fde68a,#fca5a5 60%,#f9a8d4)"></div>
				<h2 class="product__title">انگشتر نقرهٔ طرح پیچک</h2>
				<p class="product__meta">کد کالا: KMD-1202 · موجود در انبار</p>
				<p class="product__price">۶۴۰٬۰۰۰ <small>تومان</small></p>

				<form class="cart" onsubmit="return false;">
					<div class="add-to-cart">
						<button type="submit">افزودن به سبد خرید</button>
						<span class="wish" aria-hidden="true">♡</span>
					</div>
				</form>

				{$scenario_simple}
			</article>

			<p class="note">اگر برای محصولی راهنمای اختصاصی تعیین نکنید، افزونه از راهنمای پیش‌فرض دسته‌بندی یا راهنمای پیش‌فرض فروشگاه استفاده می‌کند. برای محصولاتی که راهنما ندارند، هیچ چیزی چاپ نمی‌شود.</p>
		</section>
	</div>
</div>

<script>window.ksgFrontend = {$localized};</script>
<script src="assets/frontend.js"></script>
</body>
</html>
HTML;

file_put_contents( $output_dir . '/index.html', $html ); // phpcs:ignore WordPress.WP.AlternativeFunctions

echo "پیش‌نمایش ساخته شد: {$output_dir}/index.html\n";
