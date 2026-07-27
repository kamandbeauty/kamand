<?php
/**
 * Bilingual (fa / en) string map.
 *
 * The web-app switches language instantly on the client, so every UI string
 * lives in one map that is exposed to both PHP (Havato_I18N::t) and JS
 * (window.HAVATO.i18n). WordPress .po/.mo files remain supported for anything
 * rendered outside the app (admin notices, plugin meta, e-mails).
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Translation registry.
 */
class Havato_I18N {

	/**
	 * Cached string map.
	 *
	 * @var array|null
	 */
	private static $map = null;

	/**
	 * Runtime language override (used by REST requests).
	 *
	 * @var string|null
	 */
	private static $forced_lang = null;

	/**
	 * Supported languages and their direction.
	 *
	 * @return array
	 */
	public static function languages() {
		return array(
			'fa' => array(
				'label' => 'فارسی',
				'dir'   => 'rtl',
				'font'  => 'Vazirmatn',
			),
			'en' => array(
				'label' => 'English',
				'dir'   => 'ltr',
				'font'  => 'system',
			),
		);
	}

	/**
	 * Force a language for the current request.
	 *
	 * @param string $lang Language code.
	 */
	public static function set_lang( $lang ) {
		$lang              = self::sanitize_lang( $lang );
		self::$forced_lang = $lang;
	}

	/**
	 * Normalize any incoming language value.
	 *
	 * @param mixed $lang Raw value.
	 * @return string
	 */
	public static function sanitize_lang( $lang ) {
		$lang = is_string( $lang ) ? strtolower( substr( trim( $lang ), 0, 5 ) ) : '';
		if ( 0 === strpos( $lang, 'en' ) ) {
			return 'en';
		}
		return 'fa';
	}

	/**
	 * Resolve the active language: forced > request > user meta > site default.
	 *
	 * @return string
	 */
	public static function current_lang() {
		if ( null !== self::$forced_lang ) {
			return self::$forced_lang;
		}

		// phpcs:ignore WordPress.Security.NonceVerification.Recommended -- read-only display preference.
		if ( isset( $_REQUEST['havato_lang'] ) ) {
			// phpcs:ignore WordPress.Security.NonceVerification.Recommended
			return self::sanitize_lang( wp_unslash( $_REQUEST['havato_lang'] ) );
		}

		$user_id = get_current_user_id();
		if ( $user_id ) {
			$meta = get_user_meta( $user_id, 'havato_lang', true );
			if ( $meta ) {
				return self::sanitize_lang( $meta );
			}
		}

		if ( isset( $_COOKIE['havato_lang'] ) ) {
			return self::sanitize_lang( wp_unslash( $_COOKIE['havato_lang'] ) );
		}

		$default = get_option( 'havato_default_lang', 'fa' );
		return self::sanitize_lang( $default );
	}

	/**
	 * Direction of the active (or given) language.
	 *
	 * @param string|null $lang Language code.
	 * @return string rtl|ltr
	 */
	public static function dir( $lang = null ) {
		$lang = $lang ? self::sanitize_lang( $lang ) : self::current_lang();
		$all  = self::languages();
		return $all[ $lang ]['dir'];
	}

	/**
	 * Translate a key.
	 *
	 * @param string      $key  String key.
	 * @param string|null $lang Optional language override.
	 * @return string
	 */
	public static function t( $key, $lang = null ) {
		$lang = $lang ? self::sanitize_lang( $lang ) : self::current_lang();
		$map  = self::map();
		if ( isset( $map[ $key ][ $lang ] ) ) {
			return $map[ $key ][ $lang ];
		}
		if ( isset( $map[ $key ]['en'] ) ) {
			return $map[ $key ]['en'];
		}
		return $key;
	}

	/**
	 * Flat key => string map for one language (for the JS bundle).
	 *
	 * @param string $lang Language.
	 * @return array
	 */
	public static function flat( $lang ) {
		$lang = self::sanitize_lang( $lang );
		$out  = array();
		foreach ( self::map() as $key => $pair ) {
			$out[ $key ] = isset( $pair[ $lang ] ) ? $pair[ $lang ] : $pair['en'];
		}
		return $out;
	}

	/**
	 * Both languages at once (client side instant switch).
	 *
	 * @return array
	 */
	public static function bundle() {
		return array(
			'fa' => self::flat( 'fa' ),
			'en' => self::flat( 'en' ),
		);
	}

	/**
	 * The complete string map.
	 *
	 * @return array
	 */
	public static function map() {
		if ( null !== self::$map ) {
			return self::$map;
		}

		self::$map = array(
			// Generic.
			'app_name'              => array( 'fa' => 'هواتو', 'en' => 'Havato' ),
			'tagline'               => array( 'fa' => 'دورهمی‌های هوشمند در کافه‌های شهر', 'en' => 'Smart social tables in your city' ),
			'loading'               => array( 'fa' => 'در حال بارگذاری…', 'en' => 'Loading…' ),
			'uploading'             => array( 'fa' => 'در حال آپلود…', 'en' => 'Uploading…' ),
			'uploading_photo'       => array( 'fa' => 'در حال آپلود عکس…', 'en' => 'Uploading photo…' ),
			'uploading_avatar'      => array( 'fa' => 'در حال آپلود عکس پروفایل…', 'en' => 'Uploading profile photo…' ),
			'uploading_cover'       => array( 'fa' => 'در حال آپلود عکس کاور…', 'en' => 'Uploading cover photo…' ),
			'upload_cancelled'      => array( 'fa' => 'آپلود لغو شد', 'en' => 'Upload cancelled' ),
			'saving'                => array( 'fa' => 'در حال ذخیره…', 'en' => 'Saving…' ),
			'save'                  => array( 'fa' => 'ذخیره', 'en' => 'Save' ),
			'saved'                 => array( 'fa' => 'ذخیره شد', 'en' => 'Saved' ),
			'cancel'                => array( 'fa' => 'انصراف', 'en' => 'Cancel' ),
			'close'                 => array( 'fa' => 'بستن', 'en' => 'Close' ),
			'send'                  => array( 'fa' => 'ارسال', 'en' => 'Send' ),
			'submit'                => array( 'fa' => 'ثبت', 'en' => 'Submit' ),
			'back'                  => array( 'fa' => 'بازگشت', 'en' => 'Back' ),
			'next'                  => array( 'fa' => 'بعدی', 'en' => 'Next' ),
			'prev'                  => array( 'fa' => 'قبلی', 'en' => 'Previous' ),
			'finish'                => array( 'fa' => 'پایان', 'en' => 'Finish' ),
			'confirm'               => array( 'fa' => 'تایید', 'en' => 'Confirm' ),
			'delete'                => array( 'fa' => 'حذف', 'en' => 'Delete' ),
			'edit'                  => array( 'fa' => 'ویرایش', 'en' => 'Edit' ),
			'search'                => array( 'fa' => 'جستجو', 'en' => 'Search' ),
			'filter'                => array( 'fa' => 'فیلتر', 'en' => 'Filter' ),
			'error_generic'         => array( 'fa' => 'خطایی رخ داد. دوباره تلاش کنید.', 'en' => 'Something went wrong. Please retry.' ),
			'boot_failed'           => array( 'fa' => 'ارتباط با سرور برقرار نشد', 'en' => 'Could not reach the server' ),
			'retry'                 => array( 'fa' => 'تلاش دوباره', 'en' => 'Try again' ),
			'empty_state'           => array( 'fa' => 'فعلاً چیزی برای نمایش نیست.', 'en' => 'Nothing here yet.' ),
			'toman'                 => array( 'fa' => 'تومان', 'en' => 'Toman' ),
			'free'                  => array( 'fa' => 'رایگان', 'en' => 'Free' ),
			'always_free'           => array( 'fa' => 'شرکت در همه‌ی دورهمی‌ها رایگان است.', 'en' => 'Every gathering is free to join.' ),
			'need_details_first'    => array(
				'fa' => 'برای ثبت‌نام، ابتدا مشخصات خود را در پروفایل کامل کنید.',
				'en' => 'Complete your details on your profile before joining.',
			),
			'yes'                   => array( 'fa' => 'بله', 'en' => 'Yes' ),
			'no'                    => array( 'fa' => 'خیر', 'en' => 'No' ),
			'lang_switch'           => array( 'fa' => 'English', 'en' => 'فارسی' ),
			'lang_label'            => array( 'fa' => 'زبان', 'en' => 'Language' ),

			// Auth wall.
			'auth_title'            => array( 'fa' => 'به هواتو خوش آمدید', 'en' => 'Welcome to Havato' ),
			'auth_sub'              => array( 'fa' => 'با آدم‌های هم‌فرکانس خودت، سر یک میز در بهترین کافه‌های شهر بنشین.', 'en' => 'Sit at one table with people who match your vibe, in the best cafés in town.' ),
			'login_google'          => array( 'fa' => 'ورود با حساب گوگل', 'en' => 'Continue with Google' ),
			'user_login_heading'    => array( 'fa' => 'ورود کاربر', 'en' => 'User sign-in' ),
			'login_failed'          => array( 'fa' => 'ایمیل یا رمز عبور نادرست است.', 'en' => 'Incorrect email or password.' ),
			'login_owner_only'      => array( 'fa' => 'این صفحه فقط برای صاحبان کافه است.', 'en' => 'This page is for café owners only.' ),
			'login_throttled'       => array( 'fa' => 'تلاش‌های ناموفق زیاد. ۱۵ دقیقه دیگر دوباره تلاش کنید.', 'en' => 'Too many attempts. Please try again in 15 minutes.' ),
			'forgot_password'       => array( 'fa' => 'رمز عبور را فراموش کرده‌اید؟', 'en' => 'Forgot your password?' ),
			'signup_pending_hint'   => array( 'fa' => 'پس از ثبت‌نام، کافه شما تا تایید مدیریت برای کاربران نمایش داده نمی‌شود.', 'en' => 'After signing up your café stays hidden from guests until an administrator approves it.' ),
			'storefront_title'      => array( 'fa' => 'عکس ورودی مغازه', 'en' => 'Photo of your shopfront' ),
			'storefront_hint'       => array( 'fa' => 'برای تایید سریع‌تر کافه، یک عکس از ورودی مغازه آپلود کنید.', 'en' => 'Upload a photo of your entrance to get verified faster.' ),
			'storefront_received'   => array( 'fa' => 'عکس دریافت شد و در حال بررسی است.', 'en' => 'Photo received — it is being reviewed.' ),
			'login_owner'           => array( 'fa' => '🔑 ورود صاحبین کافه', 'en' => '🔑 Café owner sign-in' ),
			'register_partner'      => array( 'fa' => '💼 ثبت‌نام کافه شریک', 'en' => '💼 Become a partner café' ),
			'google_not_configured' => array( 'fa' => 'ورود با گوگل هنوز توسط مدیر پیکربندی نشده است.', 'en' => 'Google sign-in has not been configured by the administrator yet.' ),
			'logout'                => array( 'fa' => 'خروج از حساب', 'en' => 'Sign out' ),

			// Tabs (gatherer).
			'tab_explore'           => array( 'fa' => 'کاوش', 'en' => 'Explore' ),
			'tab_map'               => array( 'fa' => 'نقشه', 'en' => 'Map' ),
			'tab_chats'             => array( 'fa' => 'گفتگوها', 'en' => 'Chats' ),
			'tab_profile'           => array( 'fa' => 'پروفایل من', 'en' => 'My Profile' ),

			// Tabs (owner).
			'tab_dashboard'         => array( 'fa' => 'داشبورد', 'en' => 'Dashboard' ),
			'tab_venue_events'      => array( 'fa' => 'رویدادهای کافه', 'en' => 'Venue Events' ),
			'tab_menu_builder'      => array( 'fa' => 'ساخت منو', 'en' => 'Menu Builder' ),
			'tab_tables'            => array( 'fa' => 'میزهای کافه', 'en' => 'My tables' ),
			'tables_hint'           => array( 'fa' => 'میزهای کافه را یک‌بار تعریف کنید؛ بعد برای هر دورهمی فقط تیک می‌زنید. ظرفیت خودکار حساب می‌شود.', 'en' => 'Define your tables once, then just tick them for each event — capacity is calculated automatically.' ),
			'table_label'           => array( 'fa' => 'نام میز', 'en' => 'Table name' ),
			'table_label_hint'      => array( 'fa' => 'مثلاً میز پنجره', 'en' => 'e.g. Window table' ),
			'table_seats'           => array( 'fa' => 'تعداد صندلی', 'en' => 'Seats' ),
			'table_number_col'      => array( 'fa' => 'شماره میز', 'en' => 'Table no.' ),
			'table_number_label'    => array( 'fa' => 'میز شماره %d', 'en' => 'Table #%d' ),
			'table_number_duplicate' => array( 'fa' => 'شماره میز %d تکراری است.', 'en' => 'Table number %d is duplicated.' ),
			'table_number_required' => array( 'fa' => 'برای هر میز، شماره همان میز در کافه را وارد کنید.', 'en' => 'Enter the number each table actually carries in your café.' ),
			'table_number_hint'     => array( 'fa' => 'شماره‌ای که روی میز نوشته شده را وارد کنید تا مهمان‌ها گیج نشوند.', 'en' => 'Use the number written on the table itself so guests are not confused.' ),
			'tables_locked'         => array( 'fa' => 'تا پایان %d دورهمی فعال، امکان ویرایش میزها نیست.', 'en' => 'Tables cannot be edited while %d active event(s) are using them.' ),
			'tables_locked_hint'    => array( 'fa' => 'پس از برگزاری یا لغو این دورهمی‌ها، میزها دوباره قابل ویرایش می‌شوند.', 'en' => 'Once those events finish or are cancelled, the tables unlock again.' ),
			'table_quantity'        => array( 'fa' => 'تعداد میز', 'en' => 'How many' ),
			'event_tables_pick'     => array( 'fa' => 'میزهای این دورهمی را انتخاب کنید', 'en' => 'Pick the tables for this event' ),
			'event_capacity_preview' => array( 'fa' => 'ظرفیت این دورهمی: %d نفر', 'en' => 'Capacity for this event: %d guests' ),
			'event_need_tables'     => array( 'fa' => 'حداقل یک میز را انتخاب کنید.', 'en' => 'Please select at least one table.' ),
			'event_theme'           => array( 'fa' => 'تم دورهمی', 'en' => 'Event theme' ),
			'event_theme_hint'      => array( 'fa' => 'مثلاً موسیقی، کتاب، بازی', 'en' => 'e.g. Music, Books, Games' ),
			'event_image'           => array( 'fa' => 'عکس دورهمی (اختیاری)', 'en' => 'Event photo (optional)' ),
			'tab_venue_settings'    => array( 'fa' => 'تنظیمات کافه', 'en' => 'Venue Settings' ),

			// Explore.
			'explore_title'         => array( 'fa' => 'دورهمی‌های این هفته', 'en' => 'This week’s tables' ),
			'explore_empty'         => array( 'fa' => 'فعلاً دورهمی بازی ثبت نشده است.', 'en' => 'No open tables right now.' ),
			'seats_left'            => array( 'fa' => 'صندلی خالی', 'en' => 'seats left' ),
			'join_event'            => array( 'fa' => 'رزرو صندلی', 'en' => 'Reserve a seat' ),
			'reserve_title'         => array( 'fa' => 'رزرو صندلی', 'en' => 'Reserve a seat' ),
			'how_many_seats'        => array( 'fa' => 'چند صندلی رزرو می‌کنید؟', 'en' => 'How many seats?' ),
			'seats_hint'            => array(
				'fa' => 'می‌توانید تا %s صندلی رزرو کنید. همراهان شما کنار خودتان می‌نشینند.',
				'en' => 'You can reserve up to %s seats. Your companions are seated with you.',
			),
			'seat_one'              => array( 'fa' => 'فقط خودم', 'en' => 'Just me' ),
			'seat_n'                => array( 'fa' => '%s نفر', 'en' => '%s people' ),
			'confirm_reserve'       => array( 'fa' => 'تایید رزرو', 'en' => 'Confirm' ),
			'only_n_seats_left'     => array(
				'fa' => 'فقط %s صندلی خالی مانده است.',
				'en' => 'Only %s seat(s) left.',
			),
			'party_max_seats'       => array(
				'fa' => 'بزرگ‌ترین میز این دورهمی %s صندلی دارد و همراهان باید کنار هم بنشینند.',
				'en' => 'The largest table here seats %s, and a party is always seated together.',
			),
			'seats_booked'          => array( 'fa' => '%s صندلی رزرو شد', 'en' => '%s seats reserved' ),
			'event_theme'           => array( 'fa' => 'موضوع', 'en' => 'Theme' ),
			'joined_event'          => array( 'fa' => 'در صف این میز هستید', 'en' => 'You are in the queue' ),
			'event_full'            => array( 'fa' => 'ظرفیت تکمیل است', 'en' => 'Table is full' ),
			// Atmosphere, not price. The plugin never handles money, so these
			// describe how a café feels rather than what it costs. The stored
			// keys stay low/medium/high so no migration is needed.
			'budget_low'            => array( 'fa' => 'دنج', 'en' => 'Cosy' ),
			'budget_medium'         => array( 'fa' => 'معمولی', 'en' => 'Everyday' ),
			'budget_high'           => array( 'fa' => 'لاکچری', 'en' => 'Upscale' ),
			'atmosphere'            => array( 'fa' => 'حال و هوا', 'en' => 'Atmosphere' ),
			'status_open'           => array( 'fa' => 'باز', 'en' => 'Open' ),
			'status_matched'        => array( 'fa' => 'میز چیده شد', 'en' => 'Matched' ),
			'status_completed'      => array( 'fa' => 'برگزار شد', 'en' => 'Completed' ),
			'status_pending_admin'  => array( 'fa' => 'در انتظار تایید', 'en' => 'Pending review' ),
			'need_profile_first'    => array( 'fa' => 'ابتدا تست شخصیت‌شناسی ۳۰ ثانیه‌ای را کامل کنید.', 'en' => 'Please complete the 30-second personality test first.' ),

			// Venue popup.
			'venue_profile'         => array( 'fa' => 'پروفایل کافه', 'en' => 'Café profile' ),
			'venue_menu'            => array( 'fa' => 'منوی کافه', 'en' => 'Café menu' ),
			'menu_display_only'     => array( 'fa' => 'این منو فقط جهت مرور است؛ سفارش حضوری در کافه ثبت می‌شود.', 'en' => 'Menu is for browsing only — orders are placed in person at the café.' ),
			'quiet_hours'           => array( 'fa' => 'ساعات خلوت', 'en' => 'Quiet hours' ),
			'view_venue_profile'    => array( 'fa' => 'مشاهده پروفایل و منوی کافه', 'en' => 'View café profile & menu' ),
			'verified_venue'        => array( 'fa' => 'کافه تاییدشده', 'en' => 'Verified café' ),
			'guests_routed'         => array( 'fa' => 'مهمان هدایت‌شده', 'en' => 'guests routed' ),

			// Map.
			'map_title'             => array( 'fa' => 'کافه‌های نزدیک', 'en' => 'Nearby cafés' ),
			'nearby_location'       => array( 'fa' => 'موقعیت نزدیک', 'en' => 'Nearby Location' ),
			'map_hint'              => array( 'fa' => 'روی پین‌ها بزنید تا پروفایل کافه باز شود.', 'en' => 'Tap a pin to open the café profile.' ),
			'locating'              => array( 'fa' => 'در حال یافتن موقعیت شما…', 'en' => 'Finding your location…' ),
			'geo_denied'            => array( 'fa' => 'دسترسی به موقعیت مکانی رد شد. از تنظیمات مرورگر اجازه دهید.', 'en' => 'Location access denied. Allow it in your browser settings.' ),
			'geo_failed'            => array( 'fa' => 'موقعیت مکانی پیدا نشد. دوباره تلاش کنید.', 'en' => 'Could not determine your location. Please try again.' ),
			'geo_unsupported'       => array( 'fa' => 'مرورگر شما از موقعیت مکانی پشتیبانی نمی‌کند.', 'en' => 'Your browser does not support geolocation.' ),

			// Chats.
			'chats_title'           => array( 'fa' => 'گفتگوها', 'en' => 'Chats' ),
			'chat_groups'           => array( 'fa' => 'چت میزها', 'en' => 'Table chats' ),
			'chat_friends'          => array( 'fa' => 'چت دوستان', 'en' => 'Friend chats' ),
			'chat_placeholder'      => array( 'fa' => 'پیام خود را بنویسید…', 'en' => 'Write a message…' ),
			'no_groups'             => array( 'fa' => 'هنوز عضو هیچ میزی نشده‌اید.', 'en' => 'You are not seated at any table yet.' ),
			'no_friends'            => array( 'fa' => 'هنوز دوستی اضافه نکرده‌اید.', 'en' => 'You have not added any friends yet.' ),
			'system_message'        => array( 'fa' => 'پیام سیستم', 'en' => 'System message' ),

			// Profile.
			'profile_title'         => array( 'fa' => 'پروفایل من', 'en' => 'My Profile' ),
			'rating_score'          => array( 'fa' => 'امتیاز رفتاری', 'en' => 'Behaviour score' ),
			'events_attended'       => array( 'fa' => 'دورهمی حاضر شده', 'en' => 'Tables attended' ),
			'start_test'            => array( 'fa' => '🧠 شروع تست ۳۰ ثانیه‌ای', 'en' => '🧠 Take the 30-second test' ),
			'test_step'             => array( 'fa' => 'مرحله', 'en' => 'Step' ),
			'q_age'                 => array( 'fa' => 'سن شما چند است؟', 'en' => 'How old are you?' ),
			'q_gender'              => array( 'fa' => 'جنسیت', 'en' => 'Gender' ),
			'gender_male'           => array( 'fa' => 'آقا', 'en' => 'Male' ),
			'gender_female'         => array( 'fa' => 'خانم', 'en' => 'Female' ),
			'gender_other'          => array( 'fa' => 'ترجیح می‌دهم نگویم', 'en' => 'Prefer not to say' ),
			'q_extroversion'        => array( 'fa' => 'چقدر برون‌گرا هستید؟', 'en' => 'How extroverted are you?' ),
			'q_talkative'           => array( 'fa' => 'سبک مکالمه شما', 'en' => 'Your conversation style' ),
			'q_vibe'                => array( 'fa' => 'جو مکالمه دلخواه', 'en' => 'Preferred conversation vibe' ),
			'vibe_deep'             => array( 'fa' => 'عمیق و فلسفی', 'en' => 'Deep & thoughtful' ),
			'vibe_fun'              => array( 'fa' => 'شاد و سرگرم‌کننده', 'en' => 'Fun & light' ),
			'q_interests'           => array( 'fa' => 'علاقه‌مندی‌ها (چندتایی)', 'en' => 'Your interests (multi-select)' ),

			// --- personality test: the five traits added in 1.11.0 ---------
			'q_openness'            => array( 'fa' => 'با آدم‌های تازه چطور برخورد می‌کنید؟', 'en' => 'How do you approach new people?' ),
			'openness_low'          => array( 'fa' => 'محتاط', 'en' => 'Cautious' ),
			'openness_high'         => array( 'fa' => 'پذیرا', 'en' => 'Open' ),
			'q_humor'               => array( 'fa' => 'شوخ‌طبعی در گفتگو چه جایگاهی دارد؟', 'en' => 'How big a part does humour play for you?' ),
			'humor_low'             => array( 'fa' => 'جدی', 'en' => 'Serious' ),
			'humor_high'            => array( 'fa' => 'شوخ', 'en' => 'Playful' ),
			'q_energy'              => array( 'fa' => 'چه فضایی برایتان دلچسب‌تر است؟', 'en' => 'Which atmosphere suits you better?' ),
			'energy_low'            => array( 'fa' => 'دنج و آرام', 'en' => 'Quiet & cosy' ),
			'energy_high'           => array( 'fa' => 'پرشور و شلوغ', 'en' => 'Lively & buzzing' ),
			'q_planning'            => array( 'fa' => 'برنامه‌ریز هستید یا خودجوش؟', 'en' => 'Planner or spontaneous?' ),
			'planning_low'          => array( 'fa' => 'خودجوش', 'en' => 'Spontaneous' ),
			'planning_high'         => array( 'fa' => 'برنامه‌ریز', 'en' => 'Planner' ),
			'q_empathy'             => array( 'fa' => 'وقتی کسی حرف می‌زند، بیشتر…', 'en' => 'When someone is talking, you mostly…' ),
			'empathy_low'           => array( 'fa' => 'راه‌حل می‌دهم', 'en' => 'Offer solutions' ),
			'empathy_high'          => array( 'fa' => 'همدلی می‌کنم', 'en' => 'Listen and empathise' ),
			'test_intro_title'      => array( 'fa' => 'شخصیت‌شناسی هواتو', 'en' => 'Your Havato personality' ),
			'test_intro_body'       => array(
				'fa' => 'هفت سؤال کوتاه درباره‌ی سبک گفتگو و شخصیت شما. جواب درست و غلط ندارد؛ هرچه صادقانه‌تر باشید، هم‌میزی‌های بهتری پیشنهاد می‌شود.',
				'en' => 'Seven short questions about how you talk and connect. There are no right answers — the more honest you are, the better your table matches.',
			),
			'trait_openness'        => array( 'fa' => 'پذیرندگی', 'en' => 'Openness' ),
			'trait_humor'           => array( 'fa' => 'شوخ‌طبعی', 'en' => 'Humour' ),
			'trait_energy'          => array( 'fa' => 'انرژی', 'en' => 'Energy' ),
			'trait_planning'        => array( 'fa' => 'برنامه‌ریزی', 'en' => 'Planning' ),
			'trait_empathy'         => array( 'fa' => 'همدلی', 'en' => 'Empathy' ),

			// --- personal details editor -----------------------------------
			'edit_details'          => array( 'fa' => '✏️ ویرایش مشخصات من', 'en' => '✏️ Edit my details' ),
			'details_title'         => array( 'fa' => 'مشخصات من', 'en' => 'My details' ),
			'details_hint'          => array(
				'fa' => 'این اطلاعات برای پیدا کردن دورهمی‌های نزدیک شما استفاده می‌شود و هر زمان قابل ویرایش است.',
				'en' => 'Used to find gatherings near you. You can change these at any time.',
			),
			'q_name'                => array( 'fa' => 'نام نمایشی', 'en' => 'Display name' ),
			'details_saved'         => array( 'fa' => 'مشخصات شما ذخیره شد.', 'en' => 'Your details were saved.' ),
			'details_needed'        => array(
				'fa' => 'برای دیدن دورهمی‌های شهرتان، ابتدا مشخصاتتان را کامل کنید.',
				'en' => 'Complete your details to see gatherings in your city.',
			),
			'err_name_short'        => array( 'fa' => 'نام باید حداقل ۲ حرف باشد.', 'en' => 'Your name needs at least 2 characters.' ),
			'err_age_range'         => array( 'fa' => 'سن باید بین ۱۸ تا ۷۵ سال باشد.', 'en' => 'Age must be between 18 and 75.' ),
			'q_city'                => array( 'fa' => 'محله / منطقه', 'en' => 'Neighborhood' ),
			'q_country'             => array( 'fa' => 'کشور', 'en' => 'Country' ),
			'q_city_select'         => array( 'fa' => 'شهر', 'en' => 'City' ),
			'q_neighborhood'        => array( 'fa' => 'محله (اختیاری)', 'en' => 'Neighborhood (optional)' ),
			'city_empty'            => array( 'fa' => 'فعلاً در شهر شما دورهمی‌ای ثبت نشده است.', 'en' => 'No tables in your city yet.' ),
			'listener'              => array( 'fa' => 'شنونده', 'en' => 'Listener' ),
			'speaker'               => array( 'fa' => 'گوینده', 'en' => 'Speaker' ),
			'introvert'             => array( 'fa' => 'درون‌گرا', 'en' => 'Introvert' ),
			'extrovert'             => array( 'fa' => 'برون‌گرا', 'en' => 'Extrovert' ),
			'behaviour_id'          => array( 'fa' => 'شناسنامه رفتاری', 'en' => 'Behaviour profile' ),
			'test_done'             => array( 'fa' => 'تست شخصیت‌شناسی شما ثبت شد.', 'en' => 'Your personality profile has been saved.' ),
			'gallery'               => array( 'fa' => 'گالری عکس', 'en' => 'Photo gallery' ),
			'gallery_locked'        => array( 'fa' => 'گالری عکس فقط برای دوستان تاییدشده قابل مشاهده است.', 'en' => 'The photo gallery is only visible to accepted friends.' ),
			'upload_photo'          => array( 'fa' => '＋ آپلود عکس', 'en' => '＋ Upload photo' ),
			'like'                  => array( 'fa' => 'لایک', 'en' => 'Like' ),
			'report'                => array( 'fa' => 'گزارش تخلف', 'en' => 'Report' ),
			'report_reason'         => array( 'fa' => 'دلیل گزارش', 'en' => 'Reason for report' ),
			'reason_nudity'         => array( 'fa' => 'محتوای نامناسب', 'en' => 'Inappropriate content' ),
			'reason_fake'           => array( 'fa' => 'عکس جعلی / متعلق به دیگری', 'en' => 'Fake or stolen photo' ),
			'reason_spam'           => array( 'fa' => 'تبلیغات و اسپم', 'en' => 'Spam or advertising' ),
			'reason_other'          => array( 'fa' => 'سایر موارد', 'en' => 'Other' ),
			'report_sent'           => array( 'fa' => 'گزارش شما ثبت شد و بررسی می‌شود.', 'en' => 'Your report has been submitted for review.' ),
			'photo_pending'         => array( 'fa' => 'در انتظار تایید', 'en' => 'Pending approval' ),
			'add_friend'            => array( 'fa' => '➕ افزودن دوست', 'en' => '➕ Add friend' ),
			'friend_pending'        => array( 'fa' => 'درخواست ارسال شد', 'en' => 'Request sent' ),
			'friend_accepted'       => array( 'fa' => 'دوست شما', 'en' => 'Your friend' ),
			'friend_requests'       => array( 'fa' => 'درخواست‌های دوستی', 'en' => 'Friend requests' ),
			'accept'                => array( 'fa' => 'پذیرفتن', 'en' => 'Accept' ),
			'reject'                => array( 'fa' => 'رد کردن', 'en' => 'Reject' ),
			'blocked_user'          => array( 'fa' => 'دسترسی به این کاربر مسدود است.', 'en' => 'This user is blocked.' ),
			'my_events'             => array( 'fa' => 'تاریخچه دورهمی‌ها', 'en' => 'Event history' ),

			// Feedback.
			'feedback_title'        => array( 'fa' => 'نظرسنجی پس از دورهمی', 'en' => 'Post-event feedback' ),
			'feedback_intro'        => array( 'fa' => 'تجربه‌ات از هم‌میزی‌ها چطور بود؟', 'en' => 'How was your experience with your table mates?' ),
			'feedback_comment'      => array( 'fa' => 'نظر شما (اختیاری)', 'en' => 'Your comment (optional)' ),
			'feedback_block'        => array( 'fa' => 'مسدودسازی این کاربر برای دورهمی‌های بعدی', 'en' => 'Block this user from future tables' ),
			'feedback_sent'         => array( 'fa' => 'ممنون! نظر شما ثبت شد.', 'en' => 'Thanks! Your feedback was recorded.' ),
			'feedback_pending'      => array( 'fa' => 'یک نظرسنجی در انتظار شماست', 'en' => 'You have a pending feedback' ),

			// Owner portal.
			'owner_login_title'     => array( 'fa' => 'پورتال صاحبان کافه', 'en' => 'Café owner portal' ),
			'owner_panel'           => array( 'fa' => 'پنل کافه', 'en' => 'Café panel' ),
			'owner_signin'          => array( 'fa' => 'ورود', 'en' => 'Sign in' ),
			'owner_signup'          => array( 'fa' => 'ثبت‌نام کافه', 'en' => 'Register café' ),
			'email'                 => array( 'fa' => 'ایمیل', 'en' => 'Email' ),
			'password'              => array( 'fa' => 'رمز عبور', 'en' => 'Password' ),
			'venue_name'            => array( 'fa' => 'نام کافه', 'en' => 'Café name' ),
			'manager_name'          => array( 'fa' => 'نام مدیر کافه/رستوران', 'en' => 'Café manager name' ),
			'venue_address'         => array( 'fa' => 'آدرس', 'en' => 'Address' ),
			'owner_pending_notice'  => array( 'fa' => 'کافه شما در انتظار تایید مدیریت است؛ تا تایید نهایی برای کاربران نمایش داده نمی‌شود.', 'en' => 'Your café is pending administrator approval and is hidden from users until verified.' ),
			'utilization'           => array( 'fa' => 'بهره‌وری', 'en' => 'Utilization' ),
			'members_at_table'      => array( 'fa' => 'اعضای این میز', 'en' => 'Members at this table' ),
			'check_in'              => array( 'fa' => '✅ حضور تایید شد', 'en' => '✅ Checked in' ),
			'not_checked_in'        => array( 'fa' => 'ثبت حضور', 'en' => 'Check in' ),
			'menu_item_name'        => array( 'fa' => 'نام محصول', 'en' => 'Item name' ),
			'menu_item_price'       => array( 'fa' => 'قیمت (تومان)', 'en' => 'Price (Toman)' ),
			'menu_item_desc'        => array( 'fa' => 'توضیحات (اختیاری)', 'en' => 'Description (optional)' ),
			'menu_item_image'       => array( 'fa' => 'عکس محصول', 'en' => 'Item photo' ),
			'add_item'              => array( 'fa' => 'افزودن محصول', 'en' => 'Add item' ),
			'menu_pending_badge'    => array( 'fa' => '⏳ در انتظار تایید مدیریت کل', 'en' => '⏳ Pending head-office approval' ),
			'menu_saved_pending'    => array( 'fa' => 'منو ذخیره شد و برای تایید ارسال گردید.', 'en' => 'Menu saved and submitted for approval.' ),
			'drag_pin'              => array( 'fa' => 'پین را روی موقعیت دقیق کافه بکشید (ذخیره خودکار).', 'en' => 'Drag the pin to your exact location (auto-saved).' ),
			'cover_image'           => array( 'fa' => 'عکس کاور', 'en' => 'Cover image' ),

			// Admin.
			'admin_dashboard'       => array( 'fa' => 'داشبورد آمار', 'en' => 'Statistics dashboard' ),
			'admin_approvals'       => array( 'fa' => 'تایید صلاحیت و منوها', 'en' => 'Approvals & menus' ),
			'admin_events'          => array( 'fa' => 'رویدادها و اعضا', 'en' => 'Events & guests' ),
			'admin_venues'          => array( 'fa' => 'همه کافه‌ها', 'en' => 'All cafés' ),
			'admin_import'          => array( 'fa' => 'افزودن گروهی کافه', 'en' => 'Bulk import cafés' ),
			'import_hint'           => array( 'fa' => 'لیست کافه‌ها را به‌صورت JSON اینجا بچسبانید. هر آیتم باید name، city، latitude و longitude داشته باشد. کافه‌های تکراری دوباره ساخته نمی‌شوند.', 'en' => 'Paste a JSON list of cafés. Each item needs name, city, latitude and longitude. Duplicates are skipped.' ),
			'import_cities'         => array( 'fa' => 'شهرهای مجاز:', 'en' => 'Supported cities:' ),
			'import_verified'       => array( 'fa' => 'کافه‌ها بلافاصله تاییدشده و برای کاربران قابل مشاهده باشند', 'en' => 'Publish immediately (verified and visible to guests)' ),
			'import_run'            => array( 'fa' => 'افزودن کافه‌ها', 'en' => 'Import cafés' ),
			'import_done'           => array( 'fa' => '%d کافه اضافه شد، %d مورد تکراری رد شد.', 'en' => '%d cafés added, %d duplicates skipped.' ),
			'import_bad_json'       => array( 'fa' => 'ساختار JSON نامعتبر است.', 'en' => 'Invalid JSON.' ),
			'import_failed_rows'    => array( 'fa' => 'ردیف‌های ناموفق', 'en' => 'Failed rows' ),
			'demo_title'            => array( 'fa' => 'محتوای نمونه', 'en' => 'Demo content' ),
			'demo_hint'             => array( 'fa' => 'کافه‌های نمونه تهران، اصفهان و استانبول به‌همراه میز و دورهمی ساخته می‌شوند تا بتوانید کل جریان را امتحان کنید. با دکمه حذف، فقط همین محتوای نمونه پاک می‌شود و کافه‌های واقعی دست‌نخورده می‌مانند.', 'en' => 'Creates sample cafés in Tehran, Isfahan and Istanbul with tables and events so you can walk through the whole flow. Removing it deletes only this sample data — real cafés are never touched.' ),
			'demo_create'           => array( 'fa' => 'ساخت محتوای نمونه', 'en' => 'Generate demo content' ),
			'demo_remove'           => array( 'fa' => 'حذف محتوای نمونه', 'en' => 'Delete demo content' ),
			'demo_confirm'          => array( 'fa' => 'همه کافه‌ها و دورهمی‌های نمونه حذف شوند؟ کافه‌های واقعی حذف نمی‌شوند.', 'en' => 'Delete all demo cafés and events? Real cafés will not be removed.' ),
			'demo_present'          => array( 'fa' => 'هم‌اکنون %d کافه و %d دورهمی نمونه موجود است', 'en' => 'Currently %d demo cafés and %d demo events' ),
			'demo_created'          => array( 'fa' => '%d کافه و %d دورهمی نمونه ساخته شد (%d مورد تکراری رد شد).', 'en' => 'Created %d demo cafés and %d demo events (%d duplicates skipped).' ),
			'demo_removed'          => array( 'fa' => '%d کافه و %d دورهمی نمونه حذف شد.', 'en' => 'Removed %d demo cafés and %d demo events.' ),
			'demo_none'             => array( 'fa' => 'محتوای نمونه‌ای برای حذف وجود ندارد.', 'en' => 'There is no demo content to remove.' ),
			'event_title'           => array( 'fa' => 'عنوان دورهمی', 'en' => 'Event title' ),
			'event_title_hint'      => array( 'fa' => 'مثلاً: شب فیلم، گپ استارتاپی', 'en' => 'e.g. Movie night, Startup talk' ),
			'admin_matcher'         => array( 'fa' => 'اجرای تطابق هوشمند', 'en' => 'Run smart matching' ),
			'admin_weights'         => array( 'fa' => 'تنظیم ضرایب فرمول', 'en' => 'Formula weights' ),
			'admin_google'          => array( 'fa' => 'تنظیمات ورود با گوگل', 'en' => 'Google sign-in' ),
			'admin_locale'          => array( 'fa' => 'تنظیمات زبان و منطقه', 'en' => 'Language & region' ),
			'admin_theme'           => array( 'fa' => 'ظاهر و تم', 'en' => 'Appearance & theme' ),
			'theme_intro'           => array(
				'fa' => 'یک تم را انتخاب کنید تا رنگ‌بندی کل اپلیکیشن تغییر کند. تغییر آنی است و روی داده‌ها اثری ندارد.',
				'en' => 'Pick a theme to repaint the whole app. The change is instant and touches no data.',
			),
			'theme_active'          => array( 'fa' => 'تم فعال', 'en' => 'Active theme' ),
			'theme_apply'           => array( 'fa' => 'اعمال این تم', 'en' => 'Apply this theme' ),
			'theme_applied'         => array( 'fa' => 'تم با موفقیت تغییر کرد.', 'en' => 'Theme changed successfully.' ),
			'theme_in_use'          => array( 'fa' => 'در حال استفاده', 'en' => 'In use' ),
			'theme_custom'          => array( 'fa' => 'تم دلخواه', 'en' => 'Custom theme' ),
			'theme_custom_hint'     => array(
				'fa' => 'فقط رنگ اصلی را انتخاب کنید؛ بقیه‌ی سایه‌ها خودکار ساخته می‌شوند. اگر رنگ برای متن سفید روشن باشد، خودکار تیره‌تر می‌شود.',
				'en' => 'Pick the main colour; every other shade is derived. Too light for white text? It is darkened automatically.',
			),
			'theme_base_colour'     => array( 'fa' => 'رنگ اصلی', 'en' => 'Main colour' ),
			'theme_accent_colour'   => array( 'fa' => 'رنگ دکمه شناور', 'en' => 'Accent (floating button)' ),
			'theme_preview'         => array( 'fa' => 'پیش‌نمایش', 'en' => 'Preview' ),
			'theme_contrast'        => array( 'fa' => 'کنتراست متن سفید', 'en' => 'White-text contrast' ),
			'theme_contrast_ok'     => array( 'fa' => 'قابل قبول', 'en' => 'Passes AA' ),
			'theme_developer_note'  => array(
				'fa' => 'توسعه‌دهندگان می‌توانند با فیلتر havato_themes تم جدید اضافه کنند؛ تم بدون هیچ تغییر دیگری در این صفحه ظاهر می‌شود.',
				'en' => 'Developers can register more themes with the havato_themes filter; they appear here automatically.',
			),
			'stat_active_users'     => array( 'fa' => 'کاربران فعال', 'en' => 'Active users' ),
			'stat_matched_tables'   => array( 'fa' => 'میزهای مطابقت‌یافته', 'en' => 'Matched tables' ),
			'stat_venues'           => array( 'fa' => 'مکان‌های ثبت‌شده', 'en' => 'Registered venues' ),
			'stat_signups'          => array( 'fa' => 'ثبت‌نام‌ها', 'en' => 'Sign-ups' ),
			'stat_attended'         => array( 'fa' => 'دورهمی‌های حاضر شده', 'en' => 'Gatherings attended' ),
			'rating_count'          => array( 'fa' => 'تعداد بازخوردها', 'en' => 'Ratings received' ),
			'col_order'             => array( 'fa' => 'ترتیب', 'en' => 'Order' ),
			'col_manager'           => array( 'fa' => 'مدیر', 'en' => 'Manager' ),
			'col_location'          => array( 'fa' => 'مکان', 'en' => 'Location' ),
			'col_status'            => array( 'fa' => 'وضعیت', 'en' => 'Status' ),
			'badge_pending'         => array( 'fa' => 'در انتظار تایید', 'en' => 'Pending' ),
			'verify_action'         => array( 'fa' => '✓ تایید صلاحیت', 'en' => '✓ Verify' ),
			'weight_location'       => array( 'fa' => 'وزن مکان', 'en' => 'Location weight' ),
			'weight_time'           => array( 'fa' => 'وزن زمان پیشنهادی', 'en' => 'Suggested-time weight' ),
			'weight_density'        => array( 'fa' => 'تراکم مکان', 'en' => 'Venue density' ),
			'live_console'          => array( 'fa' => 'کنسول زنده موتور تطابق', 'en' => 'Live matcher console' ),
			'havato_role'           => array( 'fa' => 'نقش هواتو', 'en' => 'Havato role' ),
			'venue_status'          => array( 'fa' => 'وضعیت کافه', 'en' => 'Café status' ),
		);

		/**
		 * Allow third parties / child plugins to extend or override strings.
		 *
		 * @param array $map Key => [fa, en].
		 */
		self::$map = apply_filters( 'havato_i18n_map', self::$map );

		return self::$map;
	}
}
