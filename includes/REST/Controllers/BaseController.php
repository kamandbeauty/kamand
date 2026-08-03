<?php
/**
 * Base REST controller.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\REST\Controllers;

use AISEOContentStudio\REST\RestServiceProvider;
use WP_Error;
use WP_REST_Request;
use WP_REST_Response;

if (! defined('ABSPATH')) {
    exit;
}

abstract class BaseController {
    protected string $namespace = RestServiceProvider::NAMESPACE;

    abstract public function register(): void;

    /**
     * Manage options permission.
     */
    public function can_manage(): bool {
        return current_user_can('manage_options');
    }

    /**
     * Edit posts permission.
     */
    public function can_edit_posts(): bool {
        return current_user_can('edit_posts');
    }

    /**
     * Product edit permission callback.
     *
     * @param WP_REST_Request $request Request.
     */
    public function can_edit_product(WP_REST_Request $request): bool {
        return current_user_can('edit_post', absint($request['id']));
    }

    /**
     * Wraps data in a REST response.
     *
     * @param mixed $data Data.
     */
    protected function ok($data = array(), int $status = 200): WP_REST_Response {
        return new WP_REST_Response($data, $status);
    }

    /**
     * Returns an error.
     */
    protected function error(string $message, string $code = 'aiseocs_error', int $status = 400): WP_Error {
        return new WP_Error($code, $message, array('status' => $status));
    }

    /**
     * Returns JSON body params.
     *
     * @param WP_REST_Request $request Request.
     * @return array<string,mixed>
     */
    protected function body(WP_REST_Request $request): array {
        $params = $request->get_json_params();
        if (! is_array($params)) {
            $params = $request->get_body_params();
        }
        return is_array($params) ? $params : array();
    }
}
