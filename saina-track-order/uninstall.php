<?php
if ( ! defined( 'WP_UNINSTALL_PLUGIN' ) ) {
	exit;
}

delete_option( 'saina_to_settings' );
wp_clear_scheduled_hook( 'saina_to_auto_deliver' );
