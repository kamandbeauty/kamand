<?php
/**
 * Uninstall routine.
 *
 * Data is only destroyed when the site owner explicitly opts in by defining
 * HAVATO_REMOVE_ALL_DATA (or by ticking the option before deleting), so an
 * accidental delete never wipes a production community.
 *
 * @package Havato
 */

defined( 'WP_UNINSTALL_PLUGIN' ) || exit;

$havato_purge = defined( 'HAVATO_REMOVE_ALL_DATA' ) && HAVATO_REMOVE_ALL_DATA;
$havato_purge = $havato_purge || (bool) get_option( 'havato_remove_all_data' );

// Always clean the scheduled jobs.
wp_clear_scheduled_hook( 'havato_matcher_cron' );
wp_clear_scheduled_hook( 'havato_lifecycle_cron' );

if ( ! $havato_purge ) {
	return;
}

global $wpdb;

$havato_tables = array(
	'venues',
	'events',
	'user_profiles',
	'event_registrations',
	'groups',
	'group_members',
	'chats',
	'feedbacks',
	'friends',
	'user_photos',
	'photo_likes',
	'photo_reports',
	'private_chats',
	'payouts',
);

foreach ( $havato_tables as $havato_table ) {
	$havato_name = $wpdb->prefix . 'havato_' . $havato_table;
	// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	$wpdb->query( "DROP TABLE IF EXISTS `{$havato_name}`" );
}

delete_option( 'havato_settings' );
delete_option( 'havato_db_version' );
delete_option( 'havato_console_log' );
delete_option( 'havato_default_lang' );
delete_option( 'havato_app_page_id' );
delete_option( 'havato_flush_rewrite' );
delete_option( 'havato_remove_all_data' );
delete_option( 'havato_theme' );
delete_option( 'havato_theme_custom' );
delete_option( 'havato_owner_auth_page_id' );

remove_role( 'gatherer' );
remove_role( 'cafe_owner' );
