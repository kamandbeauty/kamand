<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Saina_TO_Ajax {

	public static function init() {
		add_action( 'wp_ajax_saina_track_order', array( __CLASS__, 'track' ) );
		add_action( 'wp_ajax_nopriv_saina_track_order', array( __CLASS__, 'track' ) );
		add_action( 'wp_ajax_saina_confirm_delivery', array( __CLASS__, 'confirm' ) );
		add_action( 'wp_ajax_nopriv_saina_confirm_delivery', array( __CLASS__, 'confirm' ) );
	}

	public static function track() {
		check_ajax_referer( 'saina_to_front', 'nonce' );
		$settings = Saina_TO_Helpers::get_settings();

		if ( 'math' === $settings['captcha'] ) {
			$answer = isset( $_POST['captcha'] ) ? Saina_TO_Helpers::to_en( wp_unslash( $_POST['captcha'] ) ) : '';
			$expect = isset( $_POST['captcha_hash'] ) ? sanitize_text_field( wp_unslash( $_POST['captcha_hash'] ) ) : '';
			if ( ! hash_equals( $expect, wp_hash( $answer . '|' . wp_salt( 'nonce' ) ) ) ) {
				wp_send_json_error( array( 'message' => 'پاسخ کپچا نادرست است.' ) );
			}
		}

		$order_id = isset( $_POST['order_id'] ) ? Saina_TO_Helpers::to_en( sanitize_text_field( wp_unslash( $_POST['order_id'] ) ) ) : '';
		$mobile   = isset( $_POST['mobile'] ) ? Saina_TO_Helpers::normalize_phone( wp_unslash( $_POST['mobile'] ) ) : '';
		$email    = isset( $_POST['email'] ) ? sanitize_email( wp_unslash( $_POST['email'] ) ) : '';
		$mode     = $settings['track_mode'];

		if ( 'order_mobile' === $mode && ( '' === $order_id || '' === $mobile ) ) {
			wp_send_json_error( array( 'message' => 'شماره سفارش و موبایل هر دو لازم است.' ) );
		}
		if ( 'order_email' === $mode && ( '' === $order_id || '' === $email ) ) {
			wp_send_json_error( array( 'message' => 'شماره سفارش و ایمیل هر دو لازم است.' ) );
		}
		if ( '' === $order_id && '' === $mobile && '' === $email ) {
			wp_send_json_error( array( 'message' => 'یکی از فیلدهای پیگیری را وارد کنید.' ) );
		}

		$orders = self::query_orders( $order_id, $mobile, $email, $mode );
		if ( empty( $orders ) ) {
			wp_send_json_error( array( 'message' => 'سفارشی با این مشخصات یافت نشد.' ) );
		}

		$html = '';
		foreach ( $orders as $order ) {
			$html .= Saina_TO_Frontend::render_order_card( $order, $settings );
		}
		wp_send_json_success( array( 'html' => $html ) );
	}

	public static function confirm() {
		check_ajax_referer( 'saina_to_front', 'nonce' );
		$settings = Saina_TO_Helpers::get_settings();
		if ( 'yes' !== $settings['confirm_delivery'] ) {
			wp_send_json_error( array( 'message' => 'این قابلیت غیرفعال است.' ) );
		}
		$order_id = absint( $_POST['order_id'] ?? 0 );
		$order    = wc_get_order( $order_id );
		if ( ! $order ) {
			wp_send_json_error( array( 'message' => 'سفارش یافت نشد.' ) );
		}
		$email  = sanitize_email( wp_unslash( $_POST['email'] ?? '' ) );
		$mobile = Saina_TO_Helpers::normalize_phone( wp_unslash( $_POST['mobile'] ?? '' ) );
		$ok     = false;
		if ( is_user_logged_in() && (int) $order->get_user_id() === get_current_user_id() ) {
			$ok = true;
		}
		if ( $email && strtolower( $order->get_billing_email() ) === strtolower( $email ) ) {
			$ok = true;
		}
		if ( $mobile && Saina_TO_Helpers::normalize_phone( $order->get_billing_phone() ) === $mobile ) {
			$ok = true;
		}
		if ( ! $ok ) {
			wp_send_json_error( array( 'message' => 'اجازه تأیید این سفارش را ندارید.' ) );
		}
		$order->update_status( 'saina-delivered', 'تأیید دریافت توسط مشتری از فرم ساینا.' );
		wp_send_json_success( array( 'message' => 'وضعیت سفارش به تحویل‌شده تغییر کرد.', 'html' => Saina_TO_Frontend::render_order_card( $order, $settings ) ) );
	}

	protected static function query_orders( $order_id, $mobile, $email, $mode ) {
		$found = array();
		if ( $order_id ) {
			$order_id = ltrim( $order_id, '#' );
			$order    = wc_get_order( absint( $order_id ) );
			if ( $order ) {
				$match = true;
				if ( 'order_mobile' === $mode || ( $mobile && $order_id ) ) {
					$match = $match && Saina_TO_Helpers::normalize_phone( $order->get_billing_phone() ) === $mobile;
				}
				if ( 'order_email' === $mode || ( $email && $order_id && ! $mobile ) ) {
					$match = $match && strtolower( $order->get_billing_email() ) === strtolower( $email );
				}
				if ( $match ) {
					$found[] = $order;
				}
			}
			return $found;
		}

		$args = array(
			'limit'   => 4,
			'orderby' => 'date',
			'order'   => 'DESC',
			'return'  => 'objects',
		);
		if ( $mobile ) {
			$args['billing_phone'] = $mobile;
		}
		if ( $email ) {
			$args['billing_email'] = $email;
		}
		$orders = wc_get_orders( $args );
		if ( $mobile && empty( $orders ) ) {
			$orders = wc_get_orders(
				array(
					'limit'      => 20,
					'meta_query' => array(
						array(
							'key'     => '_billing_phone',
							'value'   => substr( $mobile, -10 ),
							'compare' => 'LIKE',
						),
					),
				)
			);
			$filtered = array();
			foreach ( $orders as $order ) {
				if ( Saina_TO_Helpers::normalize_phone( $order->get_billing_phone() ) === $mobile ) {
					$filtered[] = $order;
				}
				if ( count( $filtered ) >= 4 ) {
					break;
				}
			}
			$orders = $filtered;
		}
		return $orders;
	}
}
