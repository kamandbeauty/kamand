<?php

declare(strict_types=1);

namespace Havato\Database;

use wpdb;

if (!defined('ABSPATH')) {
    exit;
}

final class DatabaseManager
{
    private wpdb $wpdb;
    private string $charsetCollate;

    private array $tables = [
        'venues'               => 'wp_havato_venues',
        'events'               => 'wp_havato_events',
        'user_profiles'        => 'wp_havato_user_profiles',
        'event_registrations'  => 'wp_havato_event_registrations',
        'groups'               => 'wp_havato_groups',
        'group_members'        => 'wp_havato_group_members',
        'chats'                => 'wp_havato_chats',
        'feedbacks'            => 'wp_havato_feedbacks',
    ];

    public function __construct()
    {
        global $wpdb;
        $this->wpdb = $wpdb;
        $this->charsetCollate = $wpdb->get_charset_collate();
    }

    public function ensureTablesExist(): void
    {
        require_once ABSPATH . 'wp-admin/includes/upgrade.php';

        foreach ($this->tables as $key => $tableName) {
            if (!$this->tableExists($tableName)) {
                $this->createTable($key, $tableName);
            }
        }
    }

    private function tableExists(string $tableName): bool
    {
        $tableName = esc_sql($tableName);
        $result = $this->wpdb->get_var(
            $this->wpdb->prepare("SHOW TABLES LIKE %s", $tableName)
        );
        return $result === $tableName;
    }

    private function createTable(string $key, string $tableName): void
    {
        $sql = match ($key) {
            'venues' => $this->getVenuesTableSql($tableName),
            'events' => $this->getEventsTableSql($tableName),
            'user_profiles' => $this->getUserProfilesTableSql($tableName),
            'event_registrations' => $this->getRegistrationsTableSql($tableName),
            'groups' => $this->getGroupsTableSql($tableName),
            'group_members' => $this->getGroupMembersTableSql($tableName),
            'chats' => $this->getChatsTableSql($tableName),
            'feedbacks' => $this->getFeedbacksTableSql($tableName),
            default => '',
        };

        if ($sql) {
            dbDelta($sql);
        }
    }

    private function getVenuesTableSql(string $table): string
    {
        return "CREATE TABLE $table (
            id bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id bigint(20) UNSIGNED NOT NULL,
            name varchar(255) NOT NULL,
            description longtext,
            address varchar(500) NOT NULL,
            latitude decimal(10,8),
            longitude decimal(11,8),
            status varchar(20) DEFAULT 'pending' NOT NULL,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            updated_at datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY user_id (user_id),
            KEY status (status)
        ) $this->charsetCollate ENGINE=InnoDB;";
    }

    // Additional table SQL methods follow the same pattern...
    private function getEventsTableSql(string $table): string
    {
        return "CREATE TABLE $table (
            id bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
            venue_id bigint(20) UNSIGNED NOT NULL,
            title varchar(255) NOT NULL,
            description longtext,
            start_time datetime NOT NULL,
            end_time datetime NOT NULL,
            max_capacity int(11) DEFAULT 20,
            price decimal(10,2) DEFAULT 0.00,
            status varchar(20) DEFAULT 'open',
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY venue_id (venue_id),
            KEY status (status),
            KEY start_time (start_time)
        ) $this->charsetCollate ENGINE=InnoDB;";
    }

    private function getUserProfilesTableSql(string $table): string
    {
        return "CREATE TABLE $table (
            id bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id bigint(20) UNSIGNED NOT NULL UNIQUE,
            age tinyint UNSIGNED,
            gender varchar(20),
            extroversion varchar(20),
            talkative varchar(20),
            conversation_style varchar(30),
            interests text,
            personality_tags text,
            test_completed tinyint(1) DEFAULT 0,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            updated_at datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY user_id (user_id),
            KEY test_completed (test_completed)
        ) $this->charsetCollate ENGINE=InnoDB;";
    }

    private function getRegistrationsTableSql(string $table): string
    {
        return "CREATE TABLE $table (
            id bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
            event_id bigint(20) UNSIGNED NOT NULL,
            user_id bigint(20) UNSIGNED NOT NULL,
            status varchar(20) DEFAULT 'pending',
            payment_id varchar(100),
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY event_user (event_id, user_id),
            KEY status (status)
        ) $this->charsetCollate ENGINE=InnoDB;";
    }

    private function getGroupsTableSql(string $table): string
    {
        return "CREATE TABLE $table (
            id bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
            event_id bigint(20) UNSIGNED NOT NULL,
            name varchar(100),
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY event_id (event_id)
        ) $this->charsetCollate ENGINE=InnoDB;";
    }

    private function getGroupMembersTableSql(string $table): string
    {
        return "CREATE TABLE $table (
            id bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
            group_id bigint(20) UNSIGNED NOT NULL,
            user_id bigint(20) UNSIGNED NOT NULL,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY group_user (group_id, user_id)
        ) $this->charsetCollate ENGINE=InnoDB;";
    }

    private function getChatsTableSql(string $table): string
    {
        return "CREATE TABLE $table (
            id bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
            event_id bigint(20) UNSIGNED,
            group_id bigint(20) UNSIGNED,
            user_id bigint(20) UNSIGNED NOT NULL,
            message text NOT NULL,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY event_id (event_id),
            KEY group_id (group_id)
        ) $this->charsetCollate ENGINE=InnoDB;";
    }

    private function getFeedbacksTableSql(string $table): string
    {
        return "CREATE TABLE $table (
            id bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
            event_id bigint(20) UNSIGNED NOT NULL,
            user_id bigint(20) UNSIGNED NOT NULL,
            rating tinyint UNSIGNED,
            comment text,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) $this->charsetCollate ENGINE=InnoDB;";
    }
}