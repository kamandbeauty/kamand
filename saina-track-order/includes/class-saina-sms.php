<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Saina_TO_SMS {

	public static function init() {
		add_filter( 'pws_sms_shortcodes', array( __CLASS__, 'shortcodes' ), 10, 2 );
		add_filter( 'pw_sms_shortcodes', array( __CLASS__, 'shortcodes' ), 10, 2 );
		add_filter( 'persian_woocommerce_sms_shortcodes', array( __CLASS__, 'shortcodes' ), 10, 2 );
		add_filter( 'woocommerce_sms_shortcodes', array( __CLASS__, 'shortcodes' ), 10, 2 );
		add_filter( 'woocommerce_order_status_changed', array( __CLASS__, 'maybe_note' ), 20, 4 );
	}

	public static function shortcodes( $shortcodes, $order = null ) {
		if ( ! $order && isset( $shortcodes['order'] ) ) {
			$order = $shortcodes['order'];
		}
		$code = $carrier = $ship = $delivery = '';
		if ( $order instanceof WC_Order ) {
			$t        = Saina_TO_Helpers::get_order_tracking( $order );
			$code     = $t['code'];
			$carrier  = Saina_TO_Helpers::carrier_name( $t['carrier'] );
			$ship     = $t['ship_date'];
			$delivery = $t['delivery_date'];
		}
		$map = array(
			'{tracking_code}'  => $code,
			'{saina_tracking}' => $code,
			'{carrier}'        => $carrier,
			'{saina_carrier}'  => $carrier,
			'{ship_date}'      => $ship,
			'{delivery_date}'  => $delivery,
			'{saina_ship}'     => $ship,
			'{saina_delivery}' => $delivery,
		);
		if ( is_array( $shortcodes ) ) {
			return array_merge( $shortcodes, $map );
		}
		if ( is_string( $shortcodes ) ) {
			return strtr( $shortcodes, $map );
		}
		return $shortcodes;
	}

	public static function replace_text( $text, $order ) {
		$t = Saina_TO_Helpers::get_order_tracking( $order );
		return strtr(
			$text,
			array(
				'{tracking_code}'  => $t['code'],
				'{saina_tracking}' => $t['code'],
				'{carrier}'        => Saina_TO_Helpers::carrier_name( $t['carrier'] ),
				'{saina_carrier}'  => Saina_TO_Helpers::carrier_name( $t['carrier'] ),
				'{ship_date}'      => $t['ship_date'],
				'{delivery_date}'  => $t['delivery_date'],
				'{order_id}'       => $order->get_order_number(),
				'{first_name}'     => $order->get_billing_first_name(),
			)
		);
	}

	public static function maybe_note( $order_id, $from, $to, $order ) {
		if ( ! $order instanceof WC_Order ) {
			$order = wc_get_order( $order_id );
		}
		if ( ! $order ) {
			return;
		}
		$t = Saina_TO_Helpers::get_order_tracking( $order );
		if ( empty( $t['code'] ) ) {
			return;
		}
		if ( in_array( $to, array( 'completed', 'saina-delivered' ), true ) ) {
			$order->add_order_note(
				sprintf(
					'ساینا: کد رهگیری %s | %s | ارسال %s | تحویل %s',
					$t['code'],
					Saina_TO_Helpers::carrier_name( $t['carrier'] ),
					$t['ship_date'],
					$t['delivery_date']
				)
			);
		}
	}
}
