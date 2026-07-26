<?php

declare(strict_types=1);

namespace Havato\API;

use Havato\Database\DatabaseManager;
use WP_REST_Request;
use WP_REST_Response;
use WP_Error;

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Havato REST API Controller (havato/v1)
 * All endpoints are versioned and secured.
 */
final class RestController
{
    private const NAMESPACE = 'havato/v1';
    private DatabaseManager $db;

    public function __construct()
    {
        $this->db = new DatabaseManager();
    }

    /**
     * Register all REST routes.
     */
    public function registerRoutes(): void
    {
        // Public / Authenticated routes
        register_rest_route(self::NAMESPACE, '/events', [
            'methods'             => 'GET',
            'callback'            => [$this, 'getEvents'],
            'permission_callback' => [$this, 'permissionRead'],
        ]);

        register_rest_route(self::NAMESPACE, '/events/(?P<id>\d+)', [
            'methods'             => 'GET',
            'callback'            => [$this, 'getEvent'],
            'permission_callback' => [$this, 'permissionRead'],
            'args'                => ['id' => ['required' => true, 'validate_callback' => 'is_numeric']],
        ]);

        // Authenticated endpoints
        register_rest_route(self::NAMESPACE, '/profile', [
            'methods'             => 'GET',
            'callback'            => [$this, 'getProfile'],
            'permission_callback' => [$this, 'permissionLoggedIn'],
        ]);

        register_rest_route(self::NAMESPACE, '/profile', [
            'methods'             => 'POST',
            'callback'            => [$this, 'saveProfile'],
            'permission_callback' => [$this, 'permissionLoggedIn'],
        ]);

        register_rest_route(self::NAMESPACE, '/register-event', [
            'methods'             => 'POST',
            'callback'            => [$this, 'registerForEvent'],
            'permission_callback' => [$this, 'permissionLoggedIn'],
        ]);

        register_rest_route(self::NAMESPACE, '/chats/(?P<event_id>\d+)', [
            'methods'             => 'GET',
            'callback'            => [$this, 'getChats'],
            'permission_callback' => [$this, 'permissionLoggedIn'],
            'args'                => ['event_id' => ['required' => true, 'validate_callback' => 'is_numeric']],
        ]);

        register_rest_route(self::NAMESPACE, '/chats', [
            'methods'             => 'POST',
            'callback'            => [$this, 'sendChat'],
            'permission_callback' => [$this, 'permissionLoggedIn'],
        ]);

        register_rest_route(self::NAMESPACE, '/personality-test', [
            'methods'             => 'POST',
            'callback'            => [$this, 'submitPersonalityTest'],
            'permission_callback' => [$this, 'permissionLoggedIn'],
        ]);

        // Cafe owner protected endpoints
        register_rest_route(self::NAMESPACE, '/my-venue', [
            'methods'             => ['GET', 'POST'],
            'callback'            => [$this, 'manageVenue'],
            'permission_callback' => [$this, 'permissionCafeOwner'],
        ]);

        // Google OAuth callback (public)
        register_rest_route(self::NAMESPACE, '/auth/google/callback', [
            'methods'             => 'GET',
            'callback'            => [new \Havato\Auth\GoogleOAuth(), 'handleCallback'],
            'permission_callback' => '__return_true',
        ]);
    }

    // ==================== Permission Callbacks ====================

    public function permissionRead(): bool
    {
        return true; // Public read access
    }

    public function permissionLoggedIn(): bool
    {
        return is_user_logged_in();
    }

    public function permissionCafeOwner(): bool
    {
        return current_user_can('havato_manage_venue');
    }

    // ==================== Endpoints ====================

    /**
     * GET /events - List open events
     */
    public function getEvents(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;
        $table = $wpdb->prefix . 'havato_events';

        $events = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT * FROM {$table} WHERE status = %s ORDER BY start_time ASC LIMIT 50",
                'open'
            ),
            ARRAY_A
        );

        return new WP_REST_Response([
            'success' => true,
            'data'    => $events ?: [],
        ], 200);
    }

    public function getEvent(WP_REST_Request $request): WP_REST_Response|WP_Error
    {
        global $wpdb;
        $table = $wpdb->prefix . 'havato_events';
        $id = (int) $request->get_param('id');

        $event = $wpdb->get_row(
            $wpdb->prepare("SELECT * FROM {$table} WHERE id = %d", $id),
            ARRAY_A
        );

        if (!$event) {
            return new WP_Error('not_found', __('Event not found', 'havato'), ['status' => 404]);
        }

        return new WP_REST_Response(['success' => true, 'data' => $event], 200);
    }

    public function getProfile(WP_REST_Request $request): WP_REST_Response
    {
        $userId = get_current_user_id();
        global $wpdb;
        $table = $wpdb->prefix . 'havato_user_profiles';

        $profile = $wpdb->get_row(
            $wpdb->prepare("SELECT * FROM {$table} WHERE user_id = %d", $userId),
            ARRAY_A
        );

        return new WP_REST_Response([
            'success' => true,
            'data'    => $profile ?: ['test_completed' => 0],
        ], 200);
    }

    public function saveProfile(WP_REST_Request $request): WP_REST_Response|WP_Error
    {
        $userId = get_current_user_id();
        $data = $request->get_json_params();

        // Sanitize
        $age = isset($data['age']) ? absint($data['age']) : null;
        $gender = isset($data['gender']) ? sanitize_text_field($data['gender']) : null;

        global $wpdb;
        $table = $wpdb->prefix . 'havato_user_profiles';

        $wpdb->replace($table, [
            'user_id'           => $userId,
            'age'               => $age,
            'gender'            => $gender,
            'updated_at'        => current_time('mysql'),
        ]);

        return new WP_REST_Response(['success' => true, 'message' => __('Profile saved', 'havato')], 200);
    }

    public function registerForEvent(WP_REST_Request $request): WP_REST_Response|WP_Error
    {
        $userId = get_current_user_id();
        $eventId = absint($request->get_param('event_id'));

        if (!$eventId) {
            return new WP_Error('invalid_event', __('Invalid event ID', 'havato'), ['status' => 400]);
        }

        global $wpdb;
        $regTable = $wpdb->prefix . 'havato_event_registrations';

        // Prevent duplicate registration
        $exists = $wpdb->get_var($wpdb->prepare(
            "SELECT id FROM {$regTable} WHERE event_id = %d AND user_id = %d",
            $eventId, $userId
        ));

        if ($exists) {
            return new WP_REST_Response(['success' => false, 'message' => __('Already registered', 'havato')], 200);
        }

        $wpdb->insert($regTable, [
            'event_id' => $eventId,
            'user_id'  => $userId,
            'status'   => 'pending',
            'created_at' => current_time('mysql'),
        ]);

        return new WP_REST_Response([
            'success' => true,
            'message' => __('Registration successful. Proceeding to payment...', 'havato'),
            'redirect' => wc_get_checkout_url(), // Will be handled by Woo module
        ], 200);
    }

    public function getChats(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;
        $table = $wpdb->prefix . 'havato_chats';
        $eventId = (int) $request->get_param('event_id');

        $chats = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT c.*, u.display_name FROM {$table} c 
                 LEFT JOIN {$wpdb->users} u ON c.user_id = u.ID 
                 WHERE c.event_id = %d ORDER BY c.created_at ASC LIMIT 100",
                $eventId
            ),
            ARRAY_A
        );

        return new WP_REST_Response(['success' => true, 'data' => $chats ?: []], 200);
    }

    public function sendChat(WP_REST_Request $request): WP_REST_Response|WP_Error
    {
        $userId = get_current_user_id();
        $data = $request->get_json_params();

        $eventId = absint($data['event_id'] ?? 0);
        $message = isset($data['message']) ? sanitize_textarea_field($data['message']) : '';

        if (!$eventId || empty($message)) {
            return new WP_Error('invalid_data', __('Invalid chat data', 'havato'), ['status' => 400]);
        }

        global $wpdb;
        $table = $wpdb->prefix . 'havato_chats';

        $wpdb->insert($table, [
            'event_id'   => $eventId,
            'user_id'    => $userId,
            'message'    => $message,
            'created_at' => current_time('mysql'),
        ]);

        return new WP_REST_Response(['success' => true, 'message' => __('Message sent', 'havato')], 201);
    }

    public function submitPersonalityTest(WP_REST_Request $request): WP_REST_Response|WP_Error
    {
        $userId = get_current_user_id();
        $data = $request->get_json_params();

        global $wpdb;
        $table = $wpdb->prefix . 'havato_user_profiles';

        $wpdb->replace($table, [
            'user_id'            => $userId,
            'age'                => absint($data['age'] ?? 0),
            'gender'             => sanitize_text_field($data['gender'] ?? ''),
            'extroversion'       => sanitize_text_field($data['extroversion'] ?? ''),
            'talkative'          => sanitize_text_field($data['talkative'] ?? ''),
            'conversation_style' => sanitize_text_field($data['conversation_style'] ?? ''),
            'interests'          => sanitize_textarea_field($data['interests'] ?? ''),
            'test_completed'     => 1,
            'updated_at'         => current_time('mysql'),
        ]);

        return new WP_REST_Response(['success' => true, 'message' => __('Personality test completed', 'havato')], 200);
    }

    public function manageVenue(WP_REST_Request $request): WP_REST_Response|WP_Error
    {
        $userId = get_current_user_id();

        if ($request->get_method() === 'GET') {
            global $wpdb;
            $table = $wpdb->prefix . 'havato_venues';
            $venue = $wpdb->get_row(
                $wpdb->prepare("SELECT * FROM {$table} WHERE user_id = %d", $userId),
                ARRAY_A
            );
            return new WP_REST_Response(['success' => true, 'data' => $venue], 200);
        }

        // POST - Update venue
        $data = $request->get_json_params();
        global $wpdb;
        $table = $wpdb->prefix . 'havato_venues';

        $wpdb->replace($table, [
            'user_id'    => $userId,
            'name'       => sanitize_text_field($data['name'] ?? ''),
            'address'    => sanitize_text_field($data['address'] ?? ''),
            'latitude'   => (float) ($data['latitude'] ?? 0),
            'longitude'  => (float) ($data['longitude'] ?? 0),
            'status'     => 'pending',
            'updated_at' => current_time('mysql'),
        ]);

        return new WP_REST_Response(['success' => true, 'message' => __('Venue settings saved', 'havato')], 200);
    }
}