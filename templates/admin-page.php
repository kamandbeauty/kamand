<?php
/**
 * Admin React app mount point.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

if (! defined('ABSPATH')) {
    exit;
}

$direction = is_rtl() ? 'rtl' : 'ltr';
?>
<div class="wrap aiseocs-wrap" dir="<?php echo esc_attr($direction); ?>">
    <div
        id="aiseocs-admin-app"
        class="aiseocs-admin-app"
        data-rest-url="<?php echo esc_url(rest_url('aiseocs/v1/')); ?>"
        data-nonce="<?php echo esc_attr(wp_create_nonce('wp_rest')); ?>"
        data-initial-tab="<?php echo esc_attr($tab); ?>"
        data-locale="<?php echo esc_attr(get_locale()); ?>"
        data-is-rtl="<?php echo esc_attr(is_rtl() ? '1' : '0'); ?>"
        data-admin-url="<?php echo esc_url(admin_url()); ?>"
    >
        <h1><?php echo esc_html__('AI SEO Content Studio', 'aiseo-content-studio'); ?></h1>
        <p><?php echo esc_html__('Loading AI workspace…', 'aiseo-content-studio'); ?></p>
    </div>
</div>
