<?php
/**
 * Request log repository.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Repositories;

use AISEOContentStudio\Database\Schema;

if (! defined('ABSPATH')) {
    exit;
}

final class LogRepository {
    private string $table;

    public function __construct() {
        $this->table = Schema::table('logs');
    }

    /**
     * Creates a log record.
     *
     * @param array<string,mixed> $data Data.
     */
    public function create(array $data): int {
        global $wpdb;

        $record = array(
            'provider'          => sanitize_key((string) ($data['provider'] ?? '')),
            'model'             => sanitize_text_field((string) ($data['model'] ?? '')),
            'endpoint'          => esc_url_raw((string) ($data['endpoint'] ?? '')),
            'prompt_tokens'     => absint($data['prompt_tokens'] ?? 0),
            'completion_tokens' => absint($data['completion_tokens'] ?? 0),
            'total_tokens'      => absint($data['total_tokens'] ?? 0),
            'estimated_cost'    => (string) (float) ($data['estimated_cost'] ?? 0),
            'response_time_ms'  => absint($data['response_time_ms'] ?? 0),
            'status_code'       => absint($data['status_code'] ?? 0),
            'status'            => sanitize_key((string) ($data['status'] ?? 'success')),
            'error_message'     => sanitize_textarea_field((string) ($data['error_message'] ?? '')),
            'request_hash'      => sanitize_text_field((string) ($data['request_hash'] ?? '')),
            'created_by'        => get_current_user_id(),
            'created_at'        => current_time('mysql', true),
        );

        $wpdb->insert(
            $this->table,
            $record,
            array('%s', '%s', '%s', '%d', '%d', '%d', '%f', '%d', '%d', '%s', '%s', '%s', '%d', '%s')
        );

        return (int) $wpdb->insert_id;
    }

    /**
     * Lists logs.
     *
     * @param array<string,mixed> $args Query args.
     * @return array<int,array<string,mixed>>
     */
    public function all(array $args = array()): array {
        global $wpdb;

        $where  = array('1=1');
        $values = array();

        if (! empty($args['provider'])) {
            $where[]  = 'provider = %s';
            $values[] = sanitize_key((string) $args['provider']);
        }
        if (! empty($args['status'])) {
            $where[]  = 'status = %s';
            $values[] = sanitize_key((string) $args['status']);
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

        return array_map(
            static function (array $row): array {
                $row['id']                = (int) $row['id'];
                $row['prompt_tokens']     = (int) $row['prompt_tokens'];
                $row['completion_tokens'] = (int) $row['completion_tokens'];
                $row['total_tokens']      = (int) $row['total_tokens'];
                $row['estimated_cost']    = (float) $row['estimated_cost'];
                $row['response_time_ms']  = (int) $row['response_time_ms'];
                $row['status_code']       = (int) $row['status_code'];
                return $row;
            },
            $rows
        );
    }
}
