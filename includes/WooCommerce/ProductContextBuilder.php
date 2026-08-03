<?php
/**
 * WooCommerce product context builder.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\WooCommerce;

use AISEOContentStudio\Helpers\Text;

if (! defined('ABSPATH')) {
    exit;
}

final class ProductContextBuilder {
    /**
     * Builds product context for AI prompts.
     *
     * @param int $product_id Product ID.
     * @return array<string,mixed>
     */
    public function build(int $product_id): array {
        if (! function_exists('wc_get_product')) {
            throw new \RuntimeException(__('WooCommerce is required for product AI features.', 'aiseo-content-studio'));
        }

        $product = wc_get_product($product_id);
        if (! $product) {
            throw new \RuntimeException(__('Product not found.', 'aiseo-content-studio'));
        }

        $post = get_post($product_id);

        return array(
            'id'                 => $product_id,
            'title'              => get_the_title($product_id),
            'type'               => $product->get_type(),
            'category'           => $this->taxonomy_names($product_id, 'product_cat'),
            'tags'               => $this->taxonomy_names($product_id, 'product_tag'),
            'brand'              => $this->brand($product_id),
            'attributes'         => $this->attributes($product),
            'price'              => array(
                'regular'  => $product->get_regular_price(),
                'sale'     => $product->get_sale_price(),
                'current'  => $product->get_price(),
                'currency' => get_woocommerce_currency(),
            ),
            'sku'                => $product->get_sku(),
            'stock_status'       => $product->get_stock_status(),
            'short_description'  => $post ? wp_strip_all_tags((string) $post->post_excerpt) : '',
            'existing_description' => $post ? wp_strip_all_tags((string) $post->post_content) : '',
            'custom_fields'      => $this->custom_fields($product_id),
            'images'             => $this->images($product),
            'permalink'          => get_permalink($product_id),
            'average_rating'     => $product->get_average_rating(),
            'review_count'       => $product->get_review_count(),
        );
    }

    /**
     * Returns taxonomy names safely.
     *
     * @param int    $product_id Product ID.
     * @param string $taxonomy Taxonomy.
     * @return array<int,string>
     */
    private function taxonomy_names(int $product_id, string $taxonomy): array {
        if (! taxonomy_exists($taxonomy)) {
            return array();
        }

        $terms = wp_get_post_terms($product_id, $taxonomy, array('fields' => 'names'));
        if (is_wp_error($terms) || ! is_array($terms)) {
            return array();
        }

        return array_values(array_map('sanitize_text_field', $terms));
    }

    /**
     * Returns product brand.
     *
     * @param int $product_id Product ID.
     */
    private function brand(int $product_id): string {
        $taxonomies = array('product_brand', 'pa_brand', 'yith_product_brand', 'pwb-brand');
        foreach ($taxonomies as $taxonomy) {
            if (taxonomy_exists($taxonomy)) {
                $terms = wp_get_post_terms($product_id, $taxonomy, array('fields' => 'names'));
                if (! is_wp_error($terms) && ! empty($terms)) {
                    return implode(', ', array_map('sanitize_text_field', $terms));
                }
            }
        }

        foreach (array('_brand', 'brand', '_product_brand') as $key) {
            $value = get_post_meta($product_id, $key, true);
            if (is_scalar($value) && '' !== (string) $value) {
                return sanitize_text_field((string) $value);
            }
        }

        return '';
    }

    /**
     * Returns product attributes.
     *
     * @param \WC_Product $product Product.
     * @return array<string,mixed>
     */
    private function attributes($product): array {
        $items = array();

        foreach ($product->get_attributes() as $attribute) {
            $name = wc_attribute_label($attribute->get_name());
            if ($attribute->is_taxonomy()) {
                $values = wc_get_product_terms($product->get_id(), $attribute->get_name(), array('fields' => 'names'));
            } else {
                $values = $attribute->get_options();
            }

            $items[$name] = array_values(array_filter(array_map('sanitize_text_field', (array) $values)));
        }

        return $items;
    }

    /**
     * Returns safe custom fields.
     *
     * @param int $product_id Product ID.
     * @return array<string,string>
     */
    private function custom_fields(int $product_id): array {
        $meta  = get_post_meta($product_id);
        $items = array();

        foreach ($meta as $key => $values) {
            if (str_starts_with((string) $key, '_') || in_array($key, array('total_sales'), true)) {
                continue;
            }

            $value = is_array($values) ? reset($values) : $values;
            if (is_scalar($value) && '' !== (string) $value) {
                $items[sanitize_key((string) $key)] = Text::excerpt((string) $value, 300);
            }

            if (count($items) >= 25) {
                break;
            }
        }

        return $items;
    }

    /**
     * Returns product images.
     *
     * @param \WC_Product $product Product.
     * @return array<int,array<string,mixed>>
     */
    private function images($product): array {
        $ids = array();
        if ($product->get_image_id()) {
            $ids[] = (int) $product->get_image_id();
        }
        foreach ($product->get_gallery_image_ids() as $id) {
            $ids[] = (int) $id;
        }
        $ids = array_values(array_unique(array_filter($ids)));

        $images = array();
        foreach ($ids as $id) {
            $images[] = array(
                'attachment_id' => $id,
                'url'           => wp_get_attachment_image_url($id, 'large'),
                'alt'           => get_post_meta($id, '_wp_attachment_image_alt', true),
                'title'         => get_the_title($id),
                'caption'       => wp_get_attachment_caption($id),
                'description'   => get_post_field('post_content', $id),
            );
        }

        return $images;
    }
}
