<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Saina_TO_Plugin {

	protected static $instance;

	public static function instance() {
		if ( ! self::$instance ) {
			self::$instance = new self();
		}
		return self::$instance;
	}

	public function __construct() {
		if ( ! class_exists( 'WooCommerce' ) ) {
			add_action( 'admin_notices', array( $this, 'need_wc' ) );
			return;
		}
		Saina_TO_Statuses::init();
		Saina_TO_SMS::init();
		Saina_TO_Ajax::init();
		Saina_TO_Frontend::init();
		Saina_TO_Admin::init();
		add_filter( 'plugin_action_links_' . plugin_basename( SAINA_TO_FILE ), array( $this, 'links' ) );
		add_action( 'woocommerce_order_status_completed', array( $this, 'tapin_sync' ), 30 );
	}

	public function need_wc() {
		echo '<div class="notice notice-error"><p>افزونه ساینا پیگیری سفارشات به ووکامرس نیاز دارد.</p></div>';
	}

	public function links( $links ) {
		$url     = admin_url( 'admin.php?page=saina-track-order' );
		$links[] = '<a href="' . esc_url( $url ) . '">تنظیمات</a>';
		return $links;
	}

	public function tapin_sync( $order_id ) {
		$order = wc_get_order( $order_id );
		if ( ! $order ) {
			return;
		}
		if ( $order->get_meta( '_saina_tracking_code' ) ) {
			return;
		}
		$candidates = array(
			'_tapin_tracking_code',
			'tapin_post_barcode',
			'_masir_tracking',
			'_post_barcode',
		);
		foreach ( $candidates as $key ) {
			$val = $order->get_meta( $key );
			if ( $val ) {
				$order->update_meta_data( '_saina_tracking_code', $val );
				if ( ! $order->get_meta( '_saina_carrier' ) ) {
					$order->update_meta_data( '_saina_carrier', 'post' );
				}
				$order->save();
				break;
			}
		}
		do_action( 'saina_tapin_tracking_synced', $order );
	}

	public static function activate() {
		if ( ! get_option( 'saina_to_settings' ) ) {
			update_option( 'saina_to_settings', Saina_TO_Helpers::defaults() );
		}
		Saina_TO_Helpers::create_track_page();
		if ( ! wp_next_scheduled( 'saina_to_auto_deliver' ) ) {
			wp_schedule_event( time() + HOUR_IN_SECONDS, 'daily', 'saina_to_auto_deliver' );
		}
		flush_rewrite_rules();
	}

	public static function deactivate() {
		wp_clear_scheduled_hook( 'saina_to_auto_deliver' );
		flush_rewrite_rules();
	}
}
