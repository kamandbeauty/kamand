<?php
/**
 * Queue REST controller.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\REST\Controllers;

use AISEOContentStudio\Helpers\Sanitizer;
use AISEOContentStudio\Repositories\LogRepository;
use AISEOContentStudio\Repositories\QueueRepository;
use AISEOContentStudio\Services\QueueService;
use WP_REST_Request;

if (! defined('ABSPATH')) {
    exit;
}

final class QueueController extends BaseController {
    private QueueRepository $queue;

    public function __construct() {
        $this->queue = new QueueRepository();
    }

    public function register(): void {
        register_rest_route(
            $this->namespace,
            '/queue',
            array(
                'methods'             => 'GET',
                'callback'            => array($this, 'all'),
                'permission_callback' => array($this, 'can_manage'),
            )
        );

        register_rest_route(
            $this->namespace,
            '/queue/enqueue',
            array(
                'methods'             => 'POST',
                'callback'            => array($this, 'enqueue'),
                'permission_callback' => array($this, 'can_manage'),
            )
        );

        register_rest_route(
            $this->namespace,
            '/queue/process',
            array(
                'methods'             => 'POST',
                'callback'            => array($this, 'process'),
                'permission_callback' => array($this, 'can_manage'),
            )
        );

        register_rest_route(
            $this->namespace,
            '/logs',
            array(
                'methods'             => 'GET',
                'callback'            => array($this, 'logs'),
                'permission_callback' => array($this, 'can_manage'),
            )
        );
    }

    /**
     * Lists jobs.
     *
     * @param WP_REST_Request $request Request.
     */
    public function all(WP_REST_Request $request): \WP_REST_Response {
        return $this->ok(
            array(
                'queue' => $this->queue->all(
                    array(
                        'status' => sanitize_key((string) $request->get_param('status')),
                        'limit'  => absint($request->get_param('limit') ?: 50),
                    )
                ),
            )
        );
    }

    /**
     * Enqueues bulk jobs.
     *
     * @param WP_REST_Request $request Request.
     */
    public function enqueue(WP_REST_Request $request) {
        $body        = $this->body($request);
        $product_ids = Sanitizer::ids($body['product_ids'] ?? array());
        $actions     = isset($body['actions']) && is_array($body['actions']) ? array_map('sanitize_key', $body['actions']) : array('product_bundle');

        if (empty($product_ids)) {
            return $this->error(__('Add at least one product ID.', 'aiseo-content-studio'));
        }

        $ids = (new QueueService())->enqueue_products($product_ids, $actions, $body);
        return $this->ok(array('queued' => $ids, 'count' => count($ids)), 201);
    }

    /**
     * Processes queue now.
     *
     * @param WP_REST_Request $request Request.
     */
    public function process(WP_REST_Request $request): \WP_REST_Response {
        $limit = absint($request->get_param('limit') ?: 3);
        return $this->ok((new QueueService())->process($limit));
    }

    /**
     * Lists logs.
     *
     * @param WP_REST_Request $request Request.
     */
    public function logs(WP_REST_Request $request): \WP_REST_Response {
        return $this->ok(
            array(
                'logs' => (new LogRepository())->all(
                    array(
                        'provider' => sanitize_key((string) $request->get_param('provider')),
                        'status'   => sanitize_key((string) $request->get_param('status')),
                        'limit'    => absint($request->get_param('limit') ?: 50),
                    )
                ),
            )
        );
    }
}
