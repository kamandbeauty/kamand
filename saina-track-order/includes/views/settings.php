<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
$s       = Saina_TO_Helpers::get_settings();
$choices = Saina_TO_Helpers::wc_status_choices();
if ( ! function_exists( 'saina_status_select' ) ) {
function saina_status_select( $name, $value, $choices ) {
	echo '<select name="' . esc_attr( $name ) . '">';
	foreach ( $choices as $k => $label ) {
		echo '<option value="' . esc_attr( $k ) . '" ' . selected( $value, $k, false ) . '>' . esc_html( $label ) . '</option>';
	}
	echo '</select>';
}
}
?>
<div class="wrap saina-wrap saina-settings">
	<h1>به افزونه پیگیری سفارشات ووکامرس ساینا خوش آمدید</h1>
	<?php settings_errors( 'saina_to' ); ?>
	<form method="post">
		<?php wp_nonce_field( 'saina_to_settings' ); ?>

		<p class="saina-red"><strong>نمایش جزئیات سفارش برای کاربران وارد شده (با فعال‌سازی این گزینه کاربران فقط مجاز به دیدن سفارش خودشان می‌باشند)</strong></p>
		<p><label><input type="checkbox" name="own_orders" value="yes" <?php checked( $s['own_orders'], 'yes' ); ?> /> فعال سازی</label></p>
		<p class="saina-red">فعال سازی کد کپچا از لحاظ امنیتی این مورد پیشنهاد میشود!</p>
		<p>
			<label>فعال سازی کد کپچا</label>
			<select name="captcha">
				<option value="none" <?php selected( $s['captcha'], 'none' ); ?>>غیرفعال</option>
				<option value="math" <?php selected( $s['captcha'], 'math' ); ?>>کپچای عددی</option>
				<option value="recaptcha2" <?php selected( $s['captcha'], 'recaptcha2' ); ?>>Google reCAPTCHA v2</option>
				<option value="recaptcha3" <?php selected( $s['captcha'], 'recaptcha3' ); ?>>Google reCAPTCHA v3</option>
			</select>
		</p>
		<p>
			<input type="text" class="regular-text" name="recaptcha_site" value="<?php echo esc_attr( $s['recaptcha_site'] ); ?>" placeholder="Site key گوگل کپچا" />
			<input type="text" class="regular-text" name="recaptcha_secret" value="<?php echo esc_attr( $s['recaptcha_secret'] ); ?>" placeholder="Secret key" />
		</p>

		<p class="saina-red"><strong>حد هایی که میخواهید با آن جستجوی سفارش انجام شود</strong></p>
		<p class="description">توجه: سفارشاتی که با ایمیل و موبایل جستجو می‌شوند اگر بیش از ۱ سفارش وجود داشته باشد مجموع ۴ سفارش اخیر در فرم پیگیری نمایش داده می‌شود!</p>
		<p>
			<label><input type="checkbox" name="search_order" value="yes" <?php checked( $s['search_order'], 'yes' ); ?> /> شماره سفارش</label>
			<label><input type="checkbox" name="search_mobile" value="yes" <?php checked( $s['search_mobile'], 'yes' ); ?> /> شماره موبایل</label>
			<label><input type="checkbox" name="search_email" value="yes" <?php checked( $s['search_email'], 'yes' ); ?> /> ایمیل</label>
		</p>

		<p><label><input type="checkbox" name="ajax_search" value="yes" <?php checked( $s['ajax_search'], 'yes' ); ?> /> ارسال اطلاعات به صورت ایجکسی. در صورتی که در قسمت فرم چیزی نمایش داده نشد و یا بهم‌ریختگی بوجود آمد این تیک را بردارید؛ قالب شما پشتیبانی نمی‌کند</label></p>
		<p><label><input type="checkbox" name="post_new_tab" value="yes" <?php checked( $s['post_new_tab'], 'yes' ); ?> /> اگر میخواهید فرم پیگیری پست به صورت تب جدید باز شود فعال کنید</label></p>
		<p><label><input type="checkbox" name="disable_virtual" value="yes" <?php checked( $s['disable_virtual'], 'yes' ); ?> /> غیرفعال سازی پیگیری محصولات دانلودی و مجازی</label></p>
		<p><label><input type="checkbox" name="disable_progress_account" value="yes" <?php checked( $s['disable_progress_account'], 'yes' ); ?> /> غیرفعال سازی نوار پیشرفت در سفارشات کاربری</label></p>
		<p><label><input type="checkbox" name="disable_progress_thanks" value="yes" <?php checked( $s['disable_progress_thanks'], 'yes' ); ?> /> غیرفعال سازی نوار پیشرفت در قسمت صفحه تشکر</label></p>
		<p><label><input type="checkbox" name="disable_icons_column" value="yes" <?php checked( $s['disable_icons_column'], 'yes' ); ?> /> غیرفعال سازی ستون آیکن ها در قسمت سفارشات کاربری</label></p>
		<p><label><input type="checkbox" name="dokan_tracking" value="yes" <?php checked( $s['dokan_tracking'], 'yes' ); ?> /> فعال سازی درج کد رهگیری برای فروشندگان دکان</label></p>
		<p><label><input type="checkbox" name="skip_required" value="yes" <?php checked( $s['skip_required'], 'yes' ); ?> /> اگر نمیخواهید در فرم پیگیری کاربر شماره سفارش یا شماره موبایل یا ایمیل سفارششان را تکمیل نمایند این گزینه را فعال کنید</label></p>
		<p class="description">در برخی قالب‌ها زمانی که تکمیل‌شده در مرحله تکمیل‌شده به نوار پیشرفت چک‌مارک با بهم‌ریختگی به‌وجود آید، در این صورت این گزینه را فعال کنید.</p>

		<p><label>متن سفارشی فرم پیگیری<br>
			<input type="text" class="large-text" name="form_placeholder" value="<?php echo esc_attr( $s['form_placeholder'] ); ?>" />
		</label></p>

		<p class="description">شما می‌توانید با استفاده از این قسمت تکمیل بودن نوار پیشرفت را تغییر دهید. در صورتی که وضعیتی انتخاب ننمایید از وضعیت‌های پیش‌فرض پیروی خواهد شد. برای فعال شدن وضعیت جدید، پلاگین‌های جانبی هم وضعیت را فعال نمایید. وضعیت فعلی به‌صورت پیش‌فرض در حال انجام است و نوار به‌طور کامل در مرحله اول در حال انجام نیاز به ورود از این وضعیت در حال انجام در مرحله تکمیل نیست اما می‌تواند در مراحل ۲ تا ۵ انتخابی دیگر این مورد برای ۴ وضعیت بعدی نیز صدق می‌کند.</p>

		<table class="widefat striped saina-steps">
			<thead><tr><th>مرحله نوار</th><th>وضعیت ووکامرس</th><th>گزینه</th></tr></thead>
			<tbody>
				<tr>
					<td>انجام وضعیت‌ها در مرحله ۱ — در حال انجام</td>
					<td><?php saina_status_select( 'step1_status', $s['step1_status'], $choices ); ?></td>
					<td></td>
				</tr>
				<tr>
					<td>انجام وضعیت‌ها در مرحله ۲ — در حال بررسی</td>
					<td><?php saina_status_select( 'step2_status', $s['step2_status'], $choices ); ?></td>
					<td></td>
				</tr>
				<tr>
					<td>انجام وضعیت‌ها در مرحله ۳ — بسته‌بندی</td>
					<td><?php saina_status_select( 'step3_status', $s['step3_status'], $choices ); ?></td>
					<td></td>
				</tr>
				<tr>
					<td>انجام وضعیت‌ها در مرحله ۴ — تکمیل شده</td>
					<td><?php saina_status_select( 'step4_status', $s['step4_status'], $choices ); ?></td>
					<td><label><input type="checkbox" name="step4_to_post" value="yes" <?php checked( $s['step4_to_post'], 'yes' ); ?> /> تحویل به پست</label></td>
				</tr>
				<tr>
					<td>انجام وضعیت‌ها در مرحله ۵ — تحویل شده</td>
					<td><?php saina_status_select( 'step5_status', $s['step5_status'], $choices ); ?></td>
					<td><label><input type="checkbox" name="step5_delivered" value="yes" <?php checked( $s['step5_delivered'], 'yes' ); ?> /> تحویل شده</label></td>
				</tr>
			</tbody>
		</table>

		<p><label><input type="checkbox" name="enable_delivered" value="yes" <?php checked( $s['enable_delivered'], 'yes' ); ?> /> فعال کردن تحویل شده</label></p>
		<p><label><input type="checkbox" name="disable_confirm" value="yes" <?php checked( $s['disable_confirm'], 'yes' ); ?> /> غیرفعال سازی صحت دریافت محصول در صفحه سفارشات کاربر</label></p>
		<p>برای مشاهده شورتکدها کلیک کنید: <code>{order_id}</code> <code>{trackingurl}</code> <code>{username}</code> <code>{senddate}</code> <code>{deliverydate}</code> <code>{peyk}</code></p>

		<p><label>متن تولتیپ تکمیل شده (یا مرحله ۳)<br>
			<input type="text" class="large-text" name="tooltip_completed" value="<?php echo esc_attr( $s['tooltip_completed'] ); ?>" />
		</label></p>
		<p><label>متن تولتیپ تحویل شده (یا مرحله ۵)<br>
			<input type="text" class="large-text" name="tooltip_delivered" value="<?php echo esc_attr( $s['tooltip_delivered'] ); ?>" />
		</label></p>
		<p><label>متن تولتیپ تکمیل شده برای پیک (یا مرحله ۴)<br>
			<input type="text" class="large-text" name="tooltip_peyk_completed" value="<?php echo esc_attr( $s['tooltip_peyk_completed'] ); ?>" />
		</label></p>
		<p><label>متن تولتیپ تحویل شده برای پیک (یا مرحله ۵)<br>
			<input type="text" class="large-text" name="tooltip_peyk_delivered" value="<?php echo esc_attr( $s['tooltip_peyk_delivered'] ); ?>" />
		</label></p>

		<p>در این قسمت می‌توانید متن پیامکی که برای پیک ارسال می‌گردد را وارد نمایید. توجه کنید این پیام جایگزین پیامک تکمیل شده یا وضعیتی که در زیر انتخاب می‌کنید برای مشتری می‌باشد</p>
		<p>
			<?php saina_status_select( 'peyk_sms_status', $s['peyk_sms_status'], $choices ); ?>
			<span class="description">به‌صورت پیش‌فرض برای تکمیل شده ارسال می‌گردد</span>
		</p>
		<p><textarea name="peyk_sms_text" class="large-text" rows="3"><?php echo esc_textarea( $s['peyk_sms_text'] ); ?></textarea></p>

		<p><label>شهرها و شهرستان‌هایی که می‌خواهید سیستم پیک در آن فعال شود<br>
			<input type="text" class="large-text" name="peyk_cities" value="<?php echo esc_attr( $s['peyk_cities'] ); ?>" placeholder="تهران، کرج، اصفهان" />
		</label></p>
		<p><label>روش حمل و نقلی که می‌خواهید برای سیستم پیک در آن فعال شود<br>
			<input type="text" class="regular-text" name="peyk_method" value="<?php echo esc_attr( $s['peyk_method'] ); ?>" placeholder="پیک موتوری" />
		</label></p>
		<p><label><input type="checkbox" name="peyk_nationwide" value="yes" <?php checked( $s['peyk_nationwide'], 'yes' ); ?> /> چک باکسی در سطح کشور اضافه (شهرها یا مشتری)</label></p>

		<p class="saina-red"><strong>نمایش جزئیات مرسوله</strong></p>
		<p>
			<label><input type="checkbox" name="show_user" value="yes" <?php checked( $s['show_user'], 'yes' ); ?> /> کاربر</label>
			<label><input type="checkbox" name="show_payment" value="yes" <?php checked( $s['show_payment'], 'yes' ); ?> /> روش پرداخت</label>
			<label><input type="checkbox" name="show_destination" value="yes" <?php checked( $s['show_destination'], 'yes' ); ?> /> مقصد</label>
			<label><input type="checkbox" name="show_amount" value="yes" <?php checked( $s['show_amount'], 'yes' ); ?> /> مبلغ پرداخت</label>
			<label><input type="checkbox" name="show_product_image" value="yes" <?php checked( $s['show_product_image'], 'yes' ); ?> /> نمایش تصویر محصول</label>
			<label><input type="checkbox" name="show_product_name" value="yes" <?php checked( $s['show_product_name'], 'yes' ); ?> /> نمایش نام محصول</label>
			<label><input type="checkbox" name="show_state_beside" value="yes" <?php checked( $s['show_state_beside'], 'yes' ); ?> /> نمایش حالت در کنار نوار وضعیت‌ها</label>
			<label><input type="checkbox" name="shared_progress_image" value="yes" <?php checked( $s['shared_progress_image'], 'yes' ); ?> /> ساخت تصویر پیشرفت مشترک</label>
			<label><input type="checkbox" name="upload_form_image" value="yes" <?php checked( $s['upload_form_image'], 'yes' ); ?> /> بارگذاری تصویر در فرم پیگیری</label>
		</p>

		<p><label>آدرس لوگو (URL)<br>
			<input type="url" class="large-text" name="logo" value="<?php echo esc_attr( $s['logo'] ); ?>" />
		</label></p>
		<p><label>اندازه آیکن نوار پیشرفت (۱۵ تا ۱۵۰)
			<input type="number" min="15" max="150" name="icon_size" value="<?php echo esc_attr( $s['icon_size'] ); ?>" />
		</label></p>
		<p>
			<label>رنگ نوار پیشرفت <input type="color" name="color_progress" value="<?php echo esc_attr( $s['color_progress'] ); ?>" /></label>
			<label>رنگ دکمه و فیلد فرم پیگیری <input type="color" name="color_form_btn" value="<?php echo esc_attr( $s['color_form_btn'] ); ?>" /></label>
			<label>رنگ هدر جدول جزئیات کاربر <input type="color" name="color_table_header" value="<?php echo esc_attr( $s['color_table_header'] ); ?>" /></label>
			<label>رنگ متن هدر جدول <input type="color" name="color_table_header_text" value="<?php echo esc_attr( $s['color_table_header_text'] ); ?>" /></label>
			<label>رنگ دکمه پیگیری از پست <input type="color" name="color_post_btn" value="<?php echo esc_attr( $s['color_post_btn'] ); ?>" /></label>
			<label>رنگ متن دکمه پیگیری از پست <input type="color" name="color_post_btn_text" value="<?php echo esc_attr( $s['color_post_btn_text'] ); ?>" /></label>
		</p>

		<p><label>انتخاب استایل نوار پیشرفت
			<select name="progress_style">
				<option value="digi" <?php selected( $s['progress_style'], 'digi' ); ?>>استایل دیجی نوین</option>
				<option value="classic" <?php selected( $s['progress_style'], 'classic' ); ?>>کلاسیک</option>
				<option value="minimal" <?php selected( $s['progress_style'], 'minimal' ); ?>>مینیمال</option>
			</select>
		</label></p>
		<p><label>محل نمایش نوار پیشرفت
			<select name="progress_position">
				<option value="before" <?php selected( $s['progress_position'], 'before' ); ?>>قبل از جزئیات سفارش</option>
				<option value="after" <?php selected( $s['progress_position'], 'after' ); ?>>بعد از جزئیات سفارش</option>
			</select>
		</label></p>
		<p class="description">انتخاب نمایش نوار پیشرفت بعد از فیل جزئیات سفارش (این مورد بستگی به قالب شما دارد؛ اگر از فیل جزئیات سفارش بهم‌ریختگی دارد شامل پشتیبانی نمی‌شود)</p>

		<p><label><input type="checkbox" name="jalali_calendar" value="yes" <?php checked( $s['jalali_calendar'], 'yes' ); ?> /> فعال سازی تقویم شمسی در صفحه سفارش</label></p>
		<p class="description">در صورت تداخل تقویم شمسی با سایر افزونه‌های شمسی این گزینه را غیرفعال کنید</p>

		<p><label><input type="checkbox" name="auto_deliver" value="yes" <?php checked( $s['auto_deliver'], 'yes' ); ?> /> فعال سازی خودکار تغییر وضعیت به تحویل شده سفارشات</label></p>
		<p>از این قسمت تعیین کنید سفارشات تکمیل شده پس از چند روز به وضعیت تحویل شده تغییر وضعیت دهد (از یک ماه اخیر در نظر گرفته می‌شود). تعداد روز:
			<input type="number" min="1" name="auto_deliver_days" value="<?php echo esc_attr( $s['auto_deliver_days'] ); ?>" class="small-text" />
		</p>

		<p><label><input type="checkbox" name="tapin_sync" value="yes" <?php checked( $s['tapin_sync'], 'yes' ); ?> /> اگر از افزونه حمل و نقل تاپین که در مخزن وردپرس موجود است استفاده می‌کنید و کدهای رهگیری که توسط تاپین دریافت می‌شود را می‌خواهید در فیلد کد رهگیری سفارشات اضافه کنید، فعال کنید (این مورد هنگامی‌که کدهای مرسوله دریافت شده باشند و بعد از آن تغییر وضعیت تکمیل شده فعال می‌شود. تاریخ ارسال لحظه تغییر وضعیت تکمیل و نوع فرم پست پیشتاز انتخاب می‌شود)</label></p>
		<p><label><input type="checkbox" name="email_embed" value="yes" <?php checked( $s['email_embed'], 'yes' ); ?> /> درج جزئیات ارسال در ایمیل ووکامرس</label></p>

		<p class="submit"><button class="button button-primary" name="saina_to_save_settings" value="1">ذخیره تغییرات</button></p>
	</form>
</div>
