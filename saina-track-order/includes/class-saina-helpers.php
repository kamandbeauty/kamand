<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Saina_TO_Helpers {

	public static function defaults() {
		return array(
			'progress_bar'      => 'yes',
			'icons_column'      => 'yes',
			'ajax_search'       => 'yes',
			'confirm_delivery'  => 'yes',
			'disable_virtual'   => 'yes',
			'email_embed'       => 'yes',
			'captcha'           => 'math',
			'track_mode'        => 'any',
			'default_carrier'   => 'post',
			'auto_deliver_days' => 7,
			'recaptcha_site'    => '',
			'recaptcha_secret'  => '',
			'sms_enabled'       => 'yes',
			'statuses'          => self::default_statuses(),
		);
	}

	public static function default_statuses() {
		return array(
			'processing' => array(
				'label' => 'در حال انجام',
				'color' => '#0d9488',
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
				'label' => 'تکمیل شده / ارسال',
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
			'post'         => array(
				'name' => 'پست پیشتاز',
				'url'  => 'https://tracking.post.ir/',
			),
			'post-custom'  => array(
				'name' => 'پست سفارشی',
				'url'  => 'https://tracking.post.ir/',
			),
			'chapar'       => array(
				'name' => 'چاپار',
				'url'  => 'https://chapar.ir/',
			),
			'tipax'        => array(
				'name' => 'تیپاکس',
				'url'  => 'https://tipaxco.com/',
			),
			'alopeyk'      => array(
				'name' => 'الوپیک',
				'url'  => 'https://alopeyk.com/',
			),
			'snapp'        => array(
				'name' => 'اسنپ‌باکس',
				'url'  => 'https://snapp.ir/',
			),
			'peyk'         => array(
				'name' => 'پیک موتوری فروشگاه',
				'url'  => '',
			),
			'custom'       => array(
				'name' => 'سایر',
				'url'  => '',
			),
		);
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
		$map = array(
			'pending'          => 0,
			'processing'       => 0,
			'on-hold'          => 1,
			'saina-packing'    => 2,
			'packing'          => 2,
			'completed'        => 3,
			'saina-delivered'  => 4,
			'delivered'        => 4,
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
		$order->update_meta_data( '_saina_status_changed_' . time(), current_time( 'mysql' ) );
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
