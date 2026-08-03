<?php
/**
 * Generation history repository.
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

final class HistoryRepository {
    private string $table;

    public function __construct() {
        $this->table = Schema::table('history');
    }

    /**
     * Creates a history record.
     *
     * @param array<string,mixed> $data Record data.
     */
    public function create(array $data): int {
        global $wpdb;

        $record = array(
            'object_type'     => sanitize_key((string) ($data['object_type'] ?? 'content')),
            'object_id'       => absint($data['object_id'] ?? 0),
            'feature'         => sanitize_key((string) ($data['feature'] ?? '')),
            'provider'        => sanitize_key((string) ($data['provider'] ?? '')),
            'model'           => sanitize_text_field((string) ($data['model'] ?? '')),
            'prompt_hash'     => sanitize_text_field((string) ($data['prompt_hash'] ?? '')),
            'prompt'          => sanitize_textarea_field((string) ($data['prompt'] ?? '')),
            'request'         => wp_json_encode($data['request'] ?? array(), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'response'        => wp_kses_post((string) ($data['response'] ?? '')),
            'parsed_response' => wp_json_encode($data['parsed_response'] ?? null, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'status'          => sanitize_key((string) ($data['status'] ?? 'success')),
            'created_by'      => get_current_user_id(),
            'created_at'      => current_time('mysql', true),
        );

        $wpdb->insert(
            $this->table,
            $record,
            array('%s', '%d', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%d', '%s')
        );

        return (int) $wpdb->insert_id;
    }

    /**
     * Lists history records.
     *
     * @param array<string,mixed> $args Query args.
     * @return array<int,array<string,mixed>>
     */
    public function all(array $args = array()): array {
        global $wpdb;

        $where  = array('1=1');
        $values = array();

        if (! empty($args['object_type'])) {
            $where[]  = 'object_type = %s';
            $values[] = sanitize_key((string) $args['object_type']);
        }
        if (! empty($args['object_id'])) {
            $where[]  = 'object_id = %d';
            $values[] = absint($args['object_id']);
        }
        if (! empty($args['feature'])) {
            $where[]  = 'feature = %s';
            $values[] = sanitize_key((string) $args['feature']);
        }

        $limit  = isset($args['limit']) ? min(200, max(1, absint($args['limit']))) : 50;
        $offset = isset($args['offset']) ? max(0, absint($args['offset'])) : 0;
        $sql    = "SELECT * FROM {$this->table} WHERE " . implode(' AND ', $where) . ' ORDER BY created_at DESC, id DESC LIMIT %d OFFSET %d';
        $values[] = $limit;
        $values[] = $offset;

        $rows = $wpdb->get_results($wpdb->prepare($sql, $values), ARRAY_A);
        if (! is_array($rows)) {
            return array();
        }

        return array_map(array($this, 'normalize'), $rows);
    }

    /**
     * Finds a record.
     *
     * @param int $id History ID.
     * @return array<string,mixed>|null
     */
    public function find(int $id): ?array {
        global $wpdb;

        $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->table} WHERE id = %d", $id), ARRAY_A);
        return is_array($row) ? $this->normalize($row) : null;
    }

    /**
     * Deletes old cache-safe history records.
     *
     * @param int $days Retention days.
     */
    public function prune(int $days): int {
        global $wpdb;

        $days = max(1, $days);
        return (int) $wpdb->query($wpdb->prepare("DELETE FROM {$this->table} WHERE created_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL %d DAY)", $days));
    }

    /**
     * Normalizes a row.
     *
     * @param array<string,mixed> $row Row.
     * @return array<string,mixed>
     */
    private function normalize(array $row): array {
        $row['id']         = (int) ($row['id'] ?? 0);
        $row['object_id']  = (int) ($row['object_id'] ?? 0);
        $row['created_by'] = (int) ($row['created_by'] ?? 0);
        $request           = json_decode((string) ($row['request'] ?? ''), true);
        $parsed            = json_decode((string) ($row['parsed_response'] ?? ''), true);
        $row['request']    = is_array($request) ? Sanitizer::recursive($request, array('seo_description_html', 'short_description_html')) : array();
        $row['parsed_response'] = is_array($parsed) ? $parsed : null;
        return $row;
    }
}
