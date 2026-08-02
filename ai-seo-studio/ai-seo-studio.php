<?php
/**
 * Plugin Name: AI SEO Content Studio
 * Description: Premium AI writing assistant for WordPress & WooCommerce
 * Version: 1.0.0
 * Author: AI Studio
 * Text Domain: ai-seo-studio
 * Requires PHP: 8.1
 */
if (!defined('ABSPATH')) exit;

define('AISEO_VERSION', '1.0.0');
define('AISEO_FILE', __FILE__);
define('AISEO_DIR', plugin_dir_path(__FILE__));
define('AISEO_URL', plugin_dir_url(__FILE__));

require_once AISEO_DIR . 'includes/class-ai-seo-studio.php';

register_activation_hook(__FILE__, [\AISEO\Core\AI_Seo_Studio::class, 'activate']);
register_deactivation_hook(__FILE__, [\AISEO\Core\AI_Seo_Studio::class, 'deactivate']);
register_uninstall_hook(__FILE__, [\AISEO\Core\AI_Seo_Studio::class, 'uninstall']);

add_action('plugins_loaded', function() {
    \AISEO\Core\AI_Seo_Studio::instance();
});
