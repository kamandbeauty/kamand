<?php
/**
 * Rolling live log used by the dark "matcher console" in wp-admin.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Ring-buffer logger stored in a single option (max 200 lines).
 */
class Havato_Logger {

	const OPTION = 'havato_console_log';
	const LIMIT  = 200;

	/**
	 * Append a line.
	 *
	 * @param string $message Message text.
	 * @param string $level   info|success|warn|error.
	 */
	public static function log( $message, $level = 'info' ) {
		$lines = get_option( self::OPTION, array() );
		if ( ! is_array( $lines ) ) {
			$lines = array();
		}

		$lines[] = array(
			'time'  => current_time( 'H:i:s' ),
			'date'  => current_time( 'mysql' ),
			'level' => in_array( $level, array( 'info', 'success', 'warn', 'error' ), true ) ? $level : 'info',
			'msg'   => wp_strip_all_tags( (string) $message ),
		);

		if ( count( $lines ) > self::LIMIT ) {
			$lines = array_slice( $lines, -self::LIMIT );
		}

		update_option( self::OPTION, $lines, false );
	}

	/**
	 * Latest lines, newest last.
	 *
	 * @param int $limit How many lines.
	 * @return array
	 */
	public static function tail( $limit = 40 ) {
		$lines = get_option( self::OPTION, array() );
		if ( ! is_array( $lines ) || empty( $lines ) ) {
			return array();
		}
		return array_slice( $lines, -max( 1, (int) $limit ) );
	}

	/**
	 * Wipe the buffer.
	 */
	public static function clear() {
		update_option( self::OPTION, array(), false );
	}
}
