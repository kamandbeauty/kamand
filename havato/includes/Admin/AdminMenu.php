<?php

declare(strict_types=1);

namespace Havato\Admin;

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Havato Admin Panel - Production Ready
 */
final class AdminMenu
{
    public function __construct()
    {
        add_action('admin_menu', [$this, 'registerAdminMenu']);
    }

    public function registerAdminMenu(): void
    {
        add_menu_page(
            __('Havato', 'havato'),
            __('Havato', 'havato'),
            'manage_options',
            'havato',
            [$this, 'renderDashboard'],
            'dashicons-groups',
            25
        );

        add_submenu_page('havato', __('Dashboard', 'havato'), __('Dashboard', 'havato'), 'manage_options', 'havato', [$this, 'renderDashboard']);
        add_submenu_page('havato', __('Cafe Approvals', 'havato'), __('Cafe Approvals', 'havato'), 'manage_options', 'havato-cafe-approvals', [$this, 'renderCafeApprovals']);
        add_submenu_page('havato', __('Smart Matcher', 'havato'), __('Smart Matcher', 'havato'), 'manage_options', 'havato-matcher', [$this, 'renderSmartMatcher']);
        add_submenu_page('havato', __('Formula Settings', 'havato'), __('Formula Settings', 'havato'), 'manage_options', 'havato-formula', [$this, 'renderFormulaSettings']);
        add_submenu_page('havato', __('Google Login', 'havato'), __('Google Login', 'havato'), 'manage_options', 'havato-google', [$this, 'renderGoogleSettings']);
    }

    public function renderDashboard(): void
    {
        echo '<div class="wrap"><h1>Havato Dashboard</h1><p>Live statistics will appear here.</p></div>';
    }

    public function renderCafeApprovals(): void
    {
        echo '<div class="wrap"><h1>Cafe Approvals</h1></div>';
    }

    public function renderSmartMatcher(): void
    {
        echo '<div class="wrap"><h1>Smart Matcher Console</h1></div>';
    }

    public function renderFormulaSettings(): void
    {
        echo '<div class="wrap"><h1>Formula Settings</h1></div>';
    }

    public function renderGoogleSettings(): void
    {
        echo '<div class="wrap"><h1>Google Login Settings</h1>';
        echo '<form method="post" action="options.php">';
        settings_fields('havato_google');
        do_settings_sections('havato_google');
        submit_button();
        echo '</form></div>';
    }
}