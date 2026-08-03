<?php
/**
 * Cron scheduler.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Services;

use AISEOContentStudio\Database\Installer;
use AISEOContentStudio\Repositories\CacheRepository;
use AISEOContentStudio\Repositories\HistoryRepository;

if (! defined('ABSPATH')) {
    exit;
}

final class Scheduler {
    /**
     * Registers cron hooks.
     */
    public function hooks(): void {
        add_filter('cron_schedules', array($this, 'intervals'));
        add_action(Installer::CRON_HOOK, array($this, 'process_queue'));
        add_action('aiseocs_daily_maintenance', array($this, 'maintenance'));

        Installer::schedule_cron();

        if (! wp_next_scheduled('aiseocs_daily_maintenance')) {
            wp_schedule_event(time() + HOUR_IN_SECONDS, 'daily', 'aiseocs_daily_maintenance');
        }
    }

    /**
     * Adds custom intervals.
     *
     * @param array<string,array<string,mixed>> $schedules Schedules.
     * @return array<string,array<string,mixed>>
     */
    public function intervals(array $schedules): array {
        $schedules['aiseocs_every_minute'] = array(
            'interval' => MINUTE_IN_SECONDS,
            'display'  => __('Every Minute', 'aiseo-content-studio'),
        );
        return $schedules;
    }

    /**
     * Processes queue.
     */
    public function process_queue(): void {
        (new QueueService())->process();
    }

    /**
     * Runs maintenance tasks.
     */
    public function maintenance(): void {
        (new CacheRepository())->prune();
        $settings = new SettingsService();
        (new HistoryRepository())->prune((int) $settings->get('history_retention_days', 180));
    }
}
