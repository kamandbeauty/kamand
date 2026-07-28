<?php
/**
 * Real Google Sign-In (Google Identity Services).
 *
 * The front-end renders the official GIS button and posts the returned ID token
 * to /havato/v1/auth/google. The token is verified server-side against
 * https://oauth2.googleapis.com/tokeninfo (no external SDK required), then the
 * matching WordPress user is created/logged in with the `gatherer` role.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Google authentication handler.
 */
class Havato_Google_Auth {

	/**
	 * Boot.
	 */
	public static function init() {
		add_action( 'wp_login', array( __CLASS__, 'noop' ), 10, 0 );
	}

	/**
	 * Placeholder to keep the hook list explicit.
	 */
	public static function noop() {}

	/**
	 * Is Google sign-in configured?
	 *
	 * @return bool
	 */
	public static function is_configured() {
		return '' !== trim( (string) Havato_Settings::get( 'google_client_id', '' ) );
	}

	/**
	 * Verify an ID token and sign the user in.
	 *
	 * @param string $credential Google ID token (JWT).
	 * @return array|WP_Error
	 */
	public static function login_with_credential( $credential ) {
		$credential = trim( (string) $credential );
		if ( '' === $credential ) {
			return new WP_Error( 'havato_no_credential', Havato_I18N::t( 'error_generic' ), array( 'status' => 400 ) );
		}

		if ( ! self::is_configured() ) {
			return new WP_Error( 'havato_google_off', Havato_I18N::t( 'google_not_configured' ), array( 'status' => 400 ) );
		}

		$response = wp_remote_get(
			add_query_arg( 'id_token', rawurlencode( $credential ), 'https://oauth2.googleapis.com/tokeninfo' ),
			array( 'timeout' => 15 )
		);

		if ( is_wp_error( $response ) ) {
			return new WP_Error( 'havato_google_http', $response->get_error_message(), array( 'status' => 502 ) );
		}

		$code = (int) wp_remote_retrieve_response_code( $response );
		$body = json_decode( wp_remote_retrieve_body( $response ), true );

		if ( 200 !== $code || ! is_array( $body ) || empty( $body['email'] ) ) {
			return new WP_Error( 'havato_google_invalid', Havato_I18N::t( 'error_generic' ), array( 'status' => 401 ) );
		}

		$client_id = trim( (string) Havato_Settings::get( 'google_client_id', '' ) );
		if ( empty( $body['aud'] ) || $body['aud'] !== $client_id ) {
			return new WP_Error( 'havato_google_aud', 'Token audience mismatch.', array( 'status' => 401 ) );
		}

		if ( isset( $body['exp'] ) && (int) $body['exp'] < time() - 60 ) {
			return new WP_Error( 'havato_google_expired', 'Token expired.', array( 'status' => 401 ) );
		}

		$email = sanitize_email( $body['email'] );
		$name  = isset( $body['name'] ) ? sanitize_text_field( $body['name'] ) : '';
		$pic   = isset( $body['picture'] ) ? esc_url_raw( $body['picture'] ) : '';
		$sub   = isset( $body['sub'] ) ? sanitize_text_field( $body['sub'] ) : '';

		$user = get_user_by( 'email', $email );

		if ( ! $user ) {
			$login = self::unique_login( $email );
			$uid   = wp_insert_user(
				array(
					'user_login'   => $login,
					'user_email'   => $email,
					'user_pass'    => wp_generate_password( 24, true, true ),
					'display_name' => $name ? $name : $login,
					'role'         => 'gatherer',
				)
			);

			if ( is_wp_error( $uid ) ) {
				return $uid;
			}

			$user = get_user_by( 'id', $uid );
			Havato_Logger::log( sprintf( 'New gatherer registered through Google: %s.', $email ), 'success' );
		}

		if ( ! $user ) {
			return new WP_Error( 'havato_user_fail', Havato_I18N::t( 'error_generic' ), array( 'status' => 500 ) );
		}

		if ( $sub ) {
			update_user_meta( $user->ID, 'havato_google_sub', $sub );
		}
		if ( $pic ) {
			update_user_meta( $user->ID, 'havato_avatar', $pic );
		}

		// Google sign-in sets the cookie directly, so it never passes through
		// the `authenticate` filter that refuses banned accounts elsewhere.
		if ( havato_is_banned( $user->ID ) ) {
			return new WP_Error( 'havato_banned', Havato_I18N::t( 'account_banned' ), array( 'status' => 403 ) );
		}

		self::force_login( $user->ID );

		return array(
			'ok'      => true,
			'user_id' => $user->ID,
		);
	}

	/**
	 * Log a user in immediately (instant session, survives refresh).
	 *
	 * @param int $user_id User id.
	 */
	public static function force_login( $user_id ) {
		$user_id = (int) $user_id;
		wp_clear_auth_cookie();
		wp_set_current_user( $user_id );
		wp_set_auth_cookie( $user_id, true );
		do_action( 'wp_login', get_userdata( $user_id )->user_login, get_userdata( $user_id ) );
	}

	/**
	 * Build a unique login name from an e-mail.
	 *
	 * @param string $email E-mail.
	 * @return string
	 */
	private static function unique_login( $email ) {
		$base  = sanitize_user( preg_replace( '/@.*/', '', $email ), true );
		$base  = $base ? $base : 'havato';
		$login = $base;
		$i     = 1;
		while ( username_exists( $login ) ) {
			$login = $base . $i;
			$i++;
		}
		return $login;
	}
}
