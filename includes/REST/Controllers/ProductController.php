<?php
/**
 * Product REST controller.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\REST\Controllers;

use AISEOContentStudio\AI\AIService;
use AISEOContentStudio\AI\ContentAnalyzer;
use AISEOContentStudio\Services\ImageService;
use AISEOContentStudio\WooCommerce\ProductContentApplier;
use AISEOContentStudio\WooCommerce\ProductContextBuilder;
use WP_REST_Request;

if (! defined('ABSPATH')) {
    exit;
}

final class ProductController extends BaseController {
    public function register(): void {
        register_rest_route(
            $this->namespace,
            '/products/(?P<id>\d+)/context',
            array(
                'methods'             => 'GET',
                'callback'            => array($this, 'context'),
                'permission_callback' => array($this, 'can_edit_product'),
                'args'                => array('id' => array('sanitize_callback' => 'absint')),
            )
        );

        register_rest_route(
            $this->namespace,
            '/products/(?P<id>\d+)/generate',
            array(
                'methods'             => 'POST',
                'callback'            => array($this, 'generate'),
                'permission_callback' => array($this, 'can_edit_product'),
                'args'                => array('id' => array('sanitize_callback' => 'absint')),
            )
        );

        register_rest_route(
            $this->namespace,
            '/products/(?P<id>\d+)/apply',
            array(
                'methods'             => 'POST',
                'callback'            => array($this, 'apply'),
                'permission_callback' => array($this, 'can_edit_product'),
                'args'                => array('id' => array('sanitize_callback' => 'absint')),
            )
        );

        register_rest_route(
            $this->namespace,
            '/products/(?P<id>\d+)/images/generate',
            array(
                'methods'             => 'POST',
                'callback'            => array($this, 'image'),
                'permission_callback' => array($this, 'can_edit_product'),
                'args'                => array('id' => array('sanitize_callback' => 'absint')),
            )
        );
    }

    /**
     * Returns product context.
     *
     * @param WP_REST_Request $request Request.
     */
    public function context(WP_REST_Request $request) {
        try {
            return $this->ok(array('context' => (new ProductContextBuilder())->build(absint($request['id']))));
        } catch (\Throwable $exception) {
            return $this->error($exception->getMessage(), 'aiseocs_product_context_failed', 404);
        }
    }

    /**
     * Generates product content.
     *
     * @param WP_REST_Request $request Request.
     */
    public function generate(WP_REST_Request $request) {
        try {
            $body    = $this->body($request);
            $feature = sanitize_key((string) ($body['feature'] ?? 'product_bundle'));
            $context = (new ProductContextBuilder())->build(absint($request['id']));
            $result  = (new AIService())->generate_product($feature, $context, $body);

            if ('seo_score' === $feature && empty($result['parsed'])) {
                $content = (string) ($body['content'] ?? ($context['existing_description'] ?? ''));
                $result['parsed'] = (new ContentAnalyzer())->score($content, $context);
            }

            return $this->ok($result);
        } catch (\Throwable $exception) {
            return $this->error($exception->getMessage(), 'aiseocs_product_generation_failed', 500);
        }
    }

    /**
     * Applies product content.
     *
     * @param WP_REST_Request $request Request.
     */
    public function apply(WP_REST_Request $request) {
        try {
            $body    = $this->body($request);
            $payload = isset($body['payload']) && is_array($body['payload']) ? $body['payload'] : $body;
            $fields  = isset($body['fields']) && is_array($body['fields']) ? $body['fields'] : array();
            $result  = (new ProductContentApplier())->apply(absint($request['id']), $payload, $fields);
            return $this->ok($result);
        } catch (\Throwable $exception) {
            return $this->error($exception->getMessage(), 'aiseocs_product_apply_failed', 500);
        }
    }

    /**
     * Generates product image.
     *
     * @param WP_REST_Request $request Request.
     */
    public function image(WP_REST_Request $request) {
        try {
            $body    = $this->body($request);
            $context = (new ProductContextBuilder())->build(absint($request['id']));
            $prompt  = sanitize_textarea_field((string) ($body['prompt'] ?? ''));
            if ('' === $prompt) {
                $prompt = sprintf(
                    /* translators: %s: product title */
                    __('Premium ecommerce product image for %s, clean studio lighting, realistic, conversion-focused, brand-safe.', 'aiseo-content-studio'),
                    (string) ($context['title'] ?? '')
                );
            }
            $result = (new ImageService())->generate($prompt, $body);
            if (! empty($body['set_featured']) && ! empty($result['attachment_id'])) {
                set_post_thumbnail(absint($request['id']), absint($result['attachment_id']));
            }
            return $this->ok($result, 201);
        } catch (\Throwable $exception) {
            return $this->error($exception->getMessage(), 'aiseocs_product_image_failed', 500);
        }
    }
}
