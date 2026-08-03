<?php
/**
 * Provider repository.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Repositories;

use AISEOContentStudio\Database\Schema;
use AISEOContentStudio\Helpers\Crypto;
use AISEOContentStudio\Helpers\Sanitizer;

if (! defined('ABSPATH')) {
    exit;
}

final class ProviderRepository {
    private string $table;

    public function __construct() {
        $this->table = Schema::table('providers');
    }

    /**
     * Returns providers.
     *
     * @param bool $active_only Return active providers only.
     * @param bool $include_secret Include encrypted API key.
     * @return array<int,array<string,mixed>>
     */
    public function all(bool $active_only = false, bool $include_secret = true): array {
        global $wpdb;

        if ($active_only) {
            $rows = $wpdb->get_results($wpdb->prepare("SELECT * FROM {$this->table} WHERE is_active = %d ORDER BY is_default DESC, name ASC", 1), ARRAY_A);
        } else {
            $rows = $wpdb->get_results("SELECT * FROM {$this->table} ORDER BY is_default DESC, name ASC", ARRAY_A);
        }

        if (! is_array($rows)) {
            return array();
        }

        return array_map(fn($row) => $this->normalize($row, $include_secret), $rows);
    }

    /**
     * Finds by slug.
     *
     * @param string $slug Provider slug.
     * @return array<string,mixed>|null
     */
    public function find_by_slug(string $slug): ?array {
        global $wpdb;

        $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->table} WHERE slug = %s", sanitize_key($slug)), ARRAY_A);
        return is_array($row) ? $this->normalize($row, true) : null;
    }

    /**
     * Finds by ID.
     *
     * @param int $id Provider ID.
     * @return array<string,mixed>|null
     */
    public function find(int $id): ?array {
        global $wpdb;

        $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->table} WHERE id = %d", $id), ARRAY_A);
        return is_array($row) ? $this->normalize($row, true) : null;
    }

    /**
     * Returns the default provider.
     *
     * @return array<string,mixed>|null
     */
    public function default(): ?array {
        global $wpdb;

        $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->table} WHERE is_default = %d AND is_active = %d LIMIT 1", 1, 1), ARRAY_A);
        if (is_array($row)) {
            return $this->normalize($row, true);
        }

        $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->table} WHERE is_active = %d ORDER BY id ASC LIMIT 1", 1), ARRAY_A);
        return is_array($row) ? $this->normalize($row, true) : null;
    }

    /**
     * Creates a provider.
     *
     * @param array<string,mixed> $data Provider data.
     */
    public function create(array $data): int {
        global $wpdb;

        $prepared = $this->prepare_data($data, false);
        $inserted = $wpdb->insert($this->table, $prepared, $this->formats($prepared));

        $id = false === $inserted ? 0 : (int) $wpdb->insert_id;
        if (! empty($prepared['is_default']) && $id > 0) {
            $this->set_default($id);
        }

        return $id;
    }

    /**
     * Updates a provider.
     *
     * @param int                 $id Provider ID.
     * @param array<string,mixed> $data Provider data.
     */
    public function update(int $id, array $data): bool {
        global $wpdb;

        $prepared = $this->prepare_data($data, true);
        if (empty($prepared)) {
            return false;
        }

        $updated = false !== $wpdb->update($this->table, $prepared, array('id' => $id), $this->formats($prepared), array('%d'));
        if ($updated && ! empty($prepared['is_default'])) {
            $this->set_default($id);
        }

        return $updated;
    }

    /**
     * Deletes a provider.
     *
     * @param int $id Provider ID.
     */
    public function delete(int $id): bool {
        global $wpdb;

        return false !== $wpdb->delete($this->table, array('id' => $id), array('%d'));
    }

    /**
     * Marks a provider as default.
     *
     * @param int $id Provider ID.
     */
    public function set_default(int $id): bool {
        global $wpdb;

        $wpdb->query("UPDATE {$this->table} SET is_default = 0");
        return false !== $wpdb->update($this->table, array('is_default' => 1), array('id' => $id), array('%d'), array('%d'));
    }

    /**
     * Normalizes database rows.
     *
     * @param array<string,mixed> $row Row.
     * @param bool                $include_secret Include encrypted key.
     * @return array<string,mixed>
     */
    public function normalize(array $row, bool $include_secret): array {
        $row['id']         = isset($row['id']) ? (int) $row['id'] : 0;
        $row['is_active']  = ! empty($row['is_active']);
        $row['is_default'] = ! empty($row['is_default']);
        $row['models']     = $this->json_array($row['models'] ?? null);
        $row['headers']    = $this->json_array($row['headers'] ?? null);
        $row['options']    = $this->json_array($row['options'] ?? null);
        $row['has_api_key'] = ! empty($row['api_key_encrypted']);

        if (! $include_secret) {
            unset($row['api_key_encrypted']);
        }

        return $row;
    }

    /**
     * Converts stored JSON to array.
     *
     * @param mixed $value JSON value.
     * @return array<string|int,mixed>
     */
    private function json_array($value): array {
        if (is_array($value)) {
            return $value;
        }

        if (! is_string($value) || '' === $value) {
            return array();
        }

        $decoded = json_decode($value, true);
        return is_array($decoded) ? $decoded : array();
    }

    /**
     * Prepares data for insert or update.
     *
     * @param array<string,mixed> $data Raw data.
     * @param bool                $partial Whether this is a partial update.
     * @return array<string,mixed>
     */
    private function prepare_data(array $data, bool $partial): array {
        $now      = current_time('mysql', true);
        $prepared = array();

        $fields = array('name', 'slug', 'type', 'base_url', 'endpoint_path', 'image_endpoint_path', 'default_model');
        foreach ($fields as $field) {
            if (! $partial || array_key_exists($field, $data)) {
                $value = isset($data[$field]) ? (string) $data[$field] : '';
                if ('slug' === $field || 'type' === $field) {
                    $prepared[$field] = sanitize_key($value);
                } elseif ('base_url' === $field) {
                    $prepared[$field] = esc_url_raw($value);
                } elseif ('default_model' === $field) {
                    $prepared[$field] = Sanitizer::model($value);
                } else {
                    $prepared[$field] = sanitize_text_field($value);
                }
            }
        }

        if (! $partial) {
            $prepared['name']          = $prepared['name'] ?: __('Custom Provider', 'aiseo-content-studio');
            $prepared['slug']          = $prepared['slug'] ?: sanitize_title($prepared['name']);
            $prepared['type']          = $prepared['type'] ?: 'custom';
            $prepared['endpoint_path'] = $prepared['endpoint_path'] ?: '/chat/completions';
        }

        if (array_key_exists('api_key', $data) && '' !== (string) $data['api_key']) {
            $prepared['api_key_encrypted'] = Crypto::encrypt(sanitize_text_field((string) $data['api_key']));
        }

        foreach (array('models', 'headers', 'options') as $field) {
            if (! $partial || array_key_exists($field, $data)) {
                $value = $data[$field] ?? array();
                if (is_string($value) && 'models' === $field) {
                    $value = preg_split('/[\r\n,]+/', $value);
                }
                if (! is_array($value)) {
                    $value = array();
                }
                $prepared[$field] = wp_json_encode(Sanitizer::recursive($value), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
            }
        }

        foreach (array('is_active', 'is_default') as $field) {
            if (! $partial || array_key_exists($field, $data)) {
                $prepared[$field] = empty($data[$field]) ? 0 : 1;
            }
        }

        if (! $partial) {
            $prepared['created_at'] = $now;
        }
        $prepared['updated_at'] = $now;

        return $prepared;
    }

    /**
     * Returns wpdb formats.
     *
     * @param array<string,mixed> $data Data.
     * @return array<int,string>
     */
    private function formats(array $data): array {
        $formats = array();
        foreach ($data as $key => $value) {
            $formats[] = in_array($key, array('is_active', 'is_default'), true) ? '%d' : '%s';
        }
        return $formats;
    }
}
