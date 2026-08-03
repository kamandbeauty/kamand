<?php
/**
 * Applies generated content to WooCommerce products.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\WooCommerce;

use AISEOContentStudio\SEO\SEOManager;

if (! defined('ABSPATH')) {
    exit;
}

final class ProductContentApplier {
    private SEOManager $seo;

    public function __construct() {
        $this->seo = new SEOManager();
    }

    /**
     * Applies generated payload to a product.
     *
     * @param int                 $product_id Product ID.
     * @param array<string,mixed> $payload Payload.
     * @param array<string,mixed> $fields Fields to apply.
     * @return array<string,mixed>
     */
    public function apply(int $product_id, array $payload, array $fields = array()): array {
        if (! current_user_can('edit_post', $product_id)) {
            throw new \RuntimeException(__('You do not have permission to edit this product.', 'aiseo-content-studio'));
        }

        $post = get_post($product_id);
        if (! $post || 'product' !== $post->post_type) {
            throw new \RuntimeException(__('Product not found.', 'aiseo-content-studio'));
        }

        $fields = empty($fields) ? array_keys($payload) : array_map('sanitize_key', $fields);
        $updated = array();
        $post_update = array('ID' => $product_id);

        if (in_array('seo_description_html', $fields, true) && ! empty($payload['seo_description_html'])) {
            $post_update['post_content'] = wp_kses_post((string) $payload['seo_description_html']);
            $updated[] = 'description';
        }

        if (in_array('short_description_html', $fields, true) && ! empty($payload['short_description_html'])) {
            $post_update['post_excerpt'] = wp_kses_post((string) $payload['short_description_html']);
            $updated[] = 'short_description';
        }

        if (in_array('excerpt', $fields, true) && empty($post_update['post_excerpt']) && ! empty($payload['excerpt'])) {
            $post_update['post_excerpt'] = sanitize_textarea_field((string) $payload['excerpt']);
            $updated[] = 'excerpt';
        }

        if (in_array('slug', $fields, true) && ! empty($payload['slug'])) {
            $post_update['post_name'] = sanitize_title((string) $payload['slug']);
            $updated[] = 'slug';
        }

        if (in_array('title', $fields, true) && ! empty($payload['title'])) {
            $post_update['post_title'] = sanitize_text_field((string) $payload['title']);
            $updated[] = 'title';
        }

        if (count($post_update) > 1) {
            $result = wp_update_post(wp_slash($post_update), true);
            if (is_wp_error($result)) {
                throw new \RuntimeException($result->get_error_message());
            }
        }

        if (in_array('seo', $fields, true) || in_array('seo_title', $fields, true) || in_array('meta_description', $fields, true) || in_array('focus_keywords', $fields, true)) {
            $seo_title = array_key_exists('seo_title', $payload) ? sanitize_text_field((string) $payload['seo_title']) : sanitize_text_field((string) get_post_meta($product_id, '_aiseocs_seo_title', true));
            $meta_description = array_key_exists('meta_description', $payload) ? sanitize_text_field((string) $payload['meta_description']) : sanitize_text_field((string) get_post_meta($product_id, '_aiseocs_meta_description', true));
            $focus_keywords = array_key_exists('focus_keywords', $payload) ? $payload['focus_keywords'] : get_post_meta($product_id, '_aiseocs_focus_keywords', true);
            $this->seo->apply($product_id, $seo_title, $meta_description, $focus_keywords);
            $updated[] = 'seo';
        }

        if (in_array('product_tags', $fields, true) && ! empty($payload['product_tags']) && is_array($payload['product_tags'])) {
            $tags = array_values(array_filter(array_map('sanitize_text_field', $payload['product_tags'])));
            if (! empty($tags)) {
                wp_set_object_terms($product_id, $tags, 'product_tag', false);
                $updated[] = 'product_tags';
            }
        }

        if (in_array('image_seo', $fields, true) && ! empty($payload['image_seo']) && is_array($payload['image_seo'])) {
            $this->apply_images($payload['image_seo']);
            $updated[] = 'image_seo';
        }

        foreach (array('benefits', 'features', 'specifications', 'faq', 'pros', 'cons', 'product_schema', 'social_captions', 'marketing_text', 'improved_titles', 'internal_links', 'related_products', 'seo_score') as $meta_key) {
            if (in_array($meta_key, $fields, true) && array_key_exists($meta_key, $payload)) {
                update_post_meta($product_id, '_aiseocs_' . $meta_key, wp_json_encode($this->sanitize_meta_payload($payload[$meta_key]), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
                $updated[] = $meta_key;
            }
        }

        clean_post_cache($product_id);

        return array(
            'product_id' => $product_id,
            'updated'    => array_values(array_unique($updated)),
        );
    }

    /**
     * Sanitizes saved AI metadata while preserving JSON-LD keys such as @context and @type.
     *
     * @param mixed $value Value.
     * @return mixed
     */
    private function sanitize_meta_payload($value) {
        if (is_array($value)) {
            $clean = array();
            foreach ($value as $key => $item) {
                $clean_key = is_string($key) ? preg_replace('/[^a-zA-Z0-9_@\-]/', '', $key) : (int) $key;
                $clean[$clean_key] = $this->sanitize_meta_payload($item);
            }
            return $clean;
        }

        if (is_string($value)) {
            return wp_kses_post($value);
        }

        if (is_bool($value) || is_int($value) || is_float($value) || null === $value) {
            return $value;
        }

        return sanitize_text_field((string) $value);
    }

    /**
     * Applies image SEO data.
     *
     * @param array<int,array<string,mixed>> $images Image rows.
     */
    private function apply_images(array $images): void {
        foreach ($images as $image) {
            if (! is_array($image)) {
                continue;
            }

            $attachment_id = absint($image['attachment_id'] ?? 0);
            if (! $attachment_id || 'attachment' !== get_post_type($attachment_id) || ! current_user_can('edit_post', $attachment_id)) {
                continue;
            }

            if (! empty($image['alt'])) {
                update_post_meta($attachment_id, '_wp_attachment_image_alt', sanitize_text_field((string) $image['alt']));
            }

            $update = array('ID' => $attachment_id);
            if (! empty($image['title'])) {
                $update['post_title'] = sanitize_text_field((string) $image['title']);
            }
            if (! empty($image['caption'])) {
                $update['post_excerpt'] = sanitize_textarea_field((string) $image['caption']);
            }
            if (! empty($image['description'])) {
                $update['post_content'] = sanitize_textarea_field((string) $image['description']);
            }

            if (count($update) > 1) {
                wp_update_post(wp_slash($update));
            }
        }
    }
}
