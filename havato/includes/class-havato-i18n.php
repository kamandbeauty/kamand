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
			'tr' => array(
				'label' => 'Türkçe',
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
		if ( 0 === strpos( $lang, 'tr' ) ) {
			return 'tr';
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

			// No explicit choice yet: fall back to the language of the
			// country the guest selected in their profile, so a Turkish user
			// lands on a Turkish panel instead of a Persian one. An explicit
			// switch is stored in user meta above and always wins.
			$by_country = self::country_language( $user_id );
			if ( $by_country ) {
				return $by_country;
			}
		}

		if ( isset( $_COOKIE['havato_lang'] ) ) {
			return self::sanitize_lang( wp_unslash( $_COOKIE['havato_lang'] ) );
		}

		$default = get_option( 'havato_default_lang', 'fa' );
		return self::sanitize_lang( $default );
	}

	/**
	 * Default language implied by a user's selected country.
	 *
	 * Only a hint: it is consulted after an explicit preference, never
	 * before, so switching language always sticks.
	 *
	 * @param int $user_id User id.
	 * @return string Language code, or '' when there is nothing to infer.
	 */
	public static function country_language( $user_id ) {
		if ( ! $user_id || ! function_exists( 'havato_get_profile' ) ) {
			return '';
		}

		// Guard against recursion: havato_get_profile() runs a query, and
		// current_lang() can be reached from almost anywhere.
		static $busy = false;
		if ( $busy ) {
			return '';
		}

		$busy    = true;
		$profile = havato_get_profile( $user_id );
		$busy    = false;

		$country = isset( $profile['country'] ) ? (string) $profile['country'] : '';

		/**
		 * Map a country to its default interface language.
		 *
		 * @param array $map Country key => language code.
		 */
		$map = apply_filters(
			'havato_country_languages',
			array(
				'tr' => 'tr',
				'ir' => 'fa',
			)
		);

		return isset( $map[ $country ] ) ? self::sanitize_lang( $map[ $country ] ) : '';
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
		$out = array();
		foreach ( array_keys( self::languages() ) as $code ) {
			$out[ $code ] = self::flat( $code );
		}
		return $out;
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
			'app_name'              => array( 'fa' => 'هواتو', 'en' => 'Havato', 'tr' => 'Havato' ),
			'tagline'               => array( 'fa' => 'دورهمی‌های هوشمند در کافه‌های شهر', 'en' => 'Smart social tables in your city', 'tr' => 'Şehrinizde akıllı sosyal masalar' ),
			'loading'               => array( 'fa' => 'در حال بارگذاری…', 'en' => 'Loading…', 'tr' => 'Yükleniyor…' ),
			'uploading'             => array( 'fa' => 'در حال آپلود…', 'en' => 'Uploading…', 'tr' => 'Yükleniyor…' ),
			'uploading_photo'       => array( 'fa' => 'در حال آپلود عکس…', 'en' => 'Uploading photo…', 'tr' => 'Fotoğraf yükleniyor…' ),
			'uploading_avatar'      => array( 'fa' => 'در حال آپلود عکس پروفایل…', 'en' => 'Uploading profile photo…', 'tr' => 'Profil fotoğrafı yükleniyor…' ),
			'uploading_cover'       => array( 'fa' => 'در حال آپلود عکس کاور…', 'en' => 'Uploading cover photo…', 'tr' => 'Kapak fotoğrafı yükleniyor…' ),
			'upload_cancelled'      => array( 'fa' => 'آپلود لغو شد', 'en' => 'Upload cancelled', 'tr' => 'Yükleme iptal edildi' ),
			'saving'                => array( 'fa' => 'در حال ذخیره…', 'en' => 'Saving…', 'tr' => 'Kaydediliyor…' ),
			'save'                  => array( 'fa' => 'ذخیره', 'en' => 'Save', 'tr' => 'Kaydet' ),
			'saved'                 => array( 'fa' => 'ذخیره شد', 'en' => 'Saved', 'tr' => 'Kaydedildi' ),
			'cancel'                => array( 'fa' => 'انصراف', 'en' => 'Cancel', 'tr' => 'İptal' ),
			'close'                 => array( 'fa' => 'بستن', 'en' => 'Close', 'tr' => 'Kapat' ),
			'send'                  => array( 'fa' => 'ارسال', 'en' => 'Send', 'tr' => 'Gönder' ),
			'submit'                => array( 'fa' => 'ثبت', 'en' => 'Submit', 'tr' => 'Gönder' ),
			'back'                  => array( 'fa' => 'بازگشت', 'en' => 'Back', 'tr' => 'Geri' ),
			'next'                  => array( 'fa' => 'بعدی', 'en' => 'Next', 'tr' => 'İleri' ),
			'prev'                  => array( 'fa' => 'قبلی', 'en' => 'Previous', 'tr' => 'Önceki' ),
			'finish'                => array( 'fa' => 'پایان', 'en' => 'Finish', 'tr' => 'Bitir' ),
			'confirm'               => array( 'fa' => 'تایید', 'en' => 'Confirm', 'tr' => 'Onayla' ),
			'delete'                => array( 'fa' => 'حذف', 'en' => 'Delete', 'tr' => 'Sil' ),
			'edit'                  => array( 'fa' => 'ویرایش', 'en' => 'Edit', 'tr' => 'Düzenle' ),
			'search'                => array( 'fa' => 'جستجو', 'en' => 'Search', 'tr' => 'Ara' ),
			'filter'                => array( 'fa' => 'فیلتر', 'en' => 'Filter', 'tr' => 'Filtrele' ),
			'error_generic'         => array( 'fa' => 'خطایی رخ داد. دوباره تلاش کنید.', 'en' => 'Something went wrong. Please retry.', 'tr' => 'Bir şeyler ters gitti. Lütfen tekrar deneyin.' ),
			'boot_failed'           => array( 'fa' => 'ارتباط با سرور برقرار نشد', 'en' => 'Could not reach the server', 'tr' => 'Sunucuya ulaşılamadı' ),
			'retry'                 => array( 'fa' => 'تلاش دوباره', 'en' => 'Try again', 'tr' => 'Tekrar dene' ),
			'empty_state'           => array( 'fa' => 'فعلاً چیزی برای نمایش نیست.', 'en' => 'Nothing here yet.', 'tr' => 'Burada henüz bir şey yok.' ),
			'toman'                 => array( 'fa' => 'تومان', 'en' => 'Toman', 'tr' => 'Tümen' ),
			'lira'                  => array( 'fa' => 'لیر', 'en' => 'Lira', 'tr' => 'TL' ),
			'free'                  => array( 'fa' => 'رایگان', 'en' => 'Free', 'tr' => 'Ücretsiz' ),
			'always_free'           => array( 'fa' => 'شرکت در همه‌ی دورهمی‌ها رایگان است.', 'en' => 'Every gathering is free to join.', 'tr' => 'Tüm buluşmalara katılım ücretsizdir.' ),
			'need_details_first'    => array(
				'fa' => 'برای ثبت‌نام، ابتدا مشخصات خود را در پروفایل کامل کنید.',
				'en' => 'Complete your details on your profile before joining.',
				'tr' => 'Katılmadan önce profilinizdeki bilgileri tamamlayın.',
			),
			'yes'                   => array( 'fa' => 'بله', 'en' => 'Yes', 'tr' => 'Evet' ),
			'no'                    => array( 'fa' => 'خیر', 'en' => 'No', 'tr' => 'Hayır' ),
			'lang_switch'           => array( 'fa' => 'English', 'en' => 'فارسی', 'tr' => 'Türkçe' ),
			'lang_label'            => array( 'fa' => 'زبان', 'en' => 'Language', 'tr' => 'Dil' ),

			// Auth wall.
			'auth_title'            => array( 'fa' => 'به هواتو خوش آمدید', 'en' => 'Welcome to Havato', 'tr' => 'Havato’ya hoş geldiniz' ),
			'auth_sub'              => array( 'fa' => 'با آدم‌های هم‌فرکانس خودت، سر یک میز در بهترین کافه‌های شهر بنشین.', 'en' => 'Sit at one table with people who match your vibe, in the best cafés in town.', 'tr' => 'Şehrin en iyi kafelerinde, size uyan insanlarla aynı masada oturun.' ),
			'login_google'          => array( 'fa' => 'ورود با حساب گوگل', 'en' => 'Continue with Google', 'tr' => 'Google ile devam et' ),
			'user_login_heading'    => array( 'fa' => 'ورود کاربر', 'en' => 'User sign-in', 'tr' => 'Kullanıcı girişi' ),
			'login_failed'          => array( 'fa' => 'ایمیل یا رمز عبور نادرست است.', 'en' => 'Incorrect email or password.', 'tr' => 'E-posta veya şifre hatalı.' ),
			'login_owner_only'      => array( 'fa' => 'این صفحه فقط برای صاحبان کافه است.', 'en' => 'This page is for café owners only.', 'tr' => 'Bu sayfa yalnızca kafe sahipleri içindir.' ),
			'login_throttled'       => array( 'fa' => 'تلاش‌های ناموفق زیاد. ۱۵ دقیقه دیگر دوباره تلاش کنید.', 'en' => 'Too many attempts. Please try again in 15 minutes.', 'tr' => 'Çok fazla deneme. Lütfen 15 dakika sonra tekrar deneyin.' ),
			'forgot_password'       => array( 'fa' => 'رمز عبور را فراموش کرده‌اید؟', 'en' => 'Forgot your password?', 'tr' => 'Şifrenizi mi unuttunuz?' ),
			'signup_pending_hint'   => array( 'fa' => 'پس از ثبت‌نام، کافه شما تا تایید مدیریت برای کاربران نمایش داده نمی‌شود.', 'en' => 'After signing up your café stays hidden from guests until an administrator approves it.', 'tr' => 'Kaydolduktan sonra kafeniz, yönetici onaylayana kadar misafirlere gösterilmez.' ),
			'storefront_title'      => array( 'fa' => 'عکس ورودی مغازه', 'en' => 'Photo of your shopfront', 'tr' => 'Dükkân cephesi fotoğrafı' ),
			'storefront_hint'       => array( 'fa' => 'برای تایید سریع‌تر کافه، یک عکس از ورودی مغازه آپلود کنید.', 'en' => 'Upload a photo of your entrance to get verified faster.', 'tr' => 'Daha hızlı onaylanmak için girişinizin fotoğrafını yükleyin.' ),
			'storefront_received'   => array( 'fa' => 'عکس دریافت شد و در حال بررسی است.', 'en' => 'Photo received — it is being reviewed.', 'tr' => 'Fotoğraf alındı — inceleniyor.' ),
			'login_owner'           => array( 'fa' => '🔑 ورود صاحبین کافه', 'en' => '🔑 Café owner sign-in', 'tr' => '🔑 Kafe sahibi girişi' ),
			'register_partner'      => array( 'fa' => '💼 ثبت‌نام کافه شریک', 'en' => '💼 Become a partner café', 'tr' => '💼 Partner kafe olun' ),
			'google_not_configured' => array( 'fa' => 'ورود با گوگل هنوز توسط مدیر پیکربندی نشده است.', 'en' => 'Google sign-in has not been configured by the administrator yet.', 'tr' => 'Google girişi yönetici tarafından henüz yapılandırılmadı.' ),
			'logout'                => array( 'fa' => 'خروج از حساب', 'en' => 'Sign out', 'tr' => 'Çıkış yap' ),

			// Tabs (gatherer).
			'tab_home'              => array( 'fa' => 'خانه', 'en' => 'Home', 'tr' => 'Ana sayfa' ),
			'tab_my_tables'         => array( 'fa' => 'میزهای من', 'en' => 'My Tables', 'tr' => 'Masalarım' ),
			'home_greeting'         => array( 'fa' => 'خوش آمدی، %s', 'en' => 'Welcome back, %s', 'tr' => 'Tekrar hoş geldin, %s' ),
			'home_next_table'       => array( 'fa' => 'میز بعدی شما', 'en' => 'Your next table', 'tr' => 'Sıradaki masanız' ),
			'home_discover'         => array( 'fa' => 'کشف میزها', 'en' => 'Discover tables', 'tr' => 'Masaları keşfet' ),
			'quick_actions'         => array( 'fa' => 'عملیات سریع', 'en' => 'Quick actions', 'tr' => 'Hızlı işlemler' ),
			'activity_summary'      => array( 'fa' => 'خلاصه فعالیت', 'en' => 'Activity summary', 'tr' => 'Etkinlik özeti' ),
			'quick_browse'          => array( 'fa' => 'مرور دورهمی‌ها', 'en' => 'Browse gatherings', 'tr' => 'Buluşmalara göz at' ),
			'quick_host'            => array( 'fa' => 'میزبانی دورهمی', 'en' => 'Host a gathering', 'tr' => 'Buluşmaya ev sahipliği' ),
			'view_all'              => array( 'fa' => 'همه', 'en' => 'View all', 'tr' => 'Tümü' ),
			'tab_explore'           => array( 'fa' => 'کاوش', 'en' => 'Explore', 'tr' => 'Keşfet' ),
			'tab_map'               => array( 'fa' => 'نقشه', 'en' => 'Map', 'tr' => 'Harita' ),
			'tab_chats'             => array( 'fa' => 'گفتگوها', 'en' => 'Chats', 'tr' => 'Sohbetler' ),
			'tab_profile'           => array( 'fa' => 'پروفایل من', 'en' => 'My Profile', 'tr' => 'Profilim' ),

			/*
			 * Short forms, used ONLY by the five-tab bar.
			 *
			 * A tab gets one fifth of the screen — about 74px on a 375px
			 * phone, less the gutter. "My Tables" and "My Profile" do not
			 * fit and were ellipsised into "MY TABL…" / "MY PROF…", which
			 * reads as broken rather than abbreviated. Screen titles keep
			 * the possessive full form; only the bar drops it.
			 */
			'nav_tables'            => array( 'fa' => 'میزها', 'en' => 'Tables', 'tr' => 'Masalar' ),
			'nav_profile'           => array( 'fa' => 'پروفایل', 'en' => 'Profile', 'tr' => 'Profil' ),
			'dashboard_title'       => array( 'fa' => 'داشبورد من', 'en' => 'My dashboard', 'tr' => 'Panelim' ),
			'dash_upcoming'         => array( 'fa' => 'رزروهای پیش رو', 'en' => 'Upcoming bookings', 'tr' => 'Yaklaşan rezervasyonlar' ),
			'dash_requests'         => array( 'fa' => 'پیشنهادهای من', 'en' => 'My suggestions', 'tr' => 'Önerilerim' ),
			'dash_no_events'        => array( 'fa' => 'هنوز صندلی رزرو نکرده‌اید. از کاوش یک دورهمی انتخاب کنید.', 'en' => 'No seats booked yet. Pick a gathering from Explore.', 'tr' => 'Henüz koltuk ayırtmadınız. Keşfet\'ten bir buluşma seçin.' ),
			'dash_no_venues'        => array( 'fa' => 'هنوز کافه‌ای در شهر شما ثبت نشده است.', 'en' => 'No cafés in your city yet.', 'tr' => 'Şehrinizde henüz kafe yok.' ),
			'suggest_event'         => array( 'fa' => 'پیشنهاد دورهمی به کافه', 'en' => 'Suggest a gathering', 'tr' => 'Buluşma öner' ),
			'suggest_hint'          => array( 'fa' => 'روز و موضوع دلخواهتان را به کافه پیشنهاد بدهید. این یک رزرو نیست؛ تصمیم با کافه است.', 'en' => 'Tell a café which day and subject you would like. This is a suggestion, not a booking — the café decides.', 'tr' => 'Kafeye hangi gün ve konuyu istediğinizi söyleyin. Bu bir rezervasyon değil, bir öneridir; kararı kafe verir.' ),
			'send_request'          => array( 'fa' => 'ارسال پیشنهاد', 'en' => 'Send suggestion', 'tr' => 'Öneriyi gönder' ),
			'request_sent'          => array( 'fa' => 'پیشنهاد شما برای کافه ارسال شد.', 'en' => 'Your suggestion was sent to the café.', 'tr' => 'Öneriniz kafeye gönderildi.' ),
			'request_duplicate'     => array( 'fa' => 'برای همین کافه و همین روز قبلاً پیشنهاد داده‌اید.', 'en' => 'You have already suggested this café for that day.', 'tr' => 'Bu kafe için o güne zaten öneri gönderdiniz.' ),
			'request_past_date'     => array( 'fa' => 'روز انتخابی گذشته است.', 'en' => 'That day has already passed.', 'tr' => 'Seçilen gün geçmişte kalmış.' ),
			'request_other_city'    => array( 'fa' => 'فقط می‌توانید به کافه‌های شهر خودتان پیشنهاد بدهید.', 'en' => 'You can only suggest a gathering to a café in your own city.', 'tr' => 'Yalnızca kendi şehrinizdeki bir kafeye buluşma önerebilirsiniz.' ),
			'dash_set_city_first'   => array( 'fa' => 'برای پیشنهاد دورهمی، اول شهرتان را در مشخصات ثبت کنید.', 'en' => 'Set your city in your details before suggesting a gathering.', 'tr' => 'Buluşma önermeden önce bilgilerinizde şehrinizi belirtin.' ),
			'request_pending'       => array( 'fa' => 'در انتظار پاسخ', 'en' => 'Awaiting reply', 'tr' => 'Yanıt bekleniyor' ),
			'request_accepted'      => array( 'fa' => 'پذیرفته شد', 'en' => 'Accepted', 'tr' => 'Kabul edildi' ),
			'request_declined'      => array( 'fa' => 'پذیرفته نشد', 'en' => 'Declined', 'tr' => 'Reddedildi' ),
			'directions'            => array( 'fa' => 'مسیریابی', 'en' => 'Directions', 'tr' => 'Yol tarifi' ),
			'address_missing'       => array( 'fa' => 'کافه هنوز آدرس دقیقی ثبت نکرده است.', 'en' => 'The café has not written a full address yet.', 'tr' => 'Kafe henüz tam bir adres yazmadı.' ),
			'profile_photo'         => array( 'fa' => 'عکس پروفایل', 'en' => 'Profile photo', 'tr' => 'Profil fotoğrafı' ),
			'profile_photo_hint'    => array( 'fa' => 'هم‌میزی‌هایتان این عکس را کنار نام شما می‌بینند.', 'en' => 'Your table-mates see this beside your name.', 'tr' => 'Masa arkadaşlarınız bunu adınızın yanında görür.' ),
			'change_photo'          => array( 'fa' => 'تغییر عکس', 'en' => 'Change photo', 'tr' => 'Fotoğrafı değiştir' ),
			'venue_about'           => array( 'fa' => 'درباره این کافه', 'en' => 'About this café', 'tr' => 'Bu kafe hakkında' ),
			'venue_about_hint'      => array( 'fa' => 'در چند خط بنویسید کافه‌تان چه فضایی دارد؛ مهمان پیش از رزرو این را می‌خواند.', 'en' => 'A few lines on what your café is like — a guest reads this before booking.', 'tr' => 'Kafenizin nasıl bir yer olduğunu birkaç satırda yazın; misafir rezervasyondan önce bunu okur.' ),
			'guest_requests'        => array( 'fa' => 'پیشنهادهای مهمان‌ها', 'en' => 'Guest suggestions', 'tr' => 'Misafir önerileri' ),
			'guest_requests_hint'   => array( 'fa' => 'مهمان‌ها روز و موضوعی را پیشنهاد داده‌اند. با پذیرفتن، به فرم ساخت دورهمی می‌روید که از پیش پر شده است؛ تعداد صندلی را شما با انتخاب میزها تعیین می‌کنید.', 'en' => 'Guests have asked for a day and a subject. Accepting takes you to the event form, already filled in — you set the number of seats by choosing tables.', 'tr' => 'Misafirler bir gün ve konu istedi. Kabul ettiğinizde, önceden doldurulmuş etkinlik formuna gidersiniz; koltuk sayısını masaları seçerek siz belirlersiniz.' ),
			'admin_requests_hint'   => array( 'fa' => 'پیشنهادهای مهمان‌ها به همه کافه‌ها. کافه‌ای که مدام پیشنهاد می‌گیرد ولی رویداد نمی‌سازد، ارزش یک تماس را دارد.', 'en' => 'Guest suggestions across every café. One that keeps receiving them and never creates a gathering is worth a phone call.', 'tr' => 'Tüm kafelere gelen misafir önerileri. Sürekli öneri alıp hiç buluşma oluşturmayan bir kafeyi aramaya değer.' ),
			'show_all'              => array( 'fa' => 'نمایش همه', 'en' => 'Show all', 'tr' => 'Tümünü göster' ),
			'show_pending'          => array( 'fa' => 'فقط در انتظار', 'en' => 'Pending only', 'tr' => 'Yalnızca bekleyenler' ),
			'request_accepted_pick_tables' => array( 'fa' => 'پیشنهاد پذیرفته شد. حالا میزهای این دورهمی را انتخاب کنید تا تعداد صندلی مشخص شود.', 'en' => 'Suggestion accepted. Now choose which tables to open for it — that sets the number of seats.', 'tr' => 'Öneri kabul edildi. Şimdi bu buluşma için hangi masaları açacağınızı seçin — koltuk sayısını bu belirler.' ),
			'request_prefilled'     => array( 'fa' => 'این فرم از روی پیشنهاد مهمان پر شده است. روز و موضوع را مهمان خواسته؛ تعداد صندلی را شما با انتخاب میزها تعیین می‌کنید.', 'en' => 'This form is filled in from a guest suggestion. The guest asked for the day and the subject; you set the number of seats by choosing tables.', 'tr' => 'Bu form bir misafir önerisinden dolduruldu. Gün ve konuyu misafir istedi; koltuk sayısını masaları seçerek siz belirlersiniz.' ),
			'request_accept'        => array( 'fa' => 'می‌پذیرم', 'en' => 'Accept', 'tr' => 'Kabul et' ),
			'request_decline'       => array( 'fa' => 'نمی‌پذیرم', 'en' => 'Decline', 'tr' => 'Reddet' ),
			'locate_me'             => array( 'fa' => 'موقعیت من', 'en' => 'My location', 'tr' => 'Konumum' ),

			// Tabs (owner).
			'tab_dashboard'         => array( 'fa' => 'داشبورد', 'en' => 'Dashboard', 'tr' => 'Panel' ),
			'tab_venue_events'      => array( 'fa' => 'رویدادهای کافه', 'en' => 'Venue Events', 'tr' => 'Mekân Etkinlikleri' ),
			'tab_menu_builder'      => array( 'fa' => 'ساخت منو', 'en' => 'Menu Builder', 'tr' => 'Menü Oluşturucu' ),
			'tab_tables'            => array( 'fa' => 'میزهای کافه', 'en' => 'My tables', 'tr' => 'Masalarım' ),
			'tables_hint'           => array( 'fa' => 'میزهای کافه را یک‌بار تعریف کنید؛ بعد برای هر دورهمی فقط تیک می‌زنید. ظرفیت خودکار حساب می‌شود.', 'en' => 'Define your tables once, then just tick them for each event — capacity is calculated automatically.', 'tr' => 'Masalarınızı bir kez tanımlayın, sonra her etkinlik için işaretlemeniz yeterli — kapasite otomatik hesaplanır.' ),
			'table_label'           => array( 'fa' => 'نام میز', 'en' => 'Table name', 'tr' => 'Masa adı' ),
			'table_label_hint'      => array( 'fa' => 'مثلاً میز پنجره', 'en' => 'e.g. Window table', 'tr' => 'örn. Pencere kenarı' ),
			'table_seats'           => array( 'fa' => 'تعداد صندلی', 'en' => 'Seats', 'tr' => 'Koltuk' ),
			'table_number_col'      => array( 'fa' => 'شماره میز', 'en' => 'Table no.', 'tr' => 'Masa no.' ),
			'table_number_label'    => array( 'fa' => 'میز شماره %d', 'en' => 'Table #%d', 'tr' => 'Masa #%d' ),
			'table_number_duplicate' => array( 'fa' => 'شماره میز %d تکراری است.', 'en' => 'Table number %d is duplicated.', 'tr' => '%d numaralı masa tekrarlanmış.' ),
			'table_number_required' => array( 'fa' => 'برای هر میز، شماره همان میز در کافه را وارد کنید.', 'en' => 'Enter the number each table actually carries in your café.', 'tr' => 'Kafenizde masaların üzerinde yazan gerçek numarayı girin.' ),
			'table_number_hint'     => array( 'fa' => 'شماره‌ای که روی میز نوشته شده را وارد کنید تا مهمان‌ها گیج نشوند.', 'en' => 'Use the number written on the table itself so guests are not confused.', 'tr' => 'Misafirlerin kafası karışmasın diye masanın üzerindeki numarayı kullanın.' ),
			'tables_locked'         => array( 'fa' => 'تا پایان %d دورهمی فعال، امکان ویرایش میزها نیست.', 'en' => 'Tables cannot be edited while %d active event(s) are using them.', 'tr' => '%d aktif etkinlik bu masaları kullanırken masalar düzenlenemez.' ),
			'tables_locked_hint'    => array( 'fa' => 'پس از برگزاری یا لغو این دورهمی‌ها، میزها دوباره قابل ویرایش می‌شوند.', 'en' => 'Once those events finish or are cancelled, the tables unlock again.', 'tr' => 'Bu etkinlikler bitince veya iptal edilince masalar tekrar açılır.' ),
			'table_quantity'        => array( 'fa' => 'تعداد میز', 'en' => 'How many', 'tr' => 'Adet' ),
			'event_tables_pick'     => array( 'fa' => 'میزهای این دورهمی را انتخاب کنید', 'en' => 'Pick the tables for this event', 'tr' => 'Bu etkinlik için masaları seçin' ),
			'event_capacity_preview' => array( 'fa' => 'ظرفیت این دورهمی: %d نفر', 'en' => 'Capacity for this event: %d guests', 'tr' => 'Bu etkinliğin kapasitesi: %d misafir' ),
			'event_need_tables'     => array( 'fa' => 'حداقل یک میز را انتخاب کنید.', 'en' => 'Please select at least one table.', 'tr' => 'Lütfen en az bir masa seçin.' ),
			'event_theme_hint'      => array( 'fa' => 'مثلاً موسیقی، کتاب، بازی', 'en' => 'e.g. Music, Books, Games', 'tr' => 'örn. Müzik, Kitap, Oyun' ),
			'event_desc_hint'       => array( 'fa' => 'در چند خط بنویسید این دورهمی درباره چیست تا مهمان پیش از رزرو بداند.', 'en' => 'A few lines on what this gathering is, so guests know before they book.', 'tr' => 'Misafirler rezervasyon yapmadan önce bilsin diye bu buluşmanın ne olduğunu birkaç satırda yazın.' ),
			'event_image'           => array( 'fa' => 'عکس دورهمی (اختیاری)', 'en' => 'Event photo (optional)', 'tr' => 'Etkinlik fotoğrafı (isteğe bağlı)' ),
			'tab_venue_settings'    => array( 'fa' => 'تنظیمات کافه', 'en' => 'Venue Settings', 'tr' => 'Mekân Ayarları' ),

			// Explore.
			'explore_title'         => array( 'fa' => 'دورهمی‌های این هفته', 'en' => 'This week’s tables', 'tr' => 'Bu haftanın masaları' ),
			'explore_empty'         => array( 'fa' => 'فعلاً دورهمی بازی ثبت نشده است.', 'en' => 'No open tables right now.', 'tr' => 'Şu anda açık masa yok.' ),
			'seats_left'            => array( 'fa' => 'صندلی خالی', 'en' => 'seats left', 'tr' => 'koltuk kaldı' ),
			'seats_occupancy'       => array( 'fa' => 'پرشده از ظرفیت', 'en' => 'Filled of capacity', 'tr' => 'Kapasitenin dolu kısmı' ),
			'total_seats'           => array( 'fa' => 'مجموع صندلی‌ها', 'en' => 'Total seats', 'tr' => 'Toplam koltuk' ),
			'join_event'            => array( 'fa' => 'رزرو صندلی', 'en' => 'Reserve a seat', 'tr' => 'Koltuk ayırt' ),
			'reserve_title'         => array( 'fa' => 'رزرو صندلی', 'en' => 'Reserve a seat', 'tr' => 'Koltuk ayırt' ),
			'how_many_seats'        => array( 'fa' => 'چند صندلی رزرو می‌کنید؟', 'en' => 'How many seats?', 'tr' => 'Kaç koltuk?' ),
			'seats_hint'            => array(
				'fa' => 'می‌توانید تا %s صندلی رزرو کنید. همراهان شما کنار خودتان می‌نشینند.',
				'en' => 'You can reserve up to %s seats. Your companions are seated with you.',
				'tr' => 'En fazla %s koltuk ayırtabilirsiniz. Yanınızdakiler sizinle aynı masaya oturur.',
			),
			'seat_one'              => array( 'fa' => 'فقط خودم', 'en' => 'Just me', 'tr' => 'Sadece ben' ),
			'seat_n'                => array( 'fa' => '%s نفر', 'en' => '%s people', 'tr' => '%s kişi' ),
			'confirm_reserve'       => array( 'fa' => 'تایید رزرو', 'en' => 'Confirm', 'tr' => 'Onayla' ),
			'only_n_seats_left'     => array(
				'fa' => 'فقط %s صندلی خالی مانده است.',
				'en' => 'Only %s seat(s) left.',
				'tr' => 'Yalnızca %s koltuk kaldı.',
			),
			'party_max_seats'       => array(
				'fa' => 'بزرگ‌ترین میز این دورهمی %s صندلی دارد و همراهان باید کنار هم بنشینند.',
				'en' => 'The largest table here seats %s, and a party is always seated together.',
				'tr' => 'Buradaki en büyük masa %s kişiliktir ve bir grup her zaman birlikte oturtulur.',
			),
			'seats_booked'          => array( 'fa' => '%s صندلی رزرو شد', 'en' => '%s seats reserved', 'tr' => '%s koltuk ayrıldı' ),
			'how_many_arrived'      => array( 'fa' => 'چند نفر حاضر شدند؟', 'en' => 'How many arrived?', 'tr' => 'Kaç kişi geldi?' ),
			'arrived_n_of_m'        => array( 'fa' => '%s از %s', 'en' => '%s of %s', 'tr' => '%s / %s' ),
			'penalty_points'        => array( 'fa' => 'امتیاز منفی', 'en' => 'Penalty points', 'tr' => 'Ceza puanı' ),
			'penalty_notice'        => array(
				'fa' => 'اگر در دورهمی حاضر نشوید یا صندلی رزروشده خالی بماند، امتیاز رفتاری شما کاهش می‌یابد.',
				'en' => 'Not turning up, or leaving a reserved seat empty, lowers your behaviour score.',
				'tr' => 'Gelmemek veya ayırttığınız koltuğu boş bırakmak davranış puanınızı düşürür.',
			),
			'stat_no_shows'         => array( 'fa' => 'عدم حضور', 'en' => 'No-shows', 'tr' => 'Gelmeyenler' ),
			'stat_empty_seats'      => array( 'fa' => 'صندلی خالی‌مانده', 'en' => 'Empty seats left', 'tr' => 'Boş kalan koltuk' ),
			'event_theme'           => array( 'fa' => 'موضوع', 'en' => 'Theme', 'tr' => 'Tema' ),
			'event_subject'         => array( 'fa' => 'موضوع رویداد', 'en' => 'Subject', 'tr' => 'Konu' ),
			'event_about'           => array( 'fa' => 'درباره این دورهمی', 'en' => 'About this gathering', 'tr' => 'Bu buluşma hakkında' ),
			'about_venue'           => array( 'fa' => 'درباره کافه', 'en' => 'About the café', 'tr' => 'Kafe hakkında' ),
			'starts_in'             => array( 'fa' => 'تا شروع', 'en' => 'Starts in', 'tr' => 'Başlamasına' ),
			'event_started'         => array( 'fa' => 'شروع شده است', 'en' => 'Already started', 'tr' => 'Başladı' ),
			'unit_day'              => array( 'fa' => 'روز', 'en' => 'd', 'tr' => 'g' ),
			'unit_hour'             => array( 'fa' => 'ساعت', 'en' => 'h', 'tr' => 's' ),
			'unit_minute'           => array( 'fa' => 'دقیقه', 'en' => 'm', 'tr' => 'dk' ),
			'unit_second'           => array( 'fa' => 'ثانیه', 'en' => 's', 'tr' => 'sn' ),
			'joined_event'          => array( 'fa' => 'در صف این میز هستید', 'en' => 'You are in the queue', 'tr' => 'Sıradasınız' ),
			'event_full'            => array( 'fa' => 'ظرفیت تکمیل است', 'en' => 'Table is full', 'tr' => 'Masa dolu' ),
			// Atmosphere, not price. The plugin never handles money, so these
			// describe how a café feels rather than what it costs. The stored
			// keys stay low/medium/high so no migration is needed.
			'budget_low'            => array( 'fa' => 'دنج', 'en' => 'Cosy', 'tr' => 'Samimi' ),
			'budget_medium'         => array( 'fa' => 'معمولی', 'en' => 'Everyday', 'tr' => 'Sıradan' ),
			'budget_high'           => array( 'fa' => 'لاکچری', 'en' => 'Upscale', 'tr' => 'Lüks' ),
			'atmosphere'            => array( 'fa' => 'حال و هوا', 'en' => 'Atmosphere', 'tr' => 'Atmosfer' ),
			'status_open'           => array( 'fa' => 'باز', 'en' => 'Open', 'tr' => 'Açık' ),
			'status_matched'        => array( 'fa' => 'میز چیده شد', 'en' => 'Matched', 'tr' => 'Eşleşti' ),
			'status_completed'      => array( 'fa' => 'برگزار شد', 'en' => 'Completed', 'tr' => 'Tamamlandı' ),
			'status_pending_admin'  => array( 'fa' => 'در انتظار تایید', 'en' => 'Pending review', 'tr' => 'İnceleniyor' ),
			'status_cancelled'      => array( 'fa' => 'لغو شده', 'en' => 'Cancelled', 'tr' => 'İptal edildi' ),
			'event_details'         => array( 'fa' => 'جزئیات رویداد', 'en' => 'Event details', 'tr' => 'Etkinlik ayrıntıları' ),
			'event_edit'            => array( 'fa' => 'ویرایش رویداد', 'en' => 'Edit event', 'tr' => 'Etkinliği düzenle' ),
			'event_cancel'          => array( 'fa' => 'لغو رویداد', 'en' => 'Cancel event', 'tr' => 'Etkinliği iptal et' ),
			'event_cancel_confirm'  => array( 'fa' => 'این رویداد لغو شود؟', 'en' => 'Cancel this event?', 'tr' => 'Bu etkinlik iptal edilsin mi?' ),
			'event_cancel_confirm_guests' => array( 'fa' => 'این رویداد %s رزرو دارد. با لغو آن، همه‌ی رزروها هم لغو می‌شوند. ادامه می‌دهید؟', 'en' => 'This event has %s bookings. Cancelling it will cancel them all. Continue?', 'tr' => 'Bu etkinlikte %s rezervasyon var. İptal ederseniz hepsi iptal olur. Devam edilsin mi?' ),
			'event_cancelled_done'  => array( 'fa' => 'رویداد لغو شد.', 'en' => 'Event cancelled.', 'tr' => 'Etkinlik iptal edildi.' ),
			'event_not_open'        => array( 'fa' => 'این دورهمی دیگر پذیرای رزرو نیست.', 'en' => 'This gathering is no longer taking bookings.', 'tr' => 'Bu buluşma artık rezervasyon almıyor.' ),
			'event_too_soon'        => array( 'fa' => 'مهلت رزرو این دورهمی تمام شده است.', 'en' => 'Bookings for this gathering have closed.', 'tr' => 'Bu buluşma için rezervasyonlar kapandı.' ),
			'event_over'            => array( 'fa' => 'این دورهمی دیگر در دسترس نیست.', 'en' => 'This gathering is no longer available.', 'tr' => 'Bu buluşma artık mevcut değil.' ),
			'event_time'            => array( 'fa' => 'ساعت', 'en' => 'Time', 'tr' => 'Saat' ),
			'seats_reserved'        => array( 'fa' => 'صندلی رزروشده', 'en' => 'Seats reserved', 'tr' => 'Ayrılan koltuk' ),
			'need_profile_first'    => array( 'fa' => 'ابتدا تست شخصیت‌شناسی ۳۰ ثانیه‌ای را کامل کنید.', 'en' => 'Please complete the 30-second personality test first.', 'tr' => 'Lütfen önce 30 saniyelik kişilik testini tamamlayın.' ),

			// Venue popup.
			'venue_profile'         => array( 'fa' => 'پروفایل کافه', 'en' => 'Café profile', 'tr' => 'Kafe profili' ),
			'venue_menu'            => array( 'fa' => 'منوی کافه', 'en' => 'Café menu', 'tr' => 'Kafe menüsü' ),
			'menu_display_only'     => array( 'fa' => 'این منو فقط جهت مرور است؛ سفارش حضوری در کافه ثبت می‌شود.', 'en' => 'Menu is for browsing only — orders are placed in person at the café.', 'tr' => 'Menü yalnızca göz atmak içindir — siparişler kafede yerinde verilir.' ),
			'quiet_hours'           => array( 'fa' => 'ساعات خلوت', 'en' => 'Quiet hours', 'tr' => 'Sakin saatler' ),
			'view_venue_profile'    => array( 'fa' => 'مشاهده پروفایل و منوی کافه', 'en' => 'View café profile & menu', 'tr' => 'Kafe profilini ve menüsünü gör' ),
			'verified_venue'        => array( 'fa' => 'کافه تاییدشده', 'en' => 'Verified café', 'tr' => 'Onaylı kafe' ),
			'guests_routed'         => array( 'fa' => 'مهمان هدایت‌شده', 'en' => 'guests routed', 'tr' => 'misafir yönlendirildi' ),

			// Map.
			'map_title'             => array( 'fa' => 'کافه‌های نزدیک', 'en' => 'Nearby cafés', 'tr' => 'Yakındaki kafeler' ),
			'nearby_location'       => array( 'fa' => 'موقعیت نزدیک', 'en' => 'Nearby Location', 'tr' => 'Yakın Konum' ),
			'map_hint'              => array( 'fa' => 'روی پین‌ها بزنید تا پروفایل کافه باز شود.', 'en' => 'Tap a pin to open the café profile.', 'tr' => 'Kafe profilini açmak için bir işarete dokunun.' ),
			// Shown when the map library cannot be fetched. The café list
			// underneath still works, so this is an inconvenience, not a dead
			// end — the wording says so.
			'map_unavailable'       => array( 'fa' => 'نقشه در دسترس نیست. فهرست کافه‌ها در پایین همچنان کار می‌کند.', 'en' => 'The map could not load. The café list below still works.', 'tr' => 'Harita yüklenemedi. Aşağıdaki kafe listesi çalışmaya devam ediyor.' ),
			'locating'              => array( 'fa' => 'در حال یافتن موقعیت شما…', 'en' => 'Finding your location…', 'tr' => 'Konumunuz bulunuyor…' ),
			'geo_denied'            => array( 'fa' => 'دسترسی به موقعیت مکانی رد شد. از تنظیمات مرورگر اجازه دهید.', 'en' => 'Location access denied. Allow it in your browser settings.', 'tr' => 'Konum erişimi reddedildi. Tarayıcı ayarlarınızdan izin verin.' ),
			'geo_failed'            => array( 'fa' => 'موقعیت مکانی پیدا نشد. دوباره تلاش کنید.', 'en' => 'Could not determine your location. Please try again.', 'tr' => 'Konumunuz belirlenemedi. Lütfen tekrar deneyin.' ),
			'geo_unsupported'       => array( 'fa' => 'مرورگر شما از موقعیت مکانی پشتیبانی نمی‌کند.', 'en' => 'Your browser does not support geolocation.', 'tr' => 'Tarayıcınız konum servisini desteklemiyor.' ),

			// Chats.
			'chats_title'           => array( 'fa' => 'گفتگوها', 'en' => 'Chats', 'tr' => 'Sohbetler' ),
			'chat_groups'           => array( 'fa' => 'چت میزها', 'en' => 'Table chats', 'tr' => 'Masa sohbetleri' ),
			'chat_friends'          => array( 'fa' => 'چت دوستان', 'en' => 'Friend chats', 'tr' => 'Arkadaş sohbetleri' ),
			'chat_placeholder'      => array( 'fa' => 'پیام خود را بنویسید…', 'en' => 'Write a message…', 'tr' => 'Bir mesaj yazın…' ),
			'no_groups'             => array( 'fa' => 'هنوز عضو هیچ میزی نشده‌اید.', 'en' => 'You are not seated at any table yet.', 'tr' => 'Henüz hiçbir masaya oturmadınız.' ),
			'no_friends'            => array( 'fa' => 'هنوز دوستی اضافه نکرده‌اید.', 'en' => 'You have not added any friends yet.', 'tr' => 'Henüz arkadaş eklemediniz.' ),
			'system_message'        => array( 'fa' => 'پیام سیستم', 'en' => 'System message', 'tr' => 'Sistem mesajı' ),
			'chat_table_ready'      => array( 'fa' => 'میز شما چیده شد!', 'en' => 'Your table is ready at', 'tr' => 'Masanız hazır:' ),
			'venue_fallback'        => array( 'fa' => 'کافه', 'en' => 'Café', 'tr' => 'Kafe' ),

			// Profile.
			'profile_title'         => array( 'fa' => 'پروفایل من', 'en' => 'My Profile', 'tr' => 'Profilim' ),
			'rating_score'          => array( 'fa' => 'امتیاز رفتاری', 'en' => 'Behaviour score', 'tr' => 'Davranış puanı' ),
			'events_attended'       => array( 'fa' => 'دورهمی حاضر شده', 'en' => 'Tables attended', 'tr' => 'Katıldığı masa' ),
			'start_test'            => array( 'fa' => '🧠 شروع تست ۳۰ ثانیه‌ای', 'en' => '🧠 Take the 30-second test', 'tr' => '🧠 30 saniyelik testi çöz' ),
			'test_step'             => array( 'fa' => 'مرحله', 'en' => 'Step', 'tr' => 'Adım' ),
			'q_age'                 => array( 'fa' => 'سن شما چند است؟', 'en' => 'How old are you?', 'tr' => 'Kaç yaşındasınız?' ),
			'q_gender'              => array( 'fa' => 'جنسیت', 'en' => 'Gender', 'tr' => 'Cinsiyet' ),
			'gender_male'           => array( 'fa' => 'آقا', 'en' => 'Male', 'tr' => 'Erkek' ),
			'gender_female'         => array( 'fa' => 'خانم', 'en' => 'Female', 'tr' => 'Kadın' ),
			'gender_other'          => array( 'fa' => 'ترجیح می‌دهم نگویم', 'en' => 'Prefer not to say', 'tr' => 'Belirtmek istemiyorum' ),
			'q_extroversion'        => array( 'fa' => 'چقدر برون‌گرا هستید؟', 'en' => 'How extroverted are you?', 'tr' => 'Ne kadar dışa dönüksünüz?' ),
			'q_talkative'           => array( 'fa' => 'سبک مکالمه شما', 'en' => 'Your conversation style', 'tr' => 'Sohbet tarzınız' ),
			'q_vibe'                => array( 'fa' => 'جو مکالمه دلخواه', 'en' => 'Preferred conversation vibe', 'tr' => 'Tercih ettiğiniz sohbet havası' ),
			'vibe_deep'             => array( 'fa' => 'عمیق و فلسفی', 'en' => 'Deep & thoughtful', 'tr' => 'Derin ve düşündürücü' ),
			'vibe_fun'              => array( 'fa' => 'شاد و سرگرم‌کننده', 'en' => 'Fun & light', 'tr' => 'Eğlenceli ve hafif' ),
			'q_interests'           => array( 'fa' => 'علاقه‌مندی‌ها (چندتایی)', 'en' => 'Your interests (multi-select)', 'tr' => 'İlgi alanlarınız (çoklu seçim)' ),
			'interests_search'      => array( 'fa' => 'جستجو در علاقه‌مندی‌ها…', 'en' => 'Search interests…', 'tr' => 'İlgi alanlarında ara…' ),
			'interests_chosen'      => array( 'fa' => '%s انتخاب‌شده', 'en' => '%s selected', 'tr' => '%s seçildi' ),
			'interests_none_found'  => array( 'fa' => 'موردی با این جستجو پیدا نشد.', 'en' => 'Nothing matches that search.', 'tr' => 'Bu aramayla eşleşen bir şey yok.' ),
			'interests_other'       => array( 'fa' => 'سایر', 'en' => 'Other', 'tr' => 'Diğer' ),

			// --- personality test: the five traits added in 1.11.0 ---------
			'q_openness'            => array( 'fa' => 'با آدم‌های تازه چطور برخورد می‌کنید؟', 'en' => 'How do you approach new people?', 'tr' => 'Yeni insanlara nasıl yaklaşırsınız?' ),
			'openness_low'          => array( 'fa' => 'محتاط', 'en' => 'Cautious', 'tr' => 'Temkinli' ),
			'openness_high'         => array( 'fa' => 'پذیرا', 'en' => 'Open', 'tr' => 'Açık' ),
			'q_humor'               => array( 'fa' => 'شوخ‌طبعی در گفتگو چه جایگاهی دارد؟', 'en' => 'How big a part does humour play for you?', 'tr' => 'Mizah sizin için ne kadar önemli?' ),
			'humor_low'             => array( 'fa' => 'جدی', 'en' => 'Serious', 'tr' => 'Ciddi' ),
			'humor_high'            => array( 'fa' => 'شوخ', 'en' => 'Playful', 'tr' => 'Şakacı' ),
			'q_energy'              => array( 'fa' => 'چه فضایی برایتان دلچسب‌تر است؟', 'en' => 'Which atmosphere suits you better?', 'tr' => 'Hangi ortam size daha uygun?' ),
			'energy_low'            => array( 'fa' => 'دنج و آرام', 'en' => 'Quiet & cosy', 'tr' => 'Sakin ve samimi' ),
			'energy_high'           => array( 'fa' => 'پرشور و شلوغ', 'en' => 'Lively & buzzing', 'tr' => 'Hareketli ve canlı' ),
			'q_planning'            => array( 'fa' => 'برنامه‌ریز هستید یا خودجوش؟', 'en' => 'Planner or spontaneous?', 'tr' => 'Planlı mı, spontane mi?' ),
			'planning_low'          => array( 'fa' => 'خودجوش', 'en' => 'Spontaneous', 'tr' => 'Spontane' ),
			'planning_high'         => array( 'fa' => 'برنامه‌ریز', 'en' => 'Planner', 'tr' => 'Planlı' ),
			'q_empathy'             => array( 'fa' => 'وقتی کسی حرف می‌زند، بیشتر…', 'en' => 'When someone is talking, you mostly…', 'tr' => 'Biri konuşurken çoğunlukla…' ),
			'empathy_low'           => array( 'fa' => 'راه‌حل می‌دهم', 'en' => 'Offer solutions', 'tr' => 'Çözüm sunarım' ),
			'empathy_high'          => array( 'fa' => 'همدلی می‌کنم', 'en' => 'Listen and empathise', 'tr' => 'Dinler ve empati kurarım' ),
			'test_intro_title'      => array( 'fa' => 'شخصیت‌شناسی هواتو', 'en' => 'Your Havato personality', 'tr' => 'Havato kişiliğiniz' ),
			'test_intro_body'       => array(
				'fa' => 'هفت سؤال کوتاه درباره‌ی سبک گفتگو و شخصیت شما. جواب درست و غلط ندارد؛ هرچه صادقانه‌تر باشید، هم‌میزی‌های بهتری پیشنهاد می‌شود.',
				'en' => 'Seven short questions about how you talk and connect. There are no right answers — the more honest you are, the better your table matches.',
				'tr' => 'Nasıl konuştuğunuz ve bağ kurduğunuzla ilgili yedi kısa soru. Doğru cevap yok — ne kadar dürüst olursanız masa eşleşmeniz o kadar iyi olur.',
			),

			// --- personal details editor -----------------------------------
			'block_user'            => array( 'fa' => 'مسدود کردن', 'en' => 'Block', 'tr' => 'Engelle' ),
			'unblock_user'          => array( 'fa' => 'رفع مسدودی', 'en' => 'Unblock', 'tr' => 'Engeli kaldır' ),
			'blocked_list'          => array( 'fa' => 'کاربران مسدودشده', 'en' => 'Blocked users', 'tr' => 'Engellenen kullanıcılar' ),
			'block_confirm'         => array(
				'fa' => 'این کاربر دیگر برای شما نمایش داده نمی‌شود، پیامی نمی‌تواند بفرستد و هرگز هم‌میز شما نخواهد شد. دوستی شما هم پایان می‌یابد.',
				'en' => 'You will no longer see this person, they cannot message you, and you will never be seated together. Your friendship also ends.',
				'tr' => 'Bu kişiyi artık görmeyeceksiniz, size mesaj gönderemez ve asla aynı masaya oturtulmazsınız. Arkadaşlığınız da sona erer.',
			),
			'blocked_done'          => array( 'fa' => 'کاربر مسدود شد.', 'en' => 'User blocked.', 'tr' => 'Kullanıcı engellendi.' ),
			'block_friends_only'    => array( 'fa' => 'مسدود کردن فقط در گفتگوی خصوصی ممکن است. برای پیام نامناسب سر میز، از دکمه گزارش استفاده کنید.', 'en' => 'Blocking is only available in a private conversation. To flag a message at a table, use Report.', 'tr' => 'Engelleme yalnızca özel sohbette kullanılabilir. Masadaki bir mesajı bildirmek için Bildir düğmesini kullanın.' ),
			'blocklists_title'      => array( 'fa' => 'فهرست‌های مسدودی', 'en' => 'Blocklists', 'tr' => 'Engel listeleri' ),
			'blocklists_hint'       => array( 'fa' => 'هر مسدودی یک قید سخت در موتور تطبیق است: این دو نفر هرگز سر یک میز نمی‌نشینند. مسدودی‌هایی که پیش از نسخه ۱٫۲۳ از داخل چت میز ثبت شده‌اند هم اینجا دیده می‌شوند و قابل برداشتن‌اند.', 'en' => 'Every block is a hard constraint in the matcher: these two are never seated together. Blocks placed from a table chat before 1.23 also appear here and can be lifted.', 'tr' => 'Her engel eşleştirme motorunda kesin bir kısıttır: bu iki kişi asla aynı masaya oturtulmaz. 1.23 öncesinde masa sohbetinden konulan engeller de burada görünür ve kaldırılabilir.' ),
			'blocklist_owner'       => array( 'fa' => 'مسدودکننده', 'en' => 'Blocked by', 'tr' => 'Engelleyen' ),
			'blocklist_target'      => array( 'fa' => 'مسدودشده', 'en' => 'Blocked person', 'tr' => 'Engellenen' ),
			'blocklist_effect'      => array( 'fa' => 'اثر', 'en' => 'Effect', 'tr' => 'Etki' ),
			'blocklist_never_seated' => array( 'fa' => 'هرگز هم‌میز نمی‌شوند', 'en' => 'Never seated together', 'tr' => 'Asla aynı masaya oturmaz' ),
			'blocklist_mutual'      => array( 'fa' => 'دوطرفه', 'en' => 'Mutual', 'tr' => 'Karşılıklı' ),
			'blocklist_clear'       => array( 'fa' => 'برداشتن مسدودی', 'en' => 'Lift block', 'tr' => 'Engeli kaldır' ),
			'blocklist_clear_confirm' => array( 'fa' => 'این مسدودی برداشته شود؟ از این پس ممکن است این دو نفر دوباره هم‌میز شوند.', 'en' => 'Lift this block? These two may be seated together again.', 'tr' => 'Bu engel kaldırılsın mı? Bu iki kişi tekrar aynı masaya oturabilir.' ),
			'blocklist_cleared'     => array( 'fa' => 'مسدودی برداشته شد.', 'en' => 'Block lifted.', 'tr' => 'Engel kaldırıldı.' ),
			'unblocked_done'        => array( 'fa' => 'مسدودی برداشته شد.', 'en' => 'User unblocked.', 'tr' => 'Engel kaldırıldı.' ),
			'report_message'        => array( 'fa' => 'گزارش پیام', 'en' => 'Report message', 'tr' => 'Mesajı bildir' ),
			'message_reported'      => array( 'fa' => 'گزارش شما ثبت شد و بررسی می‌شود.', 'en' => 'Your report has been submitted for review.', 'tr' => 'Bildiriminiz incelenmek üzere gönderildi.' ),
			'message_removed'       => array( 'fa' => '[این پیام توسط مدیریت حذف شد]', 'en' => '[This message was removed by a moderator]', 'tr' => '[Bu mesaj yönetici tarafından kaldırıldı]' ),
			'msg_actions'           => array( 'fa' => 'گزینه‌های پیام', 'en' => 'Message options', 'tr' => 'Mesaj seçenekleri' ),
			'stickers'              => array( 'fa' => 'استیکرها', 'en' => 'Stickers', 'tr' => 'Çıkartmalar' ),
			'needs_review'          => array( 'fa' => 'نیازمند بررسی', 'en' => 'Needs review', 'tr' => 'İnceleme gerekli' ),
			'only_flagged'          => array( 'fa' => 'فقط پیام‌های علامت‌خورده', 'en' => 'Flagged only', 'tr' => 'Yalnızca işaretliler' ),
			'flagged_count'         => array( 'fa' => 'پیام علامت‌خورده', 'en' => 'flagged messages', 'tr' => 'işaretli mesaj' ),
			'ban_user'              => array( 'fa' => 'مسدود کردن کاربر', 'en' => 'Ban user', 'tr' => 'Kullanıcıyı yasakla' ),
			'unban_user'            => array( 'fa' => 'رفع مسدودی کاربر', 'en' => 'Unban user', 'tr' => 'Yasağı kaldır' ),
			'banned_badge'          => array( 'fa' => 'مسدود', 'en' => 'Banned', 'tr' => 'Yasaklı' ),
			'account_banned'        => array(
				'fa' => 'دسترسی این حساب توسط مدیریت مسدود شده است.',
				'en' => 'This account has been suspended by an administrator.',
				'tr' => 'Bu hesap bir yönetici tarafından askıya alındı.',
			),
			'admin_chats'           => array( 'fa' => 'گفتگوها و گزارش‌ها', 'en' => 'Chats & reports', 'tr' => 'Sohbetler ve bildirimler' ),
			'chat_reports'          => array( 'fa' => 'پیام‌های گزارش‌شده', 'en' => 'Reported messages', 'tr' => 'Bildirilen mesajlar' ),
			'chat_log'              => array( 'fa' => 'آرشیو گفتگوها', 'en' => 'Conversation archive', 'tr' => 'Sohbet arşivi' ),
			'chat_group_col'        => array( 'fa' => 'میز', 'en' => 'Table', 'tr' => 'Masa' ),
			'chat_private_col'      => array( 'fa' => 'گفتگوی خصوصی', 'en' => 'Private chat', 'tr' => 'Özel sohbet' ),
			'keep_message'          => array( 'fa' => 'نگه داشتن', 'en' => 'Keep', 'tr' => 'Sakla' ),
			'remove_message'        => array( 'fa' => 'حذف پیام', 'en' => 'Remove message', 'tr' => 'Mesajı kaldır' ),
			'no_reports'            => array( 'fa' => 'گزارشی ثبت نشده است.', 'en' => 'No reports.', 'tr' => 'Bildirim yok.' ),
			'edit_behaviour'        => array( 'fa' => '🧠 ویرایش علاقه‌مندی‌ها و تست', 'en' => '🧠 Edit interests & test', 'tr' => '🧠 İlgi alanları ve testi düzenle' ),
			/*
			 * The profile card is titled by what it actually shows. It used to
			 * be "Behaviour profile" and printed the personality-test result;
			 * the scores are now kept private and only the interests remain.
			 */
			'interests_title'       => array( 'fa' => 'علاقه‌مندی‌ها', 'en' => 'Interests', 'tr' => 'İlgi alanları' ),
			'interests_empty'       => array( 'fa' => 'هنوز علاقه‌مندی‌ای انتخاب نکرده‌اید. با ویرایش، علاقه‌مندی‌هایتان را اضافه کنید تا هم‌میزی‌های بهتری پیدا کنید.', 'en' => 'You have not picked any interests yet. Add some so we can seat you with people who share them.', 'tr' => 'Henüz ilgi alanı seçmediniz. Ekleyin ki sizi ortak ilgi alanına sahip kişilerle aynı masaya oturtalım.' ),
			'delete_account'        => array( 'fa' => 'حذف حساب کاربری', 'en' => 'Delete my account', 'tr' => 'Hesabımı sil' ),
			'delete_confirm_1'      => array(
				'fa' => 'با حذف حساب، پروفایل، رزروها، گفتگوها و عکس‌های شما برای همیشه پاک می‌شود. این کار قابل بازگشت نیست.',
				'en' => 'Deleting your account permanently removes your profile, bookings, chats and photos. This cannot be undone.',
				'tr' => 'Hesabınızı silmek profilinizi, rezervasyonlarınızı, sohbetlerinizi ve fotoğraflarınızı kalıcı olarak siler. Bu işlem geri alınamaz.',
			),
			'delete_continue'       => array( 'fa' => 'متوجه‌ام، ادامه', 'en' => 'I understand, continue', 'tr' => 'Anladım, devam et' ),
			'delete_confirm_2'      => array(
				'fa' => 'برای تایید نهایی، عبارت زیر را وارد کنید:',
				'en' => 'To confirm, type the word below:',
				'tr' => 'Onaylamak için aşağıdaki kelimeyi yazın:',
			),
			'delete_keyword'        => array( 'fa' => 'حذف', 'en' => 'DELETE', 'tr' => 'SIL' ),
			'delete_final'          => array( 'fa' => 'حذف دائمی حساب', 'en' => 'Permanently delete', 'tr' => 'Kalıcı olarak sil' ),
			'delete_mismatch'       => array( 'fa' => 'عبارت وارد شده درست نیست.', 'en' => 'That does not match.', 'tr' => 'Girdiğiniz kelime eşleşmiyor.' ),
			'delete_done'           => array( 'fa' => 'حساب شما حذف شد.', 'en' => 'Your account has been deleted.', 'tr' => 'Hesabınız silindi.' ),
			'delete_admin_blocked'  => array(
				'fa' => 'حساب مدیر از این بخش قابل حذف نیست.',
				'en' => 'An administrator account cannot be deleted from here.',
				'tr' => 'Yönetici hesabı buradan silinemez.',
			),
			'deleted_user'          => array( 'fa' => 'کاربر حذف‌شده', 'en' => 'Deleted user', 'tr' => 'Silinmiş kullanıcı' ),
			'danger_zone'           => array( 'fa' => 'منطقه خطر', 'en' => 'Danger zone', 'tr' => 'Tehlikeli bölge' ),
			'edit_details'          => array( 'fa' => '✏️ ویرایش مشخصات من', 'en' => '✏️ Edit my details', 'tr' => '✏️ Bilgilerimi düzenle' ),
			'details_title'         => array( 'fa' => 'مشخصات من', 'en' => 'My details', 'tr' => 'Bilgilerim' ),
			'details_hint'          => array(
				'fa' => 'این اطلاعات برای پیدا کردن دورهمی‌های نزدیک شما استفاده می‌شود و هر زمان قابل ویرایش است.',
				'en' => 'Used to find gatherings near you. You can change these at any time.',
				'tr' => 'Yakınınızdaki buluşmaları bulmak için kullanılır. Bunları istediğiniz zaman değiştirebilirsiniz.',
			),
			'q_name'                => array( 'fa' => 'نام نمایشی', 'en' => 'Display name', 'tr' => 'Görünen ad' ),
			'q_phone'               => array( 'fa' => 'شماره تلفن همراه', 'en' => 'Mobile number', 'tr' => 'Cep telefonu numarası' ),
			'phone_hint'            => array(
				'fa' => 'پیش‌شماره بر اساس کشور انتخابی شما درج می‌شود. این شماره فقط برای هماهنگی کافه با شماست و برای بقیه نمایش داده نمی‌شود.',
				'en' => 'The dialling code follows the country you picked. Your number is only used by the café to reach you and is never shown to other guests.',
				'tr' => 'Ülke kodu seçtiğiniz ülkeye göre eklenir. Numaranız yalnızca kafenin size ulaşması için kullanılır ve diğer misafirlere asla gösterilmez.',
			),
			'err_phone'             => array( 'fa' => 'شماره تلفن معتبر نیست.', 'en' => 'That phone number is not valid.', 'tr' => 'Bu telefon numarası geçerli değil.' ),
			'err_phone_taken'       => array( 'fa' => 'این شماره قبلاً ثبت شده است.', 'en' => 'That number is already registered.', 'tr' => 'Bu numara zaten kayıtlı.' ),
			'details_saved'         => array( 'fa' => 'مشخصات شما ذخیره شد.', 'en' => 'Your details were saved.', 'tr' => 'Bilgileriniz kaydedildi.' ),
			'details_needed'        => array(
				'fa' => 'برای دیدن دورهمی‌های شهرتان، ابتدا مشخصاتتان را کامل کنید.',
				'en' => 'Complete your details to see gatherings in your city.',
				'tr' => 'Şehrinizdeki buluşmaları görmek için bilgilerinizi tamamlayın.',
			),
			'err_name_short'        => array( 'fa' => 'نام باید حداقل ۲ حرف باشد.', 'en' => 'Your name needs at least 2 characters.', 'tr' => 'Adınız en az 2 karakter olmalı.' ),
			'err_age_range'         => array( 'fa' => 'سن باید بین ۱۸ تا ۷۵ سال باشد.', 'en' => 'Age must be between 18 and 75.', 'tr' => 'Yaş 18 ile 75 arasında olmalı.' ),
			'q_city'                => array( 'fa' => 'محله / منطقه', 'en' => 'Neighborhood', 'tr' => 'Mahalle' ),
			'q_country'             => array( 'fa' => 'کشور', 'en' => 'Country', 'tr' => 'Ülke' ),
			'q_city_select'         => array( 'fa' => 'شهر', 'en' => 'City', 'tr' => 'Şehir' ),
			'city_empty'            => array( 'fa' => 'فعلاً در شهر شما دورهمی‌ای ثبت نشده است.', 'en' => 'No tables in your city yet.', 'tr' => 'Şehrinizde henüz masa yok.' ),
			'test_done'             => array( 'fa' => 'تست شخصیت‌شناسی شما ثبت شد.', 'en' => 'Your personality profile has been saved.', 'tr' => 'Kişilik profiliniz kaydedildi.' ),
			'gallery'               => array( 'fa' => 'گالری عکس', 'en' => 'Photo gallery', 'tr' => 'Fotoğraf galerisi' ),
			'gallery_locked'        => array( 'fa' => 'گالری عکس فقط برای دوستان تاییدشده قابل مشاهده است.', 'en' => 'The photo gallery is only visible to accepted friends.', 'tr' => 'Fotoğraf galerisi yalnızca kabul edilen arkadaşlara görünür.' ),
			'upload_photo'          => array( 'fa' => '＋ آپلود عکس', 'en' => '＋ Upload photo', 'tr' => '＋ Fotoğraf yükle' ),
			'like'                  => array( 'fa' => 'لایک', 'en' => 'Like', 'tr' => 'Beğen' ),
			'report'                => array( 'fa' => 'گزارش تخلف', 'en' => 'Report', 'tr' => 'Bildir' ),
			'report_reason'         => array( 'fa' => 'دلیل گزارش', 'en' => 'Reason for report', 'tr' => 'Bildirim nedeni' ),
			'reason_nudity'         => array( 'fa' => 'محتوای نامناسب', 'en' => 'Inappropriate content', 'tr' => 'Uygunsuz içerik' ),
			'reason_fake'           => array( 'fa' => 'عکس جعلی / متعلق به دیگری', 'en' => 'Fake or stolen photo', 'tr' => 'Sahte veya çalıntı fotoğraf' ),
			'reason_spam'           => array( 'fa' => 'تبلیغات و اسپم', 'en' => 'Spam or advertising', 'tr' => 'Spam veya reklam' ),
			'reason_other'          => array( 'fa' => 'سایر موارد', 'en' => 'Other', 'tr' => 'Diğer' ),
			'report_sent'           => array( 'fa' => 'گزارش شما ثبت شد و بررسی می‌شود.', 'en' => 'Your report has been submitted for review.', 'tr' => 'Bildiriminiz incelenmek üzere gönderildi.' ),
			'photo_pending'         => array( 'fa' => 'در انتظار تایید', 'en' => 'Pending approval', 'tr' => 'Onay bekliyor' ),
			'add_friend'            => array( 'fa' => '➕ افزودن دوست', 'en' => '➕ Add friend', 'tr' => '➕ Arkadaş ekle' ),
			'friend_pending'        => array( 'fa' => 'درخواست ارسال شد', 'en' => 'Request sent', 'tr' => 'İstek gönderildi' ),
			'friend_accepted'       => array( 'fa' => 'دوست شما', 'en' => 'Your friend', 'tr' => 'Arkadaşınız' ),
			'friend_requests'       => array( 'fa' => 'درخواست‌های دوستی', 'en' => 'Friend requests', 'tr' => 'Arkadaşlık istekleri' ),
			'accept'                => array( 'fa' => 'پذیرفتن', 'en' => 'Accept', 'tr' => 'Kabul et' ),
			'reject'                => array( 'fa' => 'رد کردن', 'en' => 'Reject', 'tr' => 'Reddet' ),
			'blocked_user'          => array( 'fa' => 'دسترسی به این کاربر مسدود است.', 'en' => 'This user is blocked.', 'tr' => 'Bu kullanıcı engellenmiş.' ),
			'my_events'             => array( 'fa' => 'تاریخچه دورهمی‌ها', 'en' => 'Event history', 'tr' => 'Etkinlik geçmişi' ),

			// Feedback.
			'feedback_title'        => array( 'fa' => 'نظرسنجی پس از دورهمی', 'en' => 'Post-event feedback', 'tr' => 'Etkinlik sonrası değerlendirme' ),
			'feedback_intro'        => array( 'fa' => 'تجربه‌ات از هم‌میزی‌ها چطور بود؟', 'en' => 'How was your experience with your table mates?', 'tr' => 'Masa arkadaşlarınızla deneyiminiz nasıldı?' ),
			'feedback_comment'      => array( 'fa' => 'نظر شما (اختیاری)', 'en' => 'Your comment (optional)', 'tr' => 'Yorumunuz (isteğe bağlı)' ),
			'feedback_block'        => array( 'fa' => 'مسدودسازی این کاربر برای دورهمی‌های بعدی', 'en' => 'Block this user from future tables', 'tr' => 'Bu kullanıcıyı gelecekteki masalardan engelle' ),
			'feedback_sent'         => array( 'fa' => 'ممنون! نظر شما ثبت شد.', 'en' => 'Thanks! Your feedback was recorded.', 'tr' => 'Teşekkürler! Değerlendirmeniz kaydedildi.' ),
			'feedback_pending'      => array( 'fa' => 'یک نظرسنجی در انتظار شماست', 'en' => 'You have a pending feedback', 'tr' => 'Bekleyen bir değerlendirmeniz var' ),

			// Owner portal.
			'owner_login_title'     => array( 'fa' => 'پورتال صاحبان کافه', 'en' => 'Café owner portal', 'tr' => 'Kafe sahibi portalı' ),
			'owner_panel'           => array( 'fa' => 'پنل کافه', 'en' => 'Café panel', 'tr' => 'Kafe paneli' ),
			'owner_signin'          => array( 'fa' => 'ورود', 'en' => 'Sign in', 'tr' => 'Giriş yap' ),
			'owner_signup'          => array( 'fa' => 'ثبت‌نام کافه', 'en' => 'Register café', 'tr' => 'Kafe kaydet' ),
			'email'                 => array( 'fa' => 'ایمیل', 'en' => 'Email', 'tr' => 'E-posta' ),
			'password'              => array( 'fa' => 'رمز عبور', 'en' => 'Password', 'tr' => 'Şifre' ),
			'venue_name'            => array( 'fa' => 'نام کافه', 'en' => 'Café name', 'tr' => 'Kafe adı' ),
			'manager_name'          => array( 'fa' => 'نام مدیر کافه/رستوران', 'en' => 'Café manager name', 'tr' => 'Kafe yöneticisinin adı' ),
			'venue_address'         => array( 'fa' => 'آدرس', 'en' => 'Address', 'tr' => 'Adres' ),
			'venue_phone'           => array( 'fa' => 'شماره تماس کافه', 'en' => 'Café phone number', 'tr' => 'Kafe telefon numarası' ),
			'venue_phone_hint'      => array( 'fa' => 'فقط برای مدیر سایت نمایش داده می‌شود و در اختیار کاربران قرار نمی‌گیرد.', 'en' => 'Visible to the site administrator only; never shown to guests.', 'tr' => 'Yalnızca site yöneticisine görünür; misafirlere asla gösterilmez.' ),
			'owner_pending_notice'  => array( 'fa' => 'کافه شما در انتظار تایید مدیریت است؛ تا تایید نهایی برای کاربران نمایش داده نمی‌شود.', 'en' => 'Your café is pending administrator approval and is hidden from users until verified.', 'tr' => 'Kafeniz yönetici onayı bekliyor ve onaylanana kadar kullanıcılara gösterilmiyor.' ),
			'utilization'           => array( 'fa' => 'بهره‌وری', 'en' => 'Utilization', 'tr' => 'Doluluk' ),
			'members_at_table'      => array( 'fa' => 'اعضای این میز', 'en' => 'Members at this table', 'tr' => 'Bu masadaki kişiler' ),
			'check_in'              => array( 'fa' => '✅ حضور تایید شد', 'en' => '✅ Checked in', 'tr' => '✅ Giriş yapıldı' ),
			'not_checked_in'        => array( 'fa' => 'ثبت حضور', 'en' => 'Check in', 'tr' => 'Giriş yap' ),
			'menu_item_name'        => array( 'fa' => 'نام محصول', 'en' => 'Item name', 'tr' => 'Ürün adı' ),
			'menu_item_price'       => array( 'fa' => 'قیمت', 'en' => 'Price', 'tr' => 'Fiyat' ),
			'menu_item_desc'        => array( 'fa' => 'توضیحات (اختیاری)', 'en' => 'Description (optional)', 'tr' => 'Açıklama (isteğe bağlı)' ),
			'menu_item_image'       => array( 'fa' => 'عکس محصول', 'en' => 'Item photo', 'tr' => 'Ürün fotoğrafı' ),
			'add_item'              => array( 'fa' => 'افزودن محصول', 'en' => 'Add item', 'tr' => 'Ürün ekle' ),
			'menu_pending_badge'    => array( 'fa' => '⏳ در انتظار تایید مدیریت کل', 'en' => '⏳ Pending head-office approval', 'tr' => '⏳ Merkez onayı bekliyor' ),
			'menu_saved_pending'    => array( 'fa' => 'منو ذخیره شد و برای تایید ارسال گردید.', 'en' => 'Menu saved and submitted for approval.', 'tr' => 'Menü kaydedildi ve onaya gönderildi.' ),
			'drag_pin'              => array( 'fa' => 'پین را روی موقعیت دقیق کافه بکشید (ذخیره خودکار).', 'en' => 'Drag the pin to your exact location (auto-saved).', 'tr' => 'İşareti tam konumunuza sürükleyin (otomatik kaydedilir).' ),
			'cover_image'           => array( 'fa' => 'عکس کاور', 'en' => 'Cover image', 'tr' => 'Kapak görseli' ),

			// Admin.
			'admin_dashboard'       => array( 'fa' => 'داشبورد آمار', 'en' => 'Statistics dashboard', 'tr' => 'İstatistik paneli' ),
			'admin_approvals'       => array( 'fa' => 'تایید صلاحیت و منوها', 'en' => 'Approvals & menus', 'tr' => 'Onaylar ve menüler' ),
			'admin_events'          => array( 'fa' => 'رویدادها و اعضا', 'en' => 'Events & guests', 'tr' => 'Etkinlikler ve misafirler' ),
			'admin_venues'          => array( 'fa' => 'همه کافه‌ها', 'en' => 'All cafés', 'tr' => 'Tüm kafeler' ),
			'admin_import'          => array( 'fa' => 'افزودن گروهی کافه', 'en' => 'Bulk import cafés', 'tr' => 'Toplu kafe içe aktarma' ),
			'import_hint'           => array( 'fa' => 'لیست کافه‌ها را به‌صورت JSON اینجا بچسبانید. هر آیتم باید name، city، latitude و longitude داشته باشد. کافه‌های تکراری دوباره ساخته نمی‌شوند.', 'en' => 'Paste a JSON list of cafés. Each item needs name, city, latitude and longitude. Duplicates are skipped.', 'tr' => 'Kafelerin JSON listesini yapıştırın. Her kayıtta ad, şehir, enlem ve boylam olmalı. Tekrarlananlar atlanır.' ),
			'import_cities'         => array( 'fa' => 'شهرهای مجاز:', 'en' => 'Supported cities:', 'tr' => 'Desteklenen şehirler:' ),
			'import_verified'       => array( 'fa' => 'کافه‌ها بلافاصله تاییدشده و برای کاربران قابل مشاهده باشند', 'en' => 'Publish immediately (verified and visible to guests)', 'tr' => 'Hemen yayınla (onaylı ve misafirlere görünür)' ),
			'import_run'            => array( 'fa' => 'افزودن کافه‌ها', 'en' => 'Import cafés', 'tr' => 'Kafeleri içe aktar' ),
			'import_done'           => array( 'fa' => '%d کافه اضافه شد، %d مورد تکراری رد شد.', 'en' => '%d cafés added, %d duplicates skipped.', 'tr' => '%d kafe eklendi, %d tekrar atlandı.' ),
			'import_bad_json'       => array( 'fa' => 'ساختار JSON نامعتبر است.', 'en' => 'Invalid JSON.', 'tr' => 'Geçersiz JSON.' ),
			'import_failed_rows'    => array( 'fa' => 'ردیف‌های ناموفق', 'en' => 'Failed rows', 'tr' => 'Başarısız satırlar' ),
			'demo_title'            => array( 'fa' => 'محتوای نمونه', 'en' => 'Demo content', 'tr' => 'Demo içerik' ),
			'demo_hint'             => array( 'fa' => 'کافه‌های نمونه تهران، اصفهان و استانبول به‌همراه میز و دورهمی ساخته می‌شوند تا بتوانید کل جریان را امتحان کنید. با دکمه حذف، فقط همین محتوای نمونه پاک می‌شود و کافه‌های واقعی دست‌نخورده می‌مانند.', 'en' => 'Creates sample cafés in Tehran, Isfahan and Istanbul with tables and events so you can walk through the whole flow. Removing it deletes only this sample data — real cafés are never touched.', 'tr' => 'Tüm akışı deneyebilmeniz için Tahran, İsfahan ve İstanbul’da masaları ve etkinlikleriyle örnek kafeler oluşturur. Kaldırmak yalnızca bu örnek veriyi siler — gerçek kafelere asla dokunulmaz.' ),
			'demo_create'           => array( 'fa' => 'ساخت محتوای نمونه', 'en' => 'Generate demo content', 'tr' => 'Demo içerik oluştur' ),
			'demo_remove'           => array( 'fa' => 'حذف محتوای نمونه', 'en' => 'Delete demo content', 'tr' => 'Demo içeriği sil' ),
			'demo_confirm'          => array( 'fa' => 'همه کافه‌ها و دورهمی‌های نمونه حذف شوند؟ کافه‌های واقعی حذف نمی‌شوند.', 'en' => 'Delete all demo cafés and events? Real cafés will not be removed.', 'tr' => 'Tüm demo kafeler ve etkinlikler silinsin mi? Gerçek kafeler kaldırılmaz.' ),
			'demo_present'          => array( 'fa' => 'هم‌اکنون %d کافه و %d دورهمی نمونه موجود است', 'en' => 'Currently %d demo cafés and %d demo events', 'tr' => 'Şu anda %d demo kafe ve %d demo etkinlik var' ),
			'demo_created'          => array( 'fa' => '%d کافه و %d دورهمی نمونه ساخته شد (%d مورد تکراری رد شد).', 'en' => 'Created %d demo cafés and %d demo events (%d duplicates skipped).', 'tr' => '%d demo kafe ve %d demo etkinlik oluşturuldu (%d tekrar atlandı).' ),
			'demo_removed'          => array( 'fa' => '%d کافه و %d دورهمی نمونه حذف شد.', 'en' => 'Removed %d demo cafés and %d demo events.', 'tr' => '%d demo kafe ve %d demo etkinlik kaldırıldı.' ),
			'demo_none'             => array( 'fa' => 'محتوای نمونه‌ای برای حذف وجود ندارد.', 'en' => 'There is no demo content to remove.', 'tr' => 'Kaldırılacak demo içerik yok.' ),
			'event_title'           => array( 'fa' => 'عنوان دورهمی', 'en' => 'Event title', 'tr' => 'Etkinlik başlığı' ),
			'event_title_hint'      => array( 'fa' => 'مثلاً: شب فیلم، گپ استارتاپی', 'en' => 'e.g. Movie night, Startup talk', 'tr' => 'örn. Film gecesi, Girişim sohbeti' ),
			'admin_matcher'         => array( 'fa' => 'اجرای تطابق هوشمند', 'en' => 'Run smart matching', 'tr' => 'Akıllı eşleştirmeyi çalıştır' ),
			'admin_weights'         => array( 'fa' => 'تنظیم ضرایب فرمول', 'en' => 'Formula weights', 'tr' => 'Formül ağırlıkları' ),
			'admin_google'          => array( 'fa' => 'تنظیمات ورود با گوگل', 'en' => 'Google sign-in', 'tr' => 'Google girişi' ),
			'admin_locale'          => array( 'fa' => 'تنظیمات زبان و منطقه', 'en' => 'Language & region', 'tr' => 'Dil ve bölge' ),
			'admin_theme'           => array( 'fa' => 'ظاهر و تم', 'en' => 'Appearance & theme', 'tr' => 'Görünüm ve tema' ),
			'theme_intro'           => array(
				'fa' => 'یک تم را انتخاب کنید تا رنگ‌بندی کل اپلیکیشن تغییر کند. تغییر آنی است و روی داده‌ها اثری ندارد.',
				'en' => 'Pick a theme to repaint the whole app. The change is instant and touches no data.',
				'tr' => 'Tüm uygulamayı yeniden renklendirmek için bir tema seçin. Değişiklik anında olur ve hiçbir veriye dokunmaz.',
			),
			'theme_active'          => array( 'fa' => 'تم فعال', 'en' => 'Active theme', 'tr' => 'Aktif tema' ),
			'theme_apply'           => array( 'fa' => 'اعمال این تم', 'en' => 'Apply this theme', 'tr' => 'Bu temayı uygula' ),
			'theme_applied'         => array( 'fa' => 'تم با موفقیت تغییر کرد.', 'en' => 'Theme changed successfully.', 'tr' => 'Tema başarıyla değiştirildi.' ),
			'theme_in_use'          => array( 'fa' => 'در حال استفاده', 'en' => 'In use', 'tr' => 'Kullanımda' ),
			'theme_custom'          => array( 'fa' => 'تم دلخواه', 'en' => 'Custom theme', 'tr' => 'Özel tema' ),
			'theme_custom_hint'     => array(
				'fa' => 'فقط رنگ اصلی را انتخاب کنید؛ بقیه‌ی سایه‌ها خودکار ساخته می‌شوند. اگر رنگ برای متن سفید روشن باشد، خودکار تیره‌تر می‌شود.',
				'en' => 'Pick the main colour; every other shade is derived. Too light for white text? It is darkened automatically.',
				'tr' => 'Ana rengi seçin; diğer tüm tonlar türetilir. Beyaz yazı için fazla açık mı? Otomatik olarak koyulaştırılır.',
			),
			'theme_base_colour'     => array( 'fa' => 'رنگ اصلی', 'en' => 'Main colour', 'tr' => 'Ana renk' ),
			'theme_accent_colour'   => array( 'fa' => 'رنگ دکمه شناور', 'en' => 'Accent (floating button)', 'tr' => 'Vurgu (yüzen düğme)' ),
			'theme_preview'         => array( 'fa' => 'پیش‌نمایش', 'en' => 'Preview', 'tr' => 'Önizleme' ),
			'theme_contrast'        => array( 'fa' => 'کنتراست متن سفید', 'en' => 'White-text contrast', 'tr' => 'Beyaz yazı kontrastı' ),
			'theme_contrast_ok'     => array( 'fa' => 'قابل قبول', 'en' => 'Passes AA', 'tr' => 'AA geçer' ),
			'theme_developer_note'  => array(
				'fa' => 'توسعه‌دهندگان می‌توانند با فیلتر havato_themes تم جدید اضافه کنند؛ تم بدون هیچ تغییر دیگری در این صفحه ظاهر می‌شود.',
				'en' => 'Developers can register more themes with the havato_themes filter; they appear here automatically.',
				'tr' => 'Geliştiriciler havato_themes filtresiyle yeni temalar ekleyebilir; temalar burada otomatik görünür.',
			),
			'stat_active_users'     => array( 'fa' => 'کاربران فعال', 'en' => 'Active users', 'tr' => 'Aktif kullanıcı' ),
			'stat_matched_tables'   => array( 'fa' => 'میزهای مطابقت‌یافته', 'en' => 'Matched tables', 'tr' => 'Eşleşen masa' ),
			'stat_venues'           => array( 'fa' => 'مکان‌های ثبت‌شده', 'en' => 'Registered venues', 'tr' => 'Kayıtlı mekân' ),
			'stat_signups'          => array( 'fa' => 'ثبت‌نام‌ها', 'en' => 'Sign-ups', 'tr' => 'Kayıt' ),
			'stat_attended'         => array( 'fa' => 'دورهمی‌های حاضر شده', 'en' => 'Gatherings attended', 'tr' => 'Katılınan buluşma' ),
			'rating_count'          => array( 'fa' => 'تعداد بازخوردها', 'en' => 'Ratings received', 'tr' => 'Alınan değerlendirme' ),
			'col_order'             => array( 'fa' => 'ترتیب', 'en' => 'Order', 'tr' => 'Sıra' ),
			'col_manager'           => array( 'fa' => 'مدیر', 'en' => 'Manager', 'tr' => 'Yönetici' ),
			'col_location'          => array( 'fa' => 'مکان', 'en' => 'Location', 'tr' => 'Konum' ),
			'col_message'           => array( 'fa' => 'متن پیام', 'en' => 'Message', 'tr' => 'Mesaj' ),
			'col_date'              => array( 'fa' => 'تاریخ', 'en' => 'Date', 'tr' => 'Tarih' ),
			'col_status'            => array( 'fa' => 'وضعیت', 'en' => 'Status', 'tr' => 'Durum' ),
			'badge_pending'         => array( 'fa' => 'در انتظار تایید', 'en' => 'Pending', 'tr' => 'Bekliyor' ),
			'verify_action'         => array( 'fa' => '✓ تایید صلاحیت', 'en' => '✓ Verify', 'tr' => '✓ Onayla' ),
			'weight_location'       => array( 'fa' => 'وزن مکان', 'en' => 'Location weight', 'tr' => 'Konum ağırlığı' ),
			'weight_time'           => array( 'fa' => 'وزن زمان پیشنهادی', 'en' => 'Suggested-time weight', 'tr' => 'Önerilen saat ağırlığı' ),
			'weight_density'        => array( 'fa' => 'تراکم مکان', 'en' => 'Venue density', 'tr' => 'Mekân yoğunluğu' ),
			'live_console'          => array( 'fa' => 'کنسول زنده موتور تطابق', 'en' => 'Live matcher console', 'tr' => 'Canlı eşleştirme konsolu' ),
			'havato_role'           => array( 'fa' => 'نقش هواتو', 'en' => 'Havato role', 'tr' => 'Havato rolü' ),
			'venue_status'          => array( 'fa' => 'وضعیت کافه', 'en' => 'Café status', 'tr' => 'Kafe durumu' ),
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
