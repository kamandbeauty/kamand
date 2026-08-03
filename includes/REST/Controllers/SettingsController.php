<?php
/**
 * Settings and providers REST controller.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\REST\Controllers;

use AISEOContentStudio\Repositories\ProviderRepository;
use AISEOContentStudio\Services\SettingsService;
use WP_REST_Request;

if (! defined('ABSPATH')) {
    exit;
}

final class SettingsController extends BaseController {
    private SettingsService $settings;
    private ProviderRepository $providers;

    public function __construct() {
        $this->settings  = new SettingsService();
        $this->providers = new ProviderRepository();
    }

    public function register(): void {
        register_rest_route(
            $this->namespace,
            '/settings',
            array(
                array(
                    'methods'             => 'GET',
                    'callback'            => array($this, 'get_settings'),
                    'permission_callback' => array($this, 'can_manage'),
                ),
                array(
                    'methods'             => 'POST',
                    'callback'            => array($this, 'save_settings'),
                    'permission_callback' => array($this, 'can_manage'),
                ),
            )
        );

        register_rest_route(
            $this->namespace,
            '/providers',
            array(
                array(
                    'methods'             => 'GET',
                    'callback'            => array($this, 'providers'),
                    'permission_callback' => array($this, 'can_manage'),
                ),
                array(
                    'methods'             => 'POST',
                    'callback'            => array($this, 'create_provider'),
                    'permission_callback' => array($this, 'can_manage'),
                ),
            )
        );

        register_rest_route(
            $this->namespace,
            '/providers/(?P<id>\d+)',
            array(
                array(
                    'methods'             => 'PUT,PATCH',
                    'callback'            => array($this, 'update_provider'),
                    'permission_callback' => array($this, 'can_manage'),
                    'args'                => array('id' => array('sanitize_callback' => 'absint')),
                ),
                array(
                    'methods'             => 'DELETE',
                    'callback'            => array($this, 'delete_provider'),
                    'permission_callback' => array($this, 'can_manage'),
                    'args'                => array('id' => array('sanitize_callback' => 'absint')),
                ),
            )
        );
    }

    /**
     * Returns settings.
     */
    public function get_settings(): \WP_REST_Response {
        return $this->ok(
            array(
                'settings'  => $this->settings->all(),
                'providers' => $this->providers->all(false, false),
            )
        );
    }

    /**
     * Saves settings.
     *
     * @param WP_REST_Request $request Request.
     */
    public function save_settings(WP_REST_Request $request): \WP_REST_Response {
        $settings = $this->settings->update($this->body($request));
        if (! empty($settings['default_provider'])) {
            $provider = $this->providers->find_by_slug((string) $settings['default_provider']);
            if ($provider) {
                $this->providers->set_default((int) $provider['id']);
            }
        }

        return $this->ok(array('settings' => $settings));
    }

    /**
     * Returns providers.
     */
    public function providers(): \WP_REST_Response {
        return $this->ok(array('providers' => $this->providers->all(false, false)));
    }

    /**
     * Creates provider.
     *
     * @param WP_REST_Request $request Request.
     */
    public function create_provider(WP_REST_Request $request) {
        $id = $this->providers->create($this->body($request));
        if (! $id) {
            return $this->error(__('Unable to create provider.', 'aiseo-content-studio'));
        }

        $provider = $this->providers->find($id);
        if ($provider && ! empty($provider['is_default'])) {
            $this->settings->update(
                array(
                    'default_provider' => (string) $provider['slug'],
                    'default_model'    => (string) $provider['default_model'],
                )
            );
        }
        return $this->ok(array('provider' => $provider ? $this->public_provider($provider) : null), 201);
    }

    /**
     * Updates provider.
     *
     * @param WP_REST_Request $request Request.
     */
    public function update_provider(WP_REST_Request $request) {
        $id      = absint($request['id']);
        $updated = $this->providers->update($id, $this->body($request));
        if (! $updated) {
            return $this->error(__('Unable to update provider.', 'aiseo-content-studio'));
        }

        $provider = $this->providers->find($id);
        if ($provider && ! empty($provider['is_default'])) {
            $this->settings->update(
                array(
                    'default_provider' => (string) $provider['slug'],
                    'default_model'    => (string) $provider['default_model'],
                )
            );
        }
        return $this->ok(array('provider' => $provider ? $this->public_provider($provider) : null));
    }

    /**
     * Deletes provider.
     *
     * @param WP_REST_Request $request Request.
     */
    public function delete_provider(WP_REST_Request $request) {
        $deleted = $this->providers->delete(absint($request['id']));
        if (! $deleted) {
            return $this->error(__('Unable to delete provider.', 'aiseo-content-studio'));
        }

        return $this->ok(array('deleted' => true));
    }

    /**
     * Removes encrypted key.
     *
     * @param array<string,mixed> $provider Provider.
     * @return array<string,mixed>
     */
    private function public_provider(array $provider): array {
        unset($provider['api_key_encrypted']);
        return $provider;
    }
}
