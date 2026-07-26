<?php

declare(strict_types=1);

namespace Havato\Auth;

use WP_Error;

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Google OAuth 2.0 Authentication Handler
 * Production-ready implementation for Havato
 */
final class GoogleOAuth
{
    private const OPTION_CLIENT_ID     = 'havato_google_client_id';
    private const OPTION_CLIENT_SECRET = 'havato_google_client_secret';
    private const OPTION_REDIRECT_URI  = 'havato_google_redirect_uri';

    /**
     * Register settings for Google OAuth.
     */
    public function registerSettings(): void
    {
        register_setting('havato_google', self::OPTION_CLIENT_ID, [
            'type'              => 'string',
            'sanitize_callback' => 'sanitize_text_field',
        ]);

        register_setting('havato_google', self::OPTION_CLIENT_SECRET, [
            'type'              => 'string',
            'sanitize_callback' => 'sanitize_text_field',
        ]);

        register_setting('havato_google', self::OPTION_REDIRECT_URI, [
            'type'              => 'string',
            'sanitize_callback' => 'esc_url_raw',
        ]);

        add_settings_section(
            'havato_google_section',
            __('Google Login Settings', 'havato'),
            fn() => printf('<p>%s</p>', esc_html__('Configure Google OAuth credentials for user authentication.', 'havato')),
            'havato_google'
        );

        add_settings_field(
            self::OPTION_CLIENT_ID,
            __('Client ID', 'havato'),
            [$this, 'renderTextField'],
            'havato_google',
            'havato_google_section',
            ['option' => self::OPTION_CLIENT_ID]
        );

        add_settings_field(
            self::OPTION_CLIENT_SECRET,
            __('Client Secret', 'havato'),
            [$this, 'renderTextField'],
            'havato_google',
            'havato_google_section',
            ['option' => self::OPTION_CLIENT_SECRET, 'type' => 'password']
        );

        add_settings_field(
            self::OPTION_REDIRECT_URI,
            __('Redirect URI', 'havato'),
            [$this, 'renderTextField'],
            'havato_google',
            'havato_google_section',
            ['option' => self::OPTION_REDIRECT_URI]
        );
    }

    public function renderTextField(array $args): void
    {
        $option = $args['option'];
        $type   = $args['type'] ?? 'text';
        $value  = get_option($option, '');
        printf(
            '<input type="%s" name="%s" value="%s" class="regular-text" />',
            esc_attr($type),
            esc_attr($option),
            esc_attr($value)
        );
    }

    /**
     * Get Google OAuth configuration.
     */
    public static function getConfig(): array
    {
        return [
            'client_id'     => get_option(self::OPTION_CLIENT_ID, ''),
            'client_secret' => get_option(self::OPTION_CLIENT_SECRET, ''),
            'redirect_uri'  => get_option(self::OPTION_REDIRECT_URI, home_url('/wp-json/havato/v1/auth/google/callback')),
        ];
    }

    /**
     * Generate Google authorization URL.
     */
    public static function getAuthorizationUrl(): string
    {
        $config = self::getConfig();

        if (empty($config['client_id']) || empty($config['redirect_uri'])) {
            return '#';
        }

        $params = [
            'client_id'     => $config['client_id'],
            'redirect_uri'  => $config['redirect_uri'],
            'response_type' => 'code',
            'scope'         => 'openid email profile',
            'access_type'   => 'offline',
            'prompt'        => 'consent',
        ];

        return 'https://accounts.google.com/o/oauth2/v2/auth?' . http_build_query($params);
    }

    /**
     * Handle Google OAuth callback and create/login user.
     */
    public function handleCallback(\WP_REST_Request $request): \WP_REST_Response|WP_Error
    {
        $code = sanitize_text_field($request->get_param('code'));

        if (!$code) {
            return new WP_Error('no_code', __('Authorization code missing', 'havato'), ['status' => 400]);
        }

        $config = self::getConfig();
        $tokenResponse = wp_remote_post('https://oauth2.googleapis.com/token', [
            'body' => [
                'code'          => $code,
                'client_id'     => $config['client_id'],
                'client_secret' => $config['client_secret'],
                'redirect_uri'  => $config['redirect_uri'],
                'grant_type'    => 'authorization_code',
            ],
        ]);

        if (is_wp_error($tokenResponse)) {
            return new WP_Error('token_error', $tokenResponse->get_error_message(), ['status' => 500]);
        }

        $tokenBody = json_decode(wp_remote_retrieve_body($tokenResponse), true);

        if (empty($tokenBody['access_token'])) {
            return new WP_Error('invalid_token', __('Failed to obtain access token', 'havato'), ['status' => 401]);
        }

        // Fetch user info
        $userInfoResponse = wp_remote_get('https://www.googleapis.com/oauth2/v3/userinfo', [
            'headers' => ['Authorization' => 'Bearer ' . $tokenBody['access_token']],
        ]);

        $userInfo = json_decode(wp_remote_retrieve_body($userInfoResponse), true);

        if (empty($userInfo['email'])) {
            return new WP_Error('no_email', __('Unable to retrieve email from Google', 'havato'), ['status' => 400]);
        }

        // Create or login user
        $user = get_user_by('email', $userInfo['email']);

        if (!$user) {
            $userId = wp_create_user(
                sanitize_user($userInfo['email']),
                wp_generate_password(32, true),
                sanitize_email($userInfo['email'])
            );

            if (is_wp_error($userId)) {
                return new WP_Error('user_creation_failed', $userId->get_error_message(), ['status' => 500]);
            }

            $user = get_user_by('id', $userId);
            wp_update_user([
                'ID'           => $userId,
                'display_name' => sanitize_text_field($userInfo['name'] ?? $userInfo['email']),
            ]);

            // Assign default role
            $user->set_role('gatherer');
        }

        // Log the user in
        wp_set_current_user($user->ID);
        wp_set_auth_cookie($user->ID, true);

        // Redirect to app
        wp_safe_redirect(home_url('/?havato_app=1'));
        exit;
    }
}