<?php
/**
 * Generation REST controller.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\REST\Controllers;

use AISEOContentStudio\AI\AIService;
use AISEOContentStudio\Services\ImageService;
use WP_REST_Request;

if (! defined('ABSPATH')) {
    exit;
}

final class GenerationController extends BaseController {
    public function register(): void {
        register_rest_route(
            $this->namespace,
            '/generate',
            array(
                'methods'             => 'POST',
                'callback'            => array($this, 'generate'),
                'permission_callback' => array($this, 'can_edit_posts'),
            )
        );

        register_rest_route(
            $this->namespace,
            '/chat',
            array(
                'methods'             => 'POST',
                'callback'            => array($this, 'chat'),
                'permission_callback' => array($this, 'can_edit_posts'),
            )
        );

        register_rest_route(
            $this->namespace,
            '/images/generate',
            array(
                'methods'             => 'POST',
                'callback'            => array($this, 'image'),
                'permission_callback' => array($this, 'can_edit_posts'),
            )
        );
    }

    /**
     * Generates content.
     *
     * @param WP_REST_Request $request Request.
     */
    public function generate(WP_REST_Request $request) {
        try {
            $result = (new AIService())->generate($this->body($request));
            return $this->ok($result);
        } catch (\Throwable $exception) {
            return $this->error($exception->getMessage(), 'aiseocs_generation_failed', 500);
        }
    }

    /**
     * Chat endpoint.
     *
     * @param WP_REST_Request $request Request.
     */
    public function chat(WP_REST_Request $request) {
        try {
            $body     = $this->body($request);
            $messages = isset($body['messages']) && is_array($body['messages']) ? $body['messages'] : array();
            $result   = (new AIService())->chat($messages, $body);
            return $this->ok($result);
        } catch (\Throwable $exception) {
            return $this->error($exception->getMessage(), 'aiseocs_chat_failed', 500);
        }
    }

    /**
     * Image endpoint.
     *
     * @param WP_REST_Request $request Request.
     */
    public function image(WP_REST_Request $request) {
        try {
            $body   = $this->body($request);
            $prompt = sanitize_textarea_field((string) ($body['prompt'] ?? ''));
            if ('' === $prompt) {
                return $this->error(__('Image prompt is required.', 'aiseo-content-studio'));
            }
            $result = (new ImageService())->generate($prompt, $body);
            return $this->ok($result, 201);
        } catch (\Throwable $exception) {
            return $this->error($exception->getMessage(), 'aiseocs_image_failed', 500);
        }
    }
}
