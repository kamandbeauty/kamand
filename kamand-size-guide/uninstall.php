<?php
/**
 * حذف کامل داده‌های افزونه هنگام حذف از پیشخوان.
 *
 * @package KamandSizeGuide
 */

defined( 'WP_UNINSTALL_PLUGIN' ) || exit;

global $wpdb;

// حذف همهٔ راهنماهای سایز.
$guide_ids = get_posts(
	array(
		'post_type'      => 'ksg_size_guide',
		'post_status'    => 'any',
		'posts_per_page' => -1,
		'fields'         => 'ids',
		'no_found_rows'  => true,
	)
);

foreach ( $guide_ids as $guide_id ) {
	wp_delete_post( $guide_id, true );
}

// حذف متای محصولات.
delete_post_meta_by_key( '_ksg_mode' );
delete_post_meta_by_key( '_ksg_guide_ids' );
delete_post_meta_by_key( '_ksg_inline_table' );

// حذف راهنمای پیش‌فرض دسته‌بندی‌ها.
$wpdb->delete( $wpdb->termmeta, array( 'meta_key' => 'ksg_guide_id' ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery

// حذف تنظیمات.
delete_option( 'ksg_settings' );
