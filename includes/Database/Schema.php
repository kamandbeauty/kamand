<?php
/**
 * Database schema names and SQL.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Database;

if (! defined('ABSPATH')) {
    exit;
}

final class Schema {
    public const VERSION = '1.0.0';

    /**
     * Returns a plugin table name.
     *
     * @param string $name Logical table suffix.
     */
    public static function table(string $name): string {
        global $wpdb;

        return $wpdb->prefix . 'aiseocs_' . sanitize_key($name);
    }

    /**
     * Returns all plugin tables.
     *
     * @return array<string,string>
     */
    public static function tables(): array {
        return array(
            'providers' => self::table('providers'),
            'prompts'   => self::table('prompts'),
            'history'   => self::table('history'),
            'logs'      => self::table('logs'),
            'cache'     => self::table('cache'),
            'queue'     => self::table('queue'),
        );
    }

    /**
     * Returns dbDelta SQL statements.
     *
     * @return array<int,string>
     */
    public static function statements(): array {
        global $wpdb;

        $charset = $wpdb->get_charset_collate();
        $tables  = self::tables();

        return array(
            "CREATE TABLE {$tables['providers']} (
                id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
                name varchar(191) NOT NULL,
                slug varchar(191) NOT NULL,
                type varchar(50) NOT NULL,
                base_url text NOT NULL,
                endpoint_path varchar(255) NOT NULL DEFAULT '',
                image_endpoint_path varchar(255) NOT NULL DEFAULT '',
                api_key_encrypted longtext NULL,
                default_model varchar(191) NOT NULL DEFAULT '',
                models longtext NULL,
                headers longtext NULL,
                options longtext NULL,
                is_active tinyint(1) NOT NULL DEFAULT 1,
                is_default tinyint(1) NOT NULL DEFAULT 0,
                created_at datetime NOT NULL,
                updated_at datetime NOT NULL,
                PRIMARY KEY  (id),
                UNIQUE KEY slug (slug),
                KEY type (type),
                KEY is_active (is_active),
                KEY is_default (is_default)
            ) {$charset};",
            "CREATE TABLE {$tables['prompts']} (
                id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
                title varchar(191) NOT NULL,
                slug varchar(191) NOT NULL,
                category varchar(100) NOT NULL DEFAULT 'general',
                content longtext NOT NULL,
                variables longtext NULL,
                is_favorite tinyint(1) NOT NULL DEFAULT 0,
                language varchar(20) NOT NULL DEFAULT '',
                created_by bigint(20) unsigned NOT NULL DEFAULT 0,
                created_at datetime NOT NULL,
                updated_at datetime NOT NULL,
                PRIMARY KEY  (id),
                UNIQUE KEY slug (slug),
                KEY category (category),
                KEY is_favorite (is_favorite),
                KEY created_by (created_by)
            ) {$charset};",
            "CREATE TABLE {$tables['history']} (
                id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
                object_type varchar(50) NOT NULL DEFAULT 'content',
                object_id bigint(20) unsigned NOT NULL DEFAULT 0,
                feature varchar(100) NOT NULL DEFAULT '',
                provider varchar(100) NOT NULL DEFAULT '',
                model varchar(191) NOT NULL DEFAULT '',
                prompt_hash char(64) NOT NULL DEFAULT '',
                prompt longtext NOT NULL,
                request longtext NULL,
                response longtext NOT NULL,
                parsed_response longtext NULL,
                status varchar(30) NOT NULL DEFAULT 'success',
                created_by bigint(20) unsigned NOT NULL DEFAULT 0,
                created_at datetime NOT NULL,
                PRIMARY KEY  (id),
                KEY object_lookup (object_type, object_id),
                KEY feature (feature),
                KEY provider (provider),
                KEY prompt_hash (prompt_hash),
                KEY created_by (created_by),
                KEY created_at (created_at)
            ) {$charset};",
            "CREATE TABLE {$tables['logs']} (
                id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
                provider varchar(100) NOT NULL DEFAULT '',
                model varchar(191) NOT NULL DEFAULT '',
                endpoint varchar(255) NOT NULL DEFAULT '',
                prompt_tokens int(11) NOT NULL DEFAULT 0,
                completion_tokens int(11) NOT NULL DEFAULT 0,
                total_tokens int(11) NOT NULL DEFAULT 0,
                estimated_cost decimal(18,8) NOT NULL DEFAULT 0,
                response_time_ms int(11) NOT NULL DEFAULT 0,
                status_code int(11) NOT NULL DEFAULT 0,
                status varchar(30) NOT NULL DEFAULT 'success',
                error_message text NULL,
                request_hash char(64) NOT NULL DEFAULT '',
                created_by bigint(20) unsigned NOT NULL DEFAULT 0,
                created_at datetime NOT NULL,
                PRIMARY KEY  (id),
                KEY provider (provider),
                KEY model (model),
                KEY status (status),
                KEY request_hash (request_hash),
                KEY created_at (created_at)
            ) {$charset};",
            "CREATE TABLE {$tables['cache']} (
                id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
                cache_key char(64) NOT NULL,
                provider varchar(100) NOT NULL DEFAULT '',
                model varchar(191) NOT NULL DEFAULT '',
                response longtext NOT NULL,
                tokens longtext NULL,
                expires_at datetime NOT NULL,
                created_at datetime NOT NULL,
                updated_at datetime NOT NULL,
                PRIMARY KEY  (id),
                UNIQUE KEY cache_key (cache_key),
                KEY provider_model (provider, model),
                KEY expires_at (expires_at)
            ) {$charset};",
            "CREATE TABLE {$tables['queue']} (
                id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
                job_type varchar(80) NOT NULL DEFAULT 'product_generation',
                object_type varchar(50) NOT NULL DEFAULT 'product',
                object_id bigint(20) unsigned NOT NULL DEFAULT 0,
                action varchar(100) NOT NULL DEFAULT '',
                status varchar(30) NOT NULL DEFAULT 'pending',
                priority int(11) NOT NULL DEFAULT 10,
                attempts int(11) NOT NULL DEFAULT 0,
                max_attempts int(11) NOT NULL DEFAULT 3,
                payload longtext NULL,
                result longtext NULL,
                error_message text NULL,
                scheduled_at datetime NOT NULL,
                started_at datetime NULL,
                completed_at datetime NULL,
                created_by bigint(20) unsigned NOT NULL DEFAULT 0,
                created_at datetime NOT NULL,
                updated_at datetime NOT NULL,
                PRIMARY KEY  (id),
                KEY queue_lookup (status, scheduled_at, priority),
                KEY object_lookup (object_type, object_id),
                KEY action (action)
            ) {$charset};",
        );
    }
}
