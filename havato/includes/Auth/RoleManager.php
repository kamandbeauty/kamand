<?php

declare(strict_types=1);

namespace Havato\Auth;

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Handles custom user roles and admin user list columns for Havato.
 */
final class RoleManager
{
    /**
     * Register custom Havato roles.
     */
    public function registerRoles(): void
    {
        // Gatherer (customer) role
        if (!get_role('gatherer')) {
            add_role('gatherer', __('Gatherer', 'havato'), [
                'read'                   => true,
                'edit_posts'             => false,
                'delete_posts'           => false,
                'upload_files'           => true,
                'havato_view_events'     => true,
                'havato_join_events'     => true,
                'havato_chat'            => true,
            ]);
        }

        // Cafe Owner role
        if (!get_role('cafe_owner')) {
            add_role('cafe_owner', __('Cafe Owner', 'havato'), [
                'read'                        => true,
                'edit_posts'                  => false,
                'delete_posts'                => false,
                'upload_files'                => true,
                'havato_manage_venue'         => true,
                'havato_create_events'        => true,
                'havato_manage_menu'          => true,
                'havato_view_registrations'   => true,
            ]);
        }
    }

    /**
     * Add custom columns to Users admin table.
     *
     * @param array<string, string> $columns
     * @return array<string, string>
     */
    public function addUserColumns(array $columns): array
    {
        $columns['havato_role']   = __('Havato Role', 'havato');
        $columns['cafe_status']   = __('Cafe Status', 'havato');
        return $columns;
    }

    /**
     * Render content for custom user columns.
     *
     * @param string $output      Column output
     * @param string $columnName  Column name
     * @param int    $userId      User ID
     * @return string
     */
    public function renderUserColumn(string $output, string $columnName, int $userId): string
    {
        $user = get_userdata($userId);
        if (!$user) {
            return $output;
        }

        switch ($columnName) {
            case 'havato_role':
                $roles = array_intersect($user->roles, ['gatherer', 'cafe_owner', 'administrator']);
                if (!empty($roles)) {
                    $roleLabels = [
                        'gatherer'    => __('Gatherer', 'havato'),
                        'cafe_owner'  => __('Cafe Owner', 'havato'),
                        'administrator' => __('Administrator', 'havato'),
                    ];
                    $displayRoles = array_map(static fn($role) => $roleLabels[$role] ?? ucfirst($role), $roles);
                    return esc_html(implode(', ', $displayRoles));
                }
                return esc_html__('None', 'havato');

            case 'cafe_status':
                if (in_array('cafe_owner', $user->roles, true)) {
                    $venueStatus = get_user_meta($userId, 'havato_venue_status', true);
                    $status = $venueStatus ?: 'pending';
                    $labels = [
                        'approved' => __('Approved', 'havato'),
                        'pending'  => __('Pending Verification', 'havato'),
                        'rejected' => __('Rejected', 'havato'),
                    ];
                    $label = $labels[$status] ?? ucfirst($status);
                    $class = $status === 'approved' ? 'approved' : ($status === 'rejected' ? 'rejected' : 'pending');
                    return sprintf(
                        '<span class="havato-status-badge %s">%s</span>',
                        esc_attr($class),
                        esc_html($label)
                    );
                }
                return '—';
        }

        return $output;
    }

    /**
     * Add filters for Havato Role and Cafe Status in Users admin.
     */
    public function addUserFilters(): void
    {
        global $pagenow;

        if ($pagenow !== 'users.php') {
            return;
        }

        // Havato Role filter
        $selectedRole = sanitize_text_field($_GET['havato_role'] ?? '');
        ?>
        <select name="havato_role" class="havato-filter-select">
            <option value=""><?php esc_html_e('All Havato Roles', 'havato'); ?></option>
            <option value="gatherer" <?php selected($selectedRole, 'gatherer'); ?>><?php esc_html_e('Gatherer', 'havato'); ?></option>
            <option value="cafe_owner" <?php selected($selectedRole, 'cafe_owner'); ?>><?php esc_html_e('Cafe Owner', 'havato'); ?></option>
        </select>
        <?php

        // Cafe Status filter (only visible when cafe_owner role is selected or always)
        $selectedStatus = sanitize_text_field($_GET['cafe_status'] ?? '');
        ?>
        <select name="cafe_status" class="havato-filter-select">
            <option value=""><?php esc_html_e('All Cafe Statuses', 'havato'); ?></option>
            <option value="approved" <?php selected($selectedStatus, 'approved'); ?>><?php esc_html_e('Approved', 'havato'); ?></option>
            <option value="pending" <?php selected($selectedStatus, 'pending'); ?>><?php esc_html_e('Pending Verification', 'havato'); ?></option>
            <option value="rejected" <?php selected($selectedStatus, 'rejected'); ?>><?php esc_html_e('Rejected', 'havato'); ?></option>
        </select>
        <?php
    }

    /**
     * Modify user query based on custom filters.
     *
     * @param \WP_User_Query $query
     */
    public function filterUsers(\WP_User_Query $query): void
    {
        global $pagenow;

        if ($pagenow !== 'users.php' || !is_admin()) {
            return;
        }

        $roleFilter = sanitize_text_field($_GET['havato_role'] ?? '');
        if ($roleFilter && in_array($roleFilter, ['gatherer', 'cafe_owner'], true)) {
            $query->set('role', $roleFilter);
        }

        $statusFilter = sanitize_text_field($_GET['cafe_status'] ?? '');
        if ($statusFilter) {
            $metaQuery = $query->get('meta_query') ?: [];
            $metaQuery[] = [
                'key'     => 'havato_venue_status',
                'value'   => $statusFilter,
                'compare' => '=',
            ];
            $query->set('meta_query', $metaQuery);
        }
    }
}