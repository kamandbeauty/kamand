<?php
/**
 * Prompt library REST controller.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\REST\Controllers;

use AISEOContentStudio\Repositories\PromptRepository;
use WP_REST_Request;

if (! defined('ABSPATH')) {
    exit;
}

final class PromptController extends BaseController {
    private PromptRepository $prompts;

    public function __construct() {
        $this->prompts = new PromptRepository();
    }

    public function register(): void {
        register_rest_route(
            $this->namespace,
            '/prompts',
            array(
                array(
                    'methods'             => 'GET',
                    'callback'            => array($this, 'all'),
                    'permission_callback' => array($this, 'can_manage'),
                ),
                array(
                    'methods'             => 'POST',
                    'callback'            => array($this, 'create'),
                    'permission_callback' => array($this, 'can_manage'),
                ),
            )
        );

        register_rest_route(
            $this->namespace,
            '/prompts/(?P<id>\d+)',
            array(
                array(
                    'methods'             => 'GET',
                    'callback'            => array($this, 'find'),
                    'permission_callback' => array($this, 'can_manage'),
                    'args'                => array('id' => array('sanitize_callback' => 'absint')),
                ),
                array(
                    'methods'             => 'PUT,PATCH',
                    'callback'            => array($this, 'update'),
                    'permission_callback' => array($this, 'can_manage'),
                    'args'                => array('id' => array('sanitize_callback' => 'absint')),
                ),
                array(
                    'methods'             => 'DELETE',
                    'callback'            => array($this, 'delete'),
                    'permission_callback' => array($this, 'can_manage'),
                    'args'                => array('id' => array('sanitize_callback' => 'absint')),
                ),
            )
        );

        register_rest_route(
            $this->namespace,
            '/prompts/import',
            array(
                'methods'             => 'POST',
                'callback'            => array($this, 'import'),
                'permission_callback' => array($this, 'can_manage'),
            )
        );
    }

    /**
     * Lists prompts.
     *
     * @param WP_REST_Request $request Request.
     */
    public function all(WP_REST_Request $request): \WP_REST_Response {
        return $this->ok(
            array(
                'prompts' => $this->prompts->all(
                    array(
                        'category' => sanitize_key((string) $request->get_param('category')),
                        'favorite' => null !== $request->get_param('favorite') ? (bool) $request->get_param('favorite') : null,
                        'limit'    => absint($request->get_param('limit') ?: 100),
                    )
                ),
            )
        );
    }

    /**
     * Finds prompt.
     *
     * @param WP_REST_Request $request Request.
     */
    public function find(WP_REST_Request $request) {
        $prompt = $this->prompts->find(absint($request['id']));
        if (! $prompt) {
            return $this->error(__('Prompt not found.', 'aiseo-content-studio'), 'aiseocs_prompt_not_found', 404);
        }
        return $this->ok(array('prompt' => $prompt));
    }

    /**
     * Creates prompt.
     *
     * @param WP_REST_Request $request Request.
     */
    public function create(WP_REST_Request $request) {
        $id = $this->prompts->create($this->body($request));
        if (! $id) {
            return $this->error(__('Unable to create prompt.', 'aiseo-content-studio'));
        }
        return $this->ok(array('prompt' => $this->prompts->find($id)), 201);
    }

    /**
     * Updates prompt.
     *
     * @param WP_REST_Request $request Request.
     */
    public function update(WP_REST_Request $request) {
        $updated = $this->prompts->update(absint($request['id']), $this->body($request));
        if (! $updated) {
            return $this->error(__('Unable to update prompt.', 'aiseo-content-studio'));
        }
        return $this->ok(array('prompt' => $this->prompts->find(absint($request['id']))));
    }

    /**
     * Deletes prompt.
     *
     * @param WP_REST_Request $request Request.
     */
    public function delete(WP_REST_Request $request) {
        return $this->ok(array('deleted' => $this->prompts->delete(absint($request['id']))));
    }

    /**
     * Imports prompts from JSON payload.
     *
     * @param WP_REST_Request $request Request.
     */
    public function import(WP_REST_Request $request) {
        $body    = $this->body($request);
        $prompts = isset($body['prompts']) && is_array($body['prompts']) ? $body['prompts'] : array();
        $count   = $this->prompts->import($prompts);
        return $this->ok(array('imported' => $count));
    }
}
