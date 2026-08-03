<?php
/**
 * Export/import REST controller.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\REST\Controllers;

use AISEOContentStudio\Services\ExportService;
use AISEOContentStudio\Services\SettingsService;
use WP_REST_Request;

if (! defined('ABSPATH')) {
    exit;
}

final class ExportController extends BaseController {
    public function register(): void {
        register_rest_route(
            $this->namespace,
            '/export/(?P<type>history|prompts)',
            array(
                'methods'             => 'GET',
                'callback'            => array($this, 'export'),
                'permission_callback' => array($this, 'can_manage'),
            )
        );

        register_rest_route(
            $this->namespace,
            '/settings/import',
            array(
                'methods'             => 'POST',
                'callback'            => array($this, 'import_settings'),
                'permission_callback' => array($this, 'can_manage'),
            )
        );
    }

    /**
     * Exports data.
     *
     * @param WP_REST_Request $request Request.
     */
    public function export(WP_REST_Request $request): \WP_REST_Response {
        $format  = sanitize_key((string) ($request->get_param('format') ?: 'json'));
        $type    = sanitize_key((string) $request['type']);
        $service = new ExportService();
        $export  = 'prompts' === $type ? $service->prompts($format) : $service->history($format, array('limit' => 200));

        return $this->ok(
            array(
                'filename'     => $export['filename'],
                'content_type' => $export['content_type'],
                'body'         => 'pdf' === $format ? base64_encode($export['body']) : $export['body'],
                'base64'       => 'pdf' === $format,
            )
        );
    }

    /**
     * Imports settings.
     *
     * @param WP_REST_Request $request Request.
     */
    public function import_settings(WP_REST_Request $request): \WP_REST_Response {
        $body     = $this->body($request);
        $settings = isset($body['settings']) && is_array($body['settings']) ? $body['settings'] : $body;
        $saved    = (new SettingsService())->update($settings);
        return $this->ok(array('settings' => $saved));
    }
}
