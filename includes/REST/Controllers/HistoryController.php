<?php
/**
 * History REST controller.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\REST\Controllers;

use AISEOContentStudio\Repositories\HistoryRepository;
use AISEOContentStudio\WooCommerce\ProductContentApplier;
use WP_REST_Request;

if (! defined('ABSPATH')) {
    exit;
}

final class HistoryController extends BaseController {
    private HistoryRepository $history;

    public function __construct() {
        $this->history = new HistoryRepository();
    }

    public function register(): void {
        register_rest_route(
            $this->namespace,
            '/history',
            array(
                'methods'             => 'GET',
                'callback'            => array($this, 'all'),
                'permission_callback' => array($this, 'can_edit_posts'),
            )
        );

        register_rest_route(
            $this->namespace,
            '/history/(?P<id>\d+)',
            array(
                array(
                    'methods'             => 'GET',
                    'callback'            => array($this, 'find'),
                    'permission_callback' => array($this, 'can_edit_posts'),
                    'args'                => array('id' => array('sanitize_callback' => 'absint')),
                ),
                array(
                    'methods'             => 'POST',
                    'callback'            => array($this, 'restore'),
                    'permission_callback' => array($this, 'can_edit_posts'),
                    'args'                => array('id' => array('sanitize_callback' => 'absint')),
                ),
            )
        );

        register_rest_route(
            $this->namespace,
            '/history/(?P<id>\d+)/diff',
            array(
                'methods'             => 'GET',
                'callback'            => array($this, 'diff'),
                'permission_callback' => array($this, 'can_edit_posts'),
                'args'                => array('id' => array('sanitize_callback' => 'absint')),
            )
        );
    }

    /**
     * Lists history.
     *
     * @param WP_REST_Request $request Request.
     */
    public function all(WP_REST_Request $request): \WP_REST_Response {
        return $this->ok(
            array(
                'history' => $this->history->all(
                    array(
                        'object_type' => sanitize_key((string) $request->get_param('object_type')),
                        'object_id'   => absint($request->get_param('object_id')),
                        'feature'     => sanitize_key((string) $request->get_param('feature')),
                        'limit'       => absint($request->get_param('limit') ?: 50),
                    )
                ),
            )
        );
    }

    /**
     * Finds one history record.
     *
     * @param WP_REST_Request $request Request.
     */
    public function find(WP_REST_Request $request) {
        $record = $this->history->find(absint($request['id']));
        if (! $record) {
            return $this->error(__('History record not found.', 'aiseo-content-studio'), 'aiseocs_history_not_found', 404);
        }
        return $this->ok(array('history' => $record));
    }

    /**
     * Restores history content.
     *
     * @param WP_REST_Request $request Request.
     */
    public function restore(WP_REST_Request $request) {
        $record = $this->history->find(absint($request['id']));
        if (! $record) {
            return $this->error(__('History record not found.', 'aiseo-content-studio'), 'aiseocs_history_not_found', 404);
        }

        $object_id = (int) $record['object_id'];
        if ($object_id && ! current_user_can('edit_post', $object_id)) {
            return $this->error(__('You do not have permission to restore this content.', 'aiseo-content-studio'), 'aiseocs_forbidden', 403);
        }

        if ('product' === $record['object_type'] && is_array($record['parsed_response'])) {
            $result = (new ProductContentApplier())->apply($object_id, $record['parsed_response']);
            return $this->ok(array('restored' => true, 'result' => $result));
        }

        if ($object_id) {
            $result = wp_update_post(
                wp_slash(
                    array(
                        'ID'           => $object_id,
                        'post_content' => wp_kses_post((string) $record['response']),
                    )
                ),
                true
            );
            if (is_wp_error($result)) {
                return $this->error($result->get_error_message());
            }
            return $this->ok(array('restored' => true, 'post_id' => $object_id));
        }

        return $this->error(__('This history record is not connected to editable content.', 'aiseo-content-studio'));
    }

    /**
     * Returns an HTML diff.
     *
     * @param WP_REST_Request $request Request.
     */
    public function diff(WP_REST_Request $request) {
        $record = $this->history->find(absint($request['id']));
        if (! $record) {
            return $this->error(__('History record not found.', 'aiseo-content-studio'), 'aiseocs_history_not_found', 404);
        }

        require_once ABSPATH . 'wp-admin/includes/revision.php';
        $current = '';
        if (! empty($record['object_id'])) {
            $current = (string) get_post_field('post_content', (int) $record['object_id']);
        }
        $diff = wp_text_diff($current, (string) $record['response']);

        return $this->ok(array('diff' => wp_kses_post((string) $diff)));
    }
}
