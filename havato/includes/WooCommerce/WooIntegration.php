<?php

declare(strict_types=1);

namespace Havato\WooCommerce;

use WP_REST_Response;
use WP_Error;

if (!defined('ABSPATH')) {
    exit;
}

/**
 * WooCommerce Integration for Havato
 * Handles paid event registration, cart clearing, and automatic confirmation.
 */
final class WooIntegration
{
    public function __construct()
    {
        // Hook into WooCommerce order completion
        add_action('woocommerce_order_status_completed', [$this, 'confirmRegistrationAfterPayment'], 10, 1);
        add_action('woocommerce_order_status_processing', [$this, 'confirmRegistrationAfterPayment'], 10, 1);

        // REST endpoint for clean cart + add ticket
        add_action('rest_api_init', [$this, 'registerWooRoutes']);
    }

    /**
     * Register WooCommerce-specific REST routes.
     */
    public function registerWooRoutes(): void
    {
        register_rest_route('havato/v1', '/start-paid-registration', [
            'methods'             => 'POST',
            'callback'            => [$this, 'startPaidRegistration'],
            'permission_callback' => fn() => is_user_logged_in(),
        ]);
    }

    /**
     * Clears cart and adds the correct event ticket product.
     */
    public function startPaidRegistration(\WP_REST_Request $request): WP_REST_Response|WP_Error
    {
        if (!class_exists('WooCommerce')) {
            return new WP_Error('no_woocommerce', __('WooCommerce is not active', 'havato'), ['status' => 400]);
        }

        $eventId = absint($request->get_param('event_id'));
        if (!$eventId) {
            return new WP_Error('invalid_event', __('Invalid event', 'havato'), ['status' => 400]);
        }

        // Get event price
        global $wpdb;
        $event = $wpdb->get_row($wpdb->prepare(
            "SELECT * FROM {$wpdb->prefix}havato_events WHERE id = %d",
            $eventId
        ), ARRAY_A);

        if (!$event) {
            return new WP_Error('event_not_found', __('Event not found', 'havato'), ['status' => 404]);
        }

        // Create or get product for this event
        $productId = $this->getOrCreateEventProduct($event);

        // Clear cart
        WC()->cart->empty_cart();

        // Add to cart
        WC()->cart->add_to_cart($productId, 1, 0, [], [
            'havato_event_id' => $eventId,
            'havato_user_id'  => get_current_user_id(),
        ]);

        return new WP_REST_Response([
            'success'  => true,
            'message'  => __('Redirecting to checkout...', 'havato'),
            'checkout' => wc_get_checkout_url(),
        ], 200);
    }

    /**
     * Creates a simple WooCommerce product for the event if it doesn't exist.
     */
    private function getOrCreateEventProduct(array $event): int
    {
        $existing = get_posts([
            'post_type'   => 'product',
            'meta_key'    => '_havato_event_id',
            'meta_value'  => $event['id'],
            'numberposts' => 1,
        ]);

        if (!empty($existing)) {
            return $existing[0]->ID;
        }

        $product = new \WC_Product_Simple();
        $product->set_name($event['title']);
        $product->set_price($event['price'] ?? 0);
        $product->set_regular_price($event['price'] ?? 0);
        $product->set_virtual(true);
        $product->set_sold_individually(true);
        $product->save();

        update_post_meta($product->get_id(), '_havato_event_id', $event['id']);

        return $product->get_id();
    }

    /**
     * Automatically confirm registration when payment is completed.
     */
    public function confirmRegistrationAfterPayment(int $orderId): void
    {
        $order = wc_get_order($orderId);
        if (!$order) return;

        foreach ($order->get_items() as $item) {
            $eventId = $item->get_meta('havato_event_id');
            $userId  = $item->get_meta('havato_user_id') ?: $order->get_user_id();

            if ($eventId && $userId) {
                global $wpdb;
                $table = $wpdb->prefix . 'havato_event_registrations';

                $wpdb->update(
                    $table,
                    ['status' => 'confirmed', 'payment_id' => $orderId],
                    ['event_id' => $eventId, 'user_id' => $userId],
                    ['%s', '%s'],
                    ['%d', '%d']
                );
            }
        }
    }
}