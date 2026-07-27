<?php
/**
 * WooCommerce integration — real checkout, no simulated wallet.
 *
 * The plugin owns a single hidden virtual product ("Havato ticket") whose price
 * is overridden per event through cart item data, so every event can have its
 * own live price while still going through the normal Woo/Shetab gateways.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Checkout bridge.
 */
class Havato_Woo {

	/**
	 * Register hooks.
	 */
	public static function init() {
		add_action( 'woocommerce_before_calculate_totals', array( __CLASS__, 'apply_ticket_price' ), 20 );
		add_filter( 'woocommerce_get_item_data', array( __CLASS__, 'cart_item_meta' ), 10, 2 );
		add_action( 'woocommerce_checkout_create_order_line_item', array( __CLASS__, 'order_line_meta' ), 10, 4 );
		add_action( 'woocommerce_order_status_processing', array( __CLASS__, 'confirm_seat' ) );
		add_action( 'woocommerce_order_status_completed', array( __CLASS__, 'confirm_seat' ) );
		add_action( 'woocommerce_payment_complete', array( __CLASS__, 'confirm_seat' ) );
	}

	/**
	 * Get (or lazily create) the virtual ticket product.
	 *
	 * @return int Product id, 0 when Woo is unavailable.
	 */
	public static function ticket_product_id() {
		if ( ! havato_woo_active() ) {
			return 0;
		}

		$pid = (int) Havato_Settings::get( 'wc_product_id', 0 );
		if ( $pid && 'product' === get_post_type( $pid ) && 'trash' !== get_post_status( $pid ) ) {
			return $pid;
		}

		$product = new WC_Product_Simple();
		$product->set_name( 'Havato Table Ticket — بلیت میز هواتو' );
		$product->set_status( 'private' );
		$product->set_catalog_visibility( 'hidden' );
		$product->set_virtual( true );
		$product->set_sold_individually( true );
		$product->set_regular_price( (string) Havato_Settings::get( 'default_ticket_price', 45000 ) );
		$product->set_price( (string) Havato_Settings::get( 'default_ticket_price', 45000 ) );
		$pid = $product->save();

		Havato_Settings::update( array( 'wc_product_id' => (int) $pid ) );

		return (int) $pid;
	}

	/**
	 * Empty the cart, add the ticket for one event and return the checkout URL.
	 *
	 * @param array $event Event row.
	 * @param int   $user_id User id.
	 * @return array{ok:bool,url:string,message:string}
	 */
	public static function create_checkout( $event, $user_id ) {
		if ( ! havato_woo_active() ) {
			return array(
				'ok'      => false,
				'url'     => '',
				'message' => 'WooCommerce is not active.',
			);
		}

		$pid = self::ticket_product_id();
		if ( ! $pid ) {
			return array( 'ok' => false, 'url' => '', 'message' => 'Ticket product missing.' );
		}

		if ( is_null( WC()->cart ) && function_exists( 'wc_load_cart' ) ) {
			wc_load_cart();
		}

		if ( is_null( WC()->cart ) ) {
			return array( 'ok' => false, 'url' => '', 'message' => 'Cart is not available.' );
		}

		WC()->cart->empty_cart();

		$price = (int) $event['price'];
		if ( $price <= 0 ) {
			$price = (int) Havato_Settings::get( 'default_ticket_price', 45000 );
		}

		WC()->cart->add_to_cart(
			$pid,
			1,
			0,
			array(),
			array(
				'havato_event_id' => $event['id'],
				'havato_price'    => $price,
				'havato_user'     => (int) $user_id,
				'havato_venue'    => $event['venue_id'],
			)
		);

		return array(
			'ok'      => true,
			'url'     => wc_get_checkout_url(),
			'message' => '',
		);
	}

	/**
	 * Force the live event price on the cart line.
	 *
	 * @param WC_Cart $cart Cart.
	 */
	public static function apply_ticket_price( $cart ) {
		if ( is_admin() && ! defined( 'DOING_AJAX' ) ) {
			return;
		}
		if ( ! $cart instanceof WC_Cart ) {
			return;
		}

		foreach ( $cart->get_cart() as $item ) {
			if ( isset( $item['havato_price'] ) && $item['havato_price'] > 0 ) {
				$item['data']->set_price( (float) $item['havato_price'] );
			}
		}
	}

	/**
	 * Show the event on the checkout line.
	 *
	 * @param array $data Item data.
	 * @param array $item Cart item.
	 * @return array
	 */
	public static function cart_item_meta( $data, $item ) {
		if ( empty( $item['havato_event_id'] ) ) {
			return $data;
		}

		global $wpdb;
		$events = Havato_DB::table( 'events' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$event = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $events WHERE id=%s", $item['havato_event_id'] ), ARRAY_A );

		if ( $event ) {
			$data[] = array(
				'name'  => Havato_I18N::t( 'explore_title' ),
				'value' => havato_date( $event['event_date'] ) . ' — ' . substr( $event['event_time'], 0, 5 ),
			);
		}

		return $data;
	}

	/**
	 * Persist the event id on the order line item.
	 *
	 * @param WC_Order_Item_Product $line   Line item.
	 * @param string                $key    Cart key.
	 * @param array                 $values Cart values.
	 * @param WC_Order              $order  Order.
	 */
	public static function order_line_meta( $line, $key, $values, $order ) {
		if ( ! empty( $values['havato_event_id'] ) ) {
			$line->add_meta_data( '_havato_event_id', $values['havato_event_id'], true );
			$line->add_meta_data( '_havato_venue_id', isset( $values['havato_venue'] ) ? $values['havato_venue'] : '', true );
			$line->add_meta_data( '_havato_user_id', isset( $values['havato_user'] ) ? (int) $values['havato_user'] : 0, true );
		}
	}

	/**
	 * On successful payment: finalize the seat in the queue and try matching.
	 *
	 * @param int $order_id Order id.
	 */
	public static function confirm_seat( $order_id ) {
		if ( ! havato_woo_active() ) {
			return;
		}

		$order = wc_get_order( $order_id );
		if ( ! $order ) {
			return;
		}

		if ( $order->get_meta( '_havato_seat_confirmed' ) ) {
			return;
		}

		global $wpdb;
		Havato_DB::ensure_tables();
		$regs = Havato_DB::table( 'event_registrations' );

		$touched = false;

		foreach ( $order->get_items() as $item ) {
			$event_id = $item->get_meta( '_havato_event_id' );
			if ( ! $event_id ) {
				continue;
			}

			$user_id = (int) $item->get_meta( '_havato_user_id' );
			if ( ! $user_id ) {
				$user_id = (int) $order->get_user_id();
			}
			if ( ! $user_id ) {
				continue;
			}

			$amount = (int) $order->get_total();

			// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$exists = $wpdb->get_var( $wpdb->prepare( "SELECT id FROM $regs WHERE event_id=%s AND user_id=%d", $event_id, $user_id ) );

			if ( $exists ) {
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->update(
					$regs,
					array( 'status' => 'queued', 'order_id' => (int) $order_id, 'amount' => $amount ),
					array( 'id' => (int) $exists ),
					array( '%s', '%d', '%d' ),
					array( '%d' )
				);
			} else {
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->insert(
					$regs,
					array(
						'event_id'   => $event_id,
						'user_id'    => $user_id,
						'status'     => 'queued',
						'order_id'   => (int) $order_id,
						'amount'     => $amount,
						'created_at' => havato_now(),
					),
					array( '%s', '%d', '%s', '%d', '%d', '%s' )
				);
			}

			Havato_Logger::log( sprintf( 'Payment confirmed (order #%d) — seat secured for user %d.', $order_id, $user_id ), 'success' );

			// PRIMARY matcher path.
			Havato_Matcher::maybe_run_on_full( $event_id );
			$touched = true;
		}

		if ( $touched ) {
			$order->update_meta_data( '_havato_seat_confirmed', 1 );
			$order->save();
		}
	}
}
