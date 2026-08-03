<?php
/**
 * Plugin uninstall handler.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

if (! defined('WP_UNINSTALL_PLUGIN')) {
    exit;
}

$settings = get_option('aiseocs_settings', array());
if (! is_array($settings) || empty($settings['delete_data_on_uninstall'])) {
    return;
}

global $wpdb;

$tables = array(
    $wpdb->prefix . 'aiseocs_providers',
    $wpdb->prefix . 'aiseocs_prompts',
    $wpdb->prefix . 'aiseocs_history',
    $wpdb->prefix . 'aiseocs_logs',
    $wpdb->prefix . 'aiseocs_cache',
    $wpdb->prefix . 'aiseocs_queue',
);

foreach ($tables as $table) {
    $wpdb->query('DROP TABLE IF EXISTS `' . esc_sql($table) . '`');
}

delete_option('aiseocs_settings');
delete_option('aiseocs_db_version');
wp_clear_scheduled_hook('aiseocs_process_queue');
wp_clear_scheduled_hook('aiseocs_daily_maintenance');
