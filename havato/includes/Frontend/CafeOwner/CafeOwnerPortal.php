<?php

declare(strict_types=1);

namespace Havato\Frontend\CafeOwner;

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Cafe Owner Portal - Production Ready
 * Separate page with tabs: Dashboard, Events, Menu Builder, Venue Settings
 */
final class CafeOwnerPortal
{
    public function render(): string
    {
        if (!current_user_can('havato_manage_venue')) {
            return '<div class="havato-app"><p>' . esc_html__('Access denied.', 'havato') . '</p></div>';
        }

        $userId = get_current_user_id();
        $venueStatus = get_user_meta($userId, 'havato_venue_status', true) ?: 'pending';

        ob_start();
        ?>
        <div class="havato-app cafe-owner-portal">
            <!-- Ambient Glow -->
            <div class="ambient-glow blob-1"></div>
            <div class="ambient-glow blob-2"></div>

            <?php if ($venueStatus !== 'approved'): ?>
                <div class="pending-banner glass">
                    <?php esc_html_e('Your venue is pending verification. You will be notified once approved.', 'havato'); ?>
                </div>
            <?php endif; ?>

            <div class="havato-main-content">
                <div id="cafe-owner-content"></div>
            </div>

            <!-- Bottom Navigation -->
            <nav class="havato-bottom-nav">
                <button class="nav-item active" data-tab="dashboard">📊 Dashboard</button>
                <button class="nav-item" data-tab="events">📅 Events</button>
                <button class="nav-item" data-tab="menu">🍽️ Menu</button>
                <button class="nav-item" data-tab="venue">🏠 Venue</button>
            </nav>
        </div>

        <script>
            document.addEventListener('DOMContentLoaded', function() {
                if (window.HavatoCafeOwner) window.HavatoCafeOwner.init();
            });
        </script>
        <?php
        return ob_get_clean();
    }
}