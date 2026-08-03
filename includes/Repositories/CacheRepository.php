<?php
/**
 * AI response cache repository.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Repositories;

use AISEOContentStudio\Database\Schema;

if (! defined('ABSPATH')) {
    exit;
}

final class CacheRepository {
    private string $table;

    public function __construct() {
        $this->table = Schema::table('cache');
    }

    /**
     * Returns a cached response.
     *
     * @param string $key Cache key.
     * @return array<string,mixed>|null
     */
    public function get(string $key): ?array {
        global $wpdb;

        $transient = get_transient('aiseocs_cache_' . $key);
        if (is_array($transient)) {
            return $transient;
        }

        $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM {$this->table} WHERE cache_key = %s AND expires_at > UTC_TIMESTAMP()", $key), ARRAY_A);
        if (! is_array($row)) {
            return null;
        }

        $response = json_decode((string) $row['response'], true);
        if (is_array($response)) {
            $ttl = max(60, strtotime((string) $row['expires_at'] . ' UTC') - time());
            set_transient('aiseocs_cache_' . $key, $response, $ttl);
            return $response;
        }

        return null;
    }

    /**
     * Stores a cached response.
     *
     * @param string              $key Cache key.
     * @param string              $provider Provider slug.
     * @param string              $model Model.
     * @param array<string,mixed> $response Response.
     * @param array<string,mixed> $tokens Token data.
     * @param int                 $ttl Time to live in seconds.
     */
    public function set(string $key, string $provider, string $model, array $response, array $tokens, int $ttl): bool {
        global $wpdb;

        $now     = current_time('mysql', true);
        $expires = gmdate('Y-m-d H:i:s', time() + max(60, $ttl));
        set_transient('aiseocs_cache_' . $key, $response, max(60, $ttl));

        $data    = array(
            'cache_key'  => $key,
            'provider'   => sanitize_key($provider),
            'model'      => sanitize_text_field($model),
            'response'   => wp_json_encode($response, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'tokens'     => wp_json_encode($tokens, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'expires_at' => $expires,
            'updated_at' => $now,
        );

        $exists = $wpdb->get_var($wpdb->prepare("SELECT id FROM {$this->table} WHERE cache_key = %s", $key));
        if ($exists) {
            return false !== $wpdb->update(
                $this->table,
                $data,
                array('cache_key' => $key),
                array('%s', '%s', '%s', '%s', '%s', '%s', '%s'),
                array('%s')
            );
        }

        $data['created_at'] = $now;
        return false !== $wpdb->insert($this->table, $data, array('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s'));
    }

    /**
     * Deletes expired records.
     */
    public function prune(): int {
        global $wpdb;

        return (int) $wpdb->query("DELETE FROM {$this->table} WHERE expires_at <= UTC_TIMESTAMP()");
    }

    /**
     * Flushes cache.
     */
    public function flush(): int {
        global $wpdb;

        return (int) $wpdb->query("TRUNCATE TABLE {$this->table}");
    }
}
