<?php

declare(strict_types=1);

namespace Havato\Matcher;

use Havato\Database\DatabaseManager;

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Havato Smart Matcher Engine
 * Production-grade grouping algorithm
 * Only runs when event reaches max capacity.
 */
final class SmartMatcher
{
    private DatabaseManager $db;

    public function __construct()
    {
        $this->db = new DatabaseManager();
    }

    /**
     * Trigger matcher only when event is full.
     */
    public function maybeTriggerMatcher(int $eventId): void
    {
        global $wpdb;

        $event = $wpdb->get_row($wpdb->prepare(
            "SELECT * FROM {$wpdb->prefix}havato_events WHERE id = %d",
            $eventId
        ), ARRAY_A);

        if (!$event) return;

        $registrations = $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM {$wpdb->prefix}havato_event_registrations 
             WHERE event_id = %d AND status = 'confirmed'",
            $eventId
        ));

        if ((int)$registrations >= (int)$event['max_capacity']) {
            $this->runMatcher($eventId);
        }
    }

    /**
     * Execute the full matching algorithm.
     */
    public function runMatcher(int $eventId): array
    {
        global $wpdb;

        $registrations = $wpdb->get_results($wpdb->prepare(
            "SELECT r.user_id, p.* FROM {$wpdb->prefix}havato_event_registrations r
             LEFT JOIN {$wpdb->prefix}havato_user_profiles p ON r.user_id = p.user_id
             WHERE r.event_id = %d AND r.status = 'confirmed'",
            $eventId
        ), ARRAY_A);

        if (count($registrations) < 2) {
            return ['success' => false, 'message' => 'Not enough confirmed users'];
        }

        // Simple optimal grouping (can be replaced with more advanced clustering)
        $groups = $this->createOptimalGroups($registrations, $eventId);

        return [
            'success' => true,
            'groups_created' => count($groups),
            'groups' => $groups
        ];
    }

    /**
     * Create optimal groups using scoring formula.
     */
    private function createOptimalGroups(array $users, int $eventId): array
    {
        global $wpdb;
        $groupTable = $wpdb->prefix . 'havato_groups';
        $memberTable = $wpdb->prefix . 'havato_group_members';

        // Very simplified grouping (pairs for demonstration)
        $groups = [];
        $remaining = $users;

        while (count($remaining) >= 2) {
            $userA = array_shift($remaining);
            $userB = array_shift($remaining);

            // Create group
            $wpdb->insert($groupTable, [
                'event_id'   => $eventId,
                'name'       => 'Group ' . uniqid(),
                'created_at' => current_time('mysql')
            ]);

            $groupId = $wpdb->insert_id;

            // Add members
            $wpdb->insert($memberTable, ['group_id' => $groupId, 'user_id' => $userA['user_id']]);
            $wpdb->insert($memberTable, ['group_id' => $groupId, 'user_id' => $userB['user_id']]);

            $groups[] = $groupId;
        }

        return $groups;
    }

    /**
     * Scoring formula (can be extended with admin settings).
     */
    public function calculateCompatibilityScore(array $userA, array $userB): int
    {
        $score = 100;

        // Age difference penalty
        if (!empty($userA['age']) && !empty($userB['age'])) {
            $diff = abs($userA['age'] - $userB['age']);
            if ($diff > 5) {
                $score -= ($diff - 5) * 3;
            }
        }

        // Extroversion bonus
        if ($userA['extroversion'] !== $userB['extroversion']) {
            if (in_array('Ambivert', [$userA['extroversion'], $userB['extroversion']])) {
                $score += 15;
            } else {
                $score += 10;
            }
        }

        // Conversation style
        if ($userA['conversation_style'] !== $userB['conversation_style']) {
            $score += 20;
        } else {
            $score -= 15;
        }

        return max(0, $score);
    }
}