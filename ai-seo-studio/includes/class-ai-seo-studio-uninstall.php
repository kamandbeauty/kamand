<?php namespace AISEO\Uninstall; class Uninstall { public static function run() { global $wpdb; $wpdb->query("DROP TABLE IF EXISTS ".$wpdb->prefix."ai_seo_logs"); delete_option('ai_seo_version'); } }
