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
			'yes'                   => array( 'fa' => 'بله', 'en' => 'Yes' ),
			'no'                    => array( 'fa' => 'خیر', 'en' => 'No' ),
			'lang_switch'           => array( 'fa' => 'English', 'en' => 'فارسی' ),
			'lang_label'            => array( 'fa' => 'زبان', 'en' => 'Language' ),

			// Auth wall.
			'auth_title'            => array( 'fa' => 'به هواتو خوش آمدید', 'en' => 'Welcome to Havato' ),
			'auth_sub'              => array( 'fa' => 'با آدم‌های هم‌فرکانس خودت، سر یک میز در بهترین کافه‌های شهر بنشین.', 'en' => 'Sit at one table with people who match your vibe, in the best cafés in town.' ),
			'login_google'          => array( 'fa' => 'ورود با حساب گوگل', 'en' => 'Continue with Google' ),
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
			'tab_venue_settings'    => array( 'fa' => 'تنظیمات کافه', 'en' => 'Venue Settings' ),

			// Explore.
			'explore_title'         => array( 'fa' => 'دورهمی‌های این هفته', 'en' => 'This week’s tables' ),
			'explore_empty'         => array( 'fa' => 'فعلاً دورهمی بازی ثبت نشده است.', 'en' => 'No open tables right now.' ),
			'seats_left'            => array( 'fa' => 'صندلی خالی', 'en' => 'seats left' ),
			'join_event'            => array( 'fa' => 'درخواست هم‌نشینی موضوعی', 'en' => 'Request a seat' ),
			'joined_event'          => array( 'fa' => 'در صف این میز هستید', 'en' => 'You are in the queue' ),
			'event_full'            => array( 'fa' => 'ظرفیت تکمیل است', 'en' => 'Table is full' ),
			'budget_low'            => array( 'fa' => 'اقتصادی', 'en' => 'Budget' ),
			'budget_medium'         => array( 'fa' => 'متوسط', 'en' => 'Standard' ),
			'budget_high'           => array( 'fa' => 'لاکچری', 'en' => 'Premium' ),
			'status_open'           => array( 'fa' => 'باز', 'en' => 'Open' ),
			'status_matched'        => array( 'fa' => 'میز چیده شد', 'en' => 'Matched' ),
			'status_completed'      => array( 'fa' => 'برگزار شد', 'en' => 'Completed' ),
			'status_pending_admin'  => array( 'fa' => 'در انتظار تایید', 'en' => 'Pending review' ),
			'redirect_payment'      => array( 'fa' => 'در حال انتقال به درگاه پرداخت…', 'en' => 'Redirecting to secure checkout…' ),
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
			'wallet'                => array( 'fa' => 'کیف پول', 'en' => 'Wallet' ),
			'wallet_spent'          => array( 'fa' => 'مجموع پرداخت‌ها', 'en' => 'Total spent' ),
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
			'q_city'                => array( 'fa' => 'محله / منطقه', 'en' => 'Neighborhood' ),
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
			'payout_status'         => array( 'fa' => 'وضعیت تسویه', 'en' => 'Payout status' ),
			'payout_period'         => array( 'fa' => 'دوره', 'en' => 'Period' ),
			'payout_gross'          => array( 'fa' => 'فروش ناخالص', 'en' => 'Gross sales' ),
			'payout_commission'     => array( 'fa' => 'کارمزد پلتفرم', 'en' => 'Platform fee' ),
			'payout_share'          => array( 'fa' => 'سهم کافه', 'en' => 'Café share' ),
			'payout_paid'           => array( 'fa' => 'تسویه‌شده', 'en' => 'Paid' ),
			'payout_due'            => array( 'fa' => 'بدهکار', 'en' => 'Due' ),

			// Admin.
			'admin_dashboard'       => array( 'fa' => 'داشبورد آمار', 'en' => 'Statistics dashboard' ),
			'admin_approvals'       => array( 'fa' => 'تایید صلاحیت و منوها', 'en' => 'Approvals & menus' ),
			'admin_matcher'         => array( 'fa' => 'اجرای تطابق هوشمند', 'en' => 'Run smart matching' ),
			'admin_revenue'         => array( 'fa' => 'درآمد و تسویه', 'en' => 'Revenue & settlements' ),
			'revenue_by_event'      => array( 'fa' => 'درآمد رویدادها', 'en' => 'Revenue by event' ),
			'admin_weights'         => array( 'fa' => 'تنظیم ضرایب فرمول', 'en' => 'Formula weights' ),
			'admin_google'          => array( 'fa' => 'تنظیمات ورود با گوگل', 'en' => 'Google sign-in' ),
			'admin_locale'          => array( 'fa' => 'تنظیمات زبان و منطقه', 'en' => 'Language & region' ),
			'stat_active_users'     => array( 'fa' => 'کاربران فعال', 'en' => 'Active users' ),
			'stat_matched_tables'   => array( 'fa' => 'میزهای مطابقت‌یافته', 'en' => 'Matched tables' ),
			'stat_venues'           => array( 'fa' => 'مکان‌های ثبت‌شده', 'en' => 'Registered venues' ),
			'stat_revenue'          => array( 'fa' => 'فروش بلیت', 'en' => 'Ticket revenue' ),
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
