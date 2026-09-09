<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Saina_TO_Statuses {

	public static function init() {
		add_action( 'init', array( __CLASS__, 'register' ) );
		add_filter( 'wc_order_statuses', array( __CLASS__, 'add_to_list' ) );
		add_filter( 'woocommerce_register_shop_order_post_statuses', array( __CLASS__, 'register_hpos' ) );
		add_action( 'saina_to_auto_deliver', array( __CLASS__, 'auto_deliver' ) );
	}

	public static function register() {
		register_post_status(
			'wc-saina-packing',
			array(
				'label'                     => 'بسته‌بندی',
				'public'                    => true,
				'show_in_admin_status_list' => true,
				'show_in_admin_all_list'    => true,
				'exclude_from_search'       => false,
				'label_count'               => _n_noop( 'بسته‌بندی <span class="count">(%s)</span>', 'بسته‌بندی <span class="count">(%s)</span>', 'saina-track-order' ),
			)
		);
		register_post_status(
			'wc-saina-delivered',
			array(
				'label'                     => 'تحویل شده',
				'public'                    => true,
				'show_in_admin_status_list' => true,
				'show_in_admin_all_list'    => true,
				'exclude_from_search'       => false,
				'label_count'               => _n_noop( 'تحویل شده <span class="count">(%s)</span>', 'تحویل شده <span class="count">(%s)</span>', 'saina-track-order' ),
			)
		);
	}

	public static function register_hpos( $statuses ) {
		$statuses['wc-saina-packing']   = array(
			'label'                     => 'بسته‌بندی',
			'public'                    => true,
			'show_in_admin_status_list' => true,
			'show_in_admin_all_list'    => true,
			'exclude_from_search'       => false,
			'label_count'               => _n_noop( 'بسته‌بندی <span class="count">(%s)</span>', 'بسته‌بندی <span class="count">(%s)</span>', 'saina-track-order' ),
		);
		$statuses['wc-saina-delivered'] = array(
			'label'                     => 'تحویل شده',
			'public'                    => true,
			'show_in_admin_status_list' => true,
			'show_in_admin_all_list'    => true,
			'exclude_from_search'       => false,
			'label_count'               => _n_noop( 'تحویل شده <span class="count">(%s)</span>', 'تحویل شده <span class="count">(%s)</span>', 'saina-track-order' ),
		);
		return $statuses;
	}

	public static function add_to_list( $statuses ) {
		$new = array();
		foreach ( $statuses as $key => $label ) {
			$new[ $key ] = $label;
			if ( 'wc-processing' === $key ) {
				$new['wc-on-hold']          = isset( $statuses['wc-on-hold'] ) ? $statuses['wc-on-hold'] : 'در حال بررسی';
				$new['wc-saina-packing']    = 'بسته‌بندی';
			}
			if ( 'wc-completed' === $key ) {
				$new['wc-saina-delivered'] = 'تحویل شده';
			}
		}
		if ( ! isset( $new['wc-saina-packing'] ) ) {
			$new['wc-saina-packing'] = 'بسته‌بندی';
		}
		if ( ! isset( $new['wc-saina-delivered'] ) ) {
			$new['wc-saina-delivered'] = 'تحویل شده';
		}
		return $new;
	}

	public static function auto_deliver() {
		$settings = Saina_TO_Helpers::get_settings();
		$days     = max( 0, intval( $settings['auto_deliver_days'] ) );
		if ( $days < 1 ) {
			return;
		}
		$orders = wc_get_orders(
			array(
				'status'       => array( 'completed' ),
				'date_created' => '<' . ( time() - ( $days * DAY_IN_SECONDS ) ),
				'limit'        => 40,
			)
		);
		foreach ( $orders as $order ) {
			$order->update_status( 'saina-delivered', 'تبدیل خودکار ساینا از تکمیل‌شده به تحویل‌شده.' );
		}
	}
}
