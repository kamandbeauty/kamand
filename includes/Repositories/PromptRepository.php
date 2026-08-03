<?php
/**
 * Prompt repository.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Repositories;

use AISEOContentStudio\Database\Schema;
use AISEOContentStudio\Helpers\Sanitizer;

if (! defined('ABSPATH')) {
    exit;
}

final class PromptRepository {
    private string $table;

    public function __construct() {
        $this->table = Schema::table('prompts');
    }

    /**
     * Lists prompts.
     *
     * @param array<string,mixed> $args Query args.
     * @return array<int,array<string,mixed>>
     */
    public function all(array $args = array()): array {
        global $wpdb;

        $where  = array('1=1');
        $values = array();

        if (! empty($args['category'])) {
            $where[]  = 'category = %s';
            $values[] = sanitize_key((string) $args['category']);
        }

        if (isset($args['favorite'])) {
            $where[]  = 'is_favorite = %d';
            $values[] = empty($args['favorite']) ? 0 : 1;
        }

        $limit  = isset($args['limit']) ? min(200, max(1, absint($args['limit']))) : 100;
        $offset = isset($args['offset']) ? max(0, absint($args['offset'])) : 0;

        $sql = "SELECT * FROM {$this->table} WHERE " . implode(' AND ', $where) . ' ORDER BY is_favorite DESC, updated_at DESC LIMIT %d OFFSET %d';
        $values[] = $limit;
        $values[] = $offset;

        $rows = $wpdb->get_results($wpdb->prepare($sql, $values), ARRAY_A);
        if (! is_array($rows)) {
            return array();
        }

        return array_map(array($this, 'normalize'), $rows);
    }

    /**
     * Counts prompts.
     */
    public function count(): int {
        global $wpdb;

        return (int) $wpdb->get_var("SELECT COUNT(*) FROM {$this->table}");
    }

    /**
     * Finds a prompt.
     *
     * @param int $id Prompt ID.
     * @return array<string,mixed>|null
     */
    public function find(int $id): ?array {
        global $wpdb;

        $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->table} WHERE id = %d", $id), ARRAY_A);
        return is_array($row) ? $this->normalize($row) : null;
    }

    /**
     * Creates a prompt.
     *
     * @param array<string,mixed> $data Prompt data.
     */
    public function create(array $data): int {
        global $wpdb;

        $prepared = $this->prepare($data, false);
        $inserted = $wpdb->insert($this->table, $prepared, $this->formats($prepared));
        return false === $inserted ? 0 : (int) $wpdb->insert_id;
    }

    /**
     * Updates a prompt.
     *
     * @param int                 $id Prompt ID.
     * @param array<string,mixed> $data Prompt data.
     */
    public function update(int $id, array $data): bool {
        global $wpdb;

        $prepared = $this->prepare($data, true);
        if (empty($prepared)) {
            return false;
        }

        return false !== $wpdb->update($this->table, $prepared, array('id' => $id), $this->formats($prepared), array('%d'));
    }

    /**
     * Deletes a prompt.
     *
     * @param int $id Prompt ID.
     */
    public function delete(int $id): bool {
        global $wpdb;

        return false !== $wpdb->delete($this->table, array('id' => $id), array('%d'));
    }

    /**
     * Imports prompts.
     *
     * @param array<int,array<string,mixed>> $prompts Prompt list.
     */
    public function import(array $prompts): int {
        $count = 0;
        foreach ($prompts as $prompt) {
            if (is_array($prompt) && ! empty($prompt['title']) && ! empty($prompt['content'])) {
                $this->create($prompt);
                ++$count;
            }
        }
        return $count;
    }

    /**
     * Normalizes a prompt row.
     *
     * @param array<string,mixed> $row Row.
     * @return array<string,mixed>
     */
    private function normalize(array $row): array {
        $row['id']          = isset($row['id']) ? (int) $row['id'] : 0;
        $row['created_by']  = isset($row['created_by']) ? (int) $row['created_by'] : 0;
        $row['is_favorite'] = ! empty($row['is_favorite']);
        $variables          = json_decode((string) ($row['variables'] ?? ''), true);
        $row['variables']   = is_array($variables) ? $variables : array();
        return $row;
    }

    /**
     * Prepares prompt data.
     *
     * @param array<string,mixed> $data Raw data.
     * @param bool                $partial Partial update.
     * @return array<string,mixed>
     */
    private function prepare(array $data, bool $partial): array {
        $now      = current_time('mysql', true);
        $prepared = array();

        if (! $partial || array_key_exists('title', $data)) {
            $prepared['title'] = sanitize_text_field((string) ($data['title'] ?? ''));
        }

        if (! $partial || array_key_exists('slug', $data) || array_key_exists('title', $data)) {
            $slug             = ! empty($data['slug']) ? (string) $data['slug'] : (string) ($data['title'] ?? '');
            $prepared['slug'] = sanitize_title($slug);
        }

        if (! $partial || array_key_exists('category', $data)) {
            $prepared['category'] = sanitize_key((string) ($data['category'] ?? 'general'));
        }

        if (! $partial || array_key_exists('content', $data)) {
            $prepared['content'] = sanitize_textarea_field((string) ($data['content'] ?? ''));
        }

        if (! $partial || array_key_exists('variables', $data)) {
            $variables             = isset($data['variables']) && is_array($data['variables']) ? Sanitizer::recursive($data['variables']) : array();
            $prepared['variables'] = wp_json_encode($variables, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }

        if (! $partial || array_key_exists('language', $data)) {
            $prepared['language'] = sanitize_text_field((string) ($data['language'] ?? ''));
        }

        if (! $partial || array_key_exists('is_favorite', $data)) {
            $prepared['is_favorite'] = empty($data['is_favorite']) ? 0 : 1;
        }

        if (! $partial) {
            $prepared['created_by'] = get_current_user_id();
            $prepared['created_at'] = $now;
        }
        $prepared['updated_at'] = $now;

        return $prepared;
    }

    /**
     * Returns formats.
     *
     * @param array<string,mixed> $data Data.
     * @return array<int,string>
     */
    private function formats(array $data): array {
        $formats = array();
        foreach ($data as $key => $value) {
            $formats[] = in_array($key, array('is_favorite', 'created_by'), true) ? '%d' : '%s';
        }
        return $formats;
    }
}
