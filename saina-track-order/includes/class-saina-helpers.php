<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Saina_TO_Helpers {

	public static function defaults() {
		return array(
			'own_orders'               => 'no',
			'captcha'                  => 'none',
			'recaptcha_site'           => '',
			'recaptcha_secret'         => '',
			'search_order'             => 'yes',
			'search_mobile'            => 'yes',
			'search_email'             => 'yes',
			'ajax_search'              => 'yes',
			'post_new_tab'             => 'no',
			'disable_virtual'          => 'yes',
			'disable_progress_account' => 'no',
			'disable_progress_thanks'  => 'no',
			'disable_icons_column'     => 'no',
			'dokan_tracking'           => 'no',
			'skip_required'            => 'no',
			'form_placeholder'         => 'لطفا شماره موبایل یا شماره سفارش خود را وارد کنید',
			'step1_status'             => 'processing',
			'step2_status'             => 'on-hold',
			'step3_status'             => 'saina-packing',
			'step4_status'             => 'completed',
			'step4_to_post'            => 'yes',
			'step5_status'             => 'saina-delivered',
			'step5_delivered'          => 'yes',
			'enable_delivered'         => 'yes',
			'disable_confirm'          => 'no',
			'tooltip_completed'        => 'سفارش شماره {order_id} رهگیری {trackingurl} توسط {username} در تاریخ {senddate} ارسال گردیده',
			'tooltip_delivered'        => 'سفارش شماره {order_id} در تاریخ {deliverydate} تحویل مشتری گردیده',
			'tooltip_peyk_completed'   => 'سفارش شماره {order_id} توسط {peyk} در تاریخ {senddate} ارسال گردیده',
			'tooltip_peyk_delivered'   => 'سفارش شماره {order_id} در تاریخ {deliverydate} تحویل مشتری گردیده',
			'peyk_sms_status'          => 'saina-packing',
			'peyk_sms_text'            => 'سفارش شماره {order_id} در تاریخ {senddate} که رهگیری {trackingurl} تحویل پست پیشتاز گردید',
			'peyk_cities'              => '',
			'peyk_method'              => '',
			'peyk_nationwide'          => 'no',
			'show_user'                => 'yes',
			'show_payment'             => 'yes',
			'show_destination'         => 'yes',
			'show_amount'              => 'yes',
			'show_product_image'       => 'yes',
			'show_product_name'        => 'yes',
			'show_state_beside'        => 'yes',
			'shared_progress_image'    => 'no',
			'upload_form_image'        => 'no',
			'logo'                     => '',
			'icon_size'                => 32,
			'color_progress'           => '#4caf50',
			'color_form_btn'           => '#4caf50',
			'color_table_header'       => '#e0e0e0',
			'color_table_header_text'  => '#333333',
			'color_post_btn'           => '#f9a825',
			'color_post_btn_text'      => '#111111',
			'progress_style'           => 'digi',
			'progress_position'        => 'before',
			'jalali_calendar'          => 'yes',
			'auto_deliver'             => 'no',
			'auto_deliver_days'        => 1,
			'tapin_sync'               => 'no',
			'email_embed'              => 'yes',
			'sms_enabled'              => 'yes',
			'default_carrier'          => 'post',
			'statuses'                 => self::default_statuses(),
		);
	}

	public static function default_statuses() {
		return array(
			'processing' => array(
				'label' => 'در حال انجام',
				'color' => '#4caf50',
			),
			'on-hold'    => array(
				'label' => 'در حال بررسی',
				'color' => '#d97706',
			),
			'packing'    => array(
				'label' => 'بسته‌بندی',
				'color' => '#7c3aed',
			),
			'completed'  => array(
				'label' => 'تکمیل شده',
				'color' => '#2563eb',
			),
			'delivered'  => array(
				'label' => 'تحویل شده',
				'color' => '#16a34a',
			),
		);
	}

	public static function get_settings() {
		$saved = get_option( 'saina_to_settings', array() );
		return wp_parse_args( is_array( $saved ) ? $saved : array(), self::defaults() );
	}

	public static function update_settings( $settings ) {
		update_option( 'saina_to_settings', $settings );
	}

	public static function carriers() {
		return array(
			'post'        => array(
				'name' => 'پست پیشتاز',
				'url'  => 'https://tracking.post.ir/',
			),
			'post-custom' => array(
				'name' => 'پست سفارشی',
				'url'  => 'https://tracking.post.ir/',
			),
			'chapar'      => array(
				'name' => 'چاپار',
				'url'  => 'https://chapar.ir/',
			),
			'tipax'       => array(
				'name' => 'تیپاکس',
				'url'  => 'https://tipaxco.com/',
			),
			'alopeyk'     => array(
				'name' => 'الوپیک',
				'url'  => 'https://alopeyk.com/',
			),
			'snapp'       => array(
				'name' => 'اسنپ‌باکس',
				'url'  => 'https://snapp.ir/',
			),
			'peyk'        => array(
				'name' => 'پیک موتوری فروشگاه',
				'url'  => '',
			),
			'custom'      => array(
				'name' => 'سایر',
				'url'  => '',
			),
		);
	}

	public static function wc_status_choices() {
		$choices = array(
			''                 => '— پیش‌فرض مرحله —',
			'pending'          => 'در انتظار پرداخت',
			'processing'       => 'در حال انجام',
			'on-hold'          => 'در انتظار بررسی',
			'saina-packing'    => 'بسته‌بندی',
			'completed'        => 'تکمیل شده',
			'saina-delivered'  => 'تحویل شده',
			'cancelled'        => 'لغو شده',
			'refunded'         => 'مسترد شده',
			'failed'           => 'ناموفق',
		);
		if ( function_exists( 'wc_get_order_statuses' ) ) {
			foreach ( wc_get_order_statuses() as $key => $label ) {
				$slug             = str_replace( 'wc-', '', $key );
				$choices[ $slug ] = $label;
			}
		}
		return $choices;
	}

	public static function carrier_name( $id ) {
		$all = self::carriers();
		return isset( $all[ $id ] ) ? $all[ $id ]['name'] : $id;
	}

	public static function to_en( $value ) {
		$fa = array( '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹', '٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩' );
		$en = array( '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' );
		return str_replace( $fa, $en, (string) $value );
	}

	public static function to_fa( $value ) {
		$en = array( '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' );
		$fa = array( '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹' );
		return str_replace( $en, $fa, (string) $value );
	}

	public static function normalize_phone( $phone ) {
		$p = preg_replace( '/[\s-]/', '', self::to_en( $phone ) );
		if ( 0 === strpos( $p, '+98' ) ) {
			$p = '0' . substr( $p, 3 );
		} elseif ( 0 === strpos( $p, '98' ) && 12 === strlen( $p ) ) {
			$p = '0' . substr( $p, 2 );
		}
		return $p;
	}

	public static function status_index( $status ) {
		$s    = self::get_settings();
		$steps = array( $s['step1_status'], $s['step2_status'], $s['step3_status'], $s['step4_status'], $s['step5_status'] );
		$idx   = array_search( $status, $steps, true );
		if ( false !== $idx ) {
			return (int) $idx;
		}
		$map = array(
			'pending'         => 0,
			'processing'      => 0,
			'on-hold'         => 1,
			'saina-packing'   => 2,
			'packing'         => 2,
			'completed'       => 3,
			'saina-delivered' => 4,
			'delivered'       => 4,
		);
		return isset( $map[ $status ] ) ? $map[ $status ] : 0;
	}

	public static function get_order_tracking( $order ) {
		if ( ! $order ) {
			return array();
		}
		return array(
			'code'          => $order->get_meta( '_saina_tracking_code' ),
			'carrier'       => $order->get_meta( '_saina_carrier' ),
			'ship_date'     => $order->get_meta( '_saina_ship_date' ),
			'delivery_date' => $order->get_meta( '_saina_delivery_date' ),
		);
	}

	public static function save_order_tracking( $order, $data ) {
		$order->update_meta_data( '_saina_tracking_code', sanitize_text_field( $data['code'] ?? '' ) );
		$order->update_meta_data( '_saina_carrier', sanitize_text_field( $data['carrier'] ?? '' ) );
		$order->update_meta_data( '_saina_ship_date', sanitize_text_field( $data['ship_date'] ?? '' ) );
		$order->update_meta_data( '_saina_delivery_date', sanitize_text_field( $data['delivery_date'] ?? '' ) );
		$order->save();
	}

	public static function order_is_virtual( $order ) {
		foreach ( $order->get_items() as $item ) {
			$product = $item->get_product();
			if ( $product && ! $product->is_virtual() && ! $product->is_downloadable() ) {
				return false;
			}
		}
		return true;
	}

	public static function replace_tokens( $text, $order ) {
		$t = self::get_order_tracking( $order );
		return strtr(
			$text,
			array(
				'{order_id}'      => $order->get_order_number(),
				'{trackingurl}'   => $t['code'],
				'{tracking_code}' => $t['code'],
				'{username}'      => $order->get_formatted_billing_full_name(),
				'{senddate}'      => $t['ship_date'],
				'{deliverydate}'  => $t['delivery_date'],
				'{peyk}'          => self::carrier_name( $t['carrier'] ),
				'{carrier}'       => self::carrier_name( $t['carrier'] ),
			)
		);
	}

	public static function create_track_page() {
		$page = get_page_by_path( 'saina-track-order' );
		if ( $page ) {
			return $page->ID;
		}
		return wp_insert_post(
			array(
				'post_title'   => 'پیگیری سفارش',
				'post_name'    => 'saina-track-order',
				'post_status'  => 'publish',
				'post_type'    => 'page',
				'post_content' => '[saina_track_order]',
			)
		);
	}
}
