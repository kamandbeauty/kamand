<?php
/**
 * Product AI panel mount point.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

if (! defined('ABSPATH')) {
    exit;
}
?>
<div
    id="aiseocs-product-panel-<?php echo esc_attr((string) $product_id); ?>"
    class="aiseocs-product-panel"
    data-product-id="<?php echo esc_attr((string) $product_id); ?>"
    data-rest-url="<?php echo esc_url(rest_url('aiseocs/v1/')); ?>"
    data-nonce="<?php echo esc_attr(wp_create_nonce('wp_rest')); ?>"
    data-locale="<?php echo esc_attr(get_locale()); ?>"
    data-is-rtl="<?php echo esc_attr(is_rtl() ? '1' : '0'); ?>"
>
    <div class="aiseocs-panel-loading">
        <?php echo esc_html__('Loading AI product assistant…', 'aiseo-content-studio'); ?>
    </div>
</div>
