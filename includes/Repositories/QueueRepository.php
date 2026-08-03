<?php
/**
 * Queue repository.
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

final class QueueRepository {
    private string $table;

    public function __construct() {
        $this->table = Schema::table('queue');
    }

    /**
     * Enqueues a job.
     *
     * @param array<string,mixed> $data Job data.
     */
    public function enqueue(array $data): int {
        global $wpdb;

        $now    = current_time('mysql', true);
        $record = array(
            'job_type'     => sanitize_key((string) ($data['job_type'] ?? 'product_generation')),
            'object_type'  => sanitize_key((string) ($data['object_type'] ?? 'product')),
            'object_id'    => absint($data['object_id'] ?? 0),
            'action'       => sanitize_key((string) ($data['action'] ?? 'product_bundle')),
            'status'       => 'pending',
            'priority'     => isset($data['priority']) ? (int) $data['priority'] : 10,
            'attempts'     => 0,
            'max_attempts' => isset($data['max_attempts']) ? max(1, absint($data['max_attempts'])) : 3,
            'payload'      => wp_json_encode(isset($data['payload']) && is_array($data['payload']) ? Sanitizer::recursive($data['payload']) : array(), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'result'       => null,
            'error_message'=> null,
            'scheduled_at' => ! empty($data['scheduled_at']) ? gmdate('Y-m-d H:i:s', strtotime((string) $data['scheduled_at'])) : $now,
            'created_by'   => get_current_user_id(),
            'created_at'   => $now,
            'updated_at'   => $now,
        );

        $wpdb->insert(
            $this->table,
            $record,
            array('%s', '%s', '%d', '%s', '%s', '%d', '%d', '%d', '%s', '%s', '%s', '%s', '%d', '%s', '%s')
        );

        return (int) $wpdb->insert_id;
    }

    /**
     * Returns next jobs.
     *
     * @param int $limit Limit.
     * @return array<int,array<string,mixed>>
     */
    public function next(int $limit = 3): array {
        global $wpdb;

        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT * FROM {$this->table} WHERE status = %s AND scheduled_at <= UTC_TIMESTAMP() AND attempts < max_attempts ORDER BY priority ASC, scheduled_at ASC LIMIT %d",
                'pending',
                max(1, min(20, $limit))
            ),
            ARRAY_A
        );

        if (! is_array($rows)) {
            return array();
        }

        return array_map(array($this, 'normalize'), $rows);
    }

    /**
     * Lists jobs.
     *
     * @param array<string,mixed> $args Query args.
     * @return array<int,array<string,mixed>>
     */
    public function all(array $args = array()): array {
        global $wpdb;

        $where  = array('1=1');
        $values = array();

        if (! empty($args['status'])) {
            $where[]  = 'status = %s';
            $values[] = sanitize_key((string) $args['status']);
        }
        if (! empty($args['object_id'])) {
            $where[]  = 'object_id = %d';
            $values[] = absint($args['object_id']);
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
     * Marks a job as running.
     *
     * @param int $id Job ID.
     */
    public function mark_running(int $id): bool {
        global $wpdb;

        return false !== $wpdb->query(
            $wpdb->prepare(
                "UPDATE {$this->table} SET status = %s, attempts = attempts + 1, started_at = UTC_TIMESTAMP(), updated_at = UTC_TIMESTAMP() WHERE id = %d",
                'running',
                $id
            )
        );
    }

    /**
     * Marks a job complete.
     *
     * @param int                 $id Job ID.
     * @param array<string,mixed> $result Result.
     */
    public function complete(int $id, array $result): bool {
        global $wpdb;

        return false !== $wpdb->update(
            $this->table,
            array(
                'status'       => 'completed',
                'result'       => wp_json_encode($result, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                'completed_at' => current_time('mysql', true),
                'updated_at'   => current_time('mysql', true),
            ),
            array('id' => $id),
            array('%s', '%s', '%s', '%s'),
            array('%d')
        );
    }

    /**
     * Marks a job failed or requeues it when attempts remain.
     *
     * @param int    $id Job ID.
     * @param string $message Error message.
     */
    public function fail(int $id, string $message): bool {
        global $wpdb;

        $job = $this->find($id);
        if ($job && (int) $job['attempts'] < (int) $job['max_attempts']) {
            return false !== $wpdb->update(
                $this->table,
                array(
                    'status'        => 'pending',
                    'error_message' => sanitize_textarea_field($message),
                    'scheduled_at'  => gmdate('Y-m-d H:i:s', time() + (MINUTE_IN_SECONDS * (int) $job['attempts'])),
                    'updated_at'    => current_time('mysql', true),
                ),
                array('id' => $id),
                array('%s', '%s', '%s', '%s'),
                array('%d')
            );
        }

        return false !== $wpdb->update(
            $this->table,
            array(
                'status'        => 'failed',
                'error_message' => sanitize_textarea_field($message),
                'completed_at'  => current_time('mysql', true),
                'updated_at'    => current_time('mysql', true),
            ),
            array('id' => $id),
            array('%s', '%s', '%s', '%s'),
            array('%d')
        );
    }

    /**
     * Finds a job.
     *
     * @param int $id Job ID.
     * @return array<string,mixed>|null
     */
    public function find(int $id): ?array {
        global $wpdb;

        $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->table} WHERE id = %d", $id), ARRAY_A);
        return is_array($row) ? $this->normalize($row) : null;
    }

    /**
     * Normalizes a row.
     *
     * @param array<string,mixed> $row Row.
     * @return array<string,mixed>
     */
    private function normalize(array $row): array {
        foreach (array('id', 'object_id', 'priority', 'attempts', 'max_attempts', 'created_by') as $key) {
            $row[$key] = isset($row[$key]) ? (int) $row[$key] : 0;
        }
        $payload       = json_decode((string) ($row['payload'] ?? ''), true);
        $result        = json_decode((string) ($row['result'] ?? ''), true);
        $row['payload'] = is_array($payload) ? $payload : array();
        $row['result']  = is_array($result) ? $result : array();
        return $row;
    }
}
