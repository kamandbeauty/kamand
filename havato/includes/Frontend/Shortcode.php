<?php

declare(strict_types=1);

namespace Havato\Frontend;

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Renders the main Havato Progressive Web App via shortcode [havato_app]
 */
final class Shortcode
{
    public function render(): string
    {
        if (!is_user_logged_in()) {
            return $this->renderAuthWall();
        }

        ob_start();
        ?>
        <div id="havato-app" class="havato-app">
            <!-- Ambient Glow Blobs -->
            <div class="ambient-glow blob-1"></div>
            <div class="ambient-glow blob-2"></div>
            <div class="ambient-glow blob-3"></div>

            <!-- Main Content Area -->
            <div class="havato-main-content">
                <!-- Dynamic Tab Content will be injected here via JS -->
                <div id="havato-tab-content" class="havato-tab-content"></div>
            </div>

            <!-- Fixed Bottom Navigation -->
            <nav class="havato-bottom-nav">
                <button class="nav-item active" data-tab="explore">
                    <span class="icon">🔍</span>
                    <span class="label"><?php esc_html_e('Explore', 'havato'); ?></span>
                </button>
                <button class="nav-item" data-tab="map">
                    <span class="icon">🗺️</span>
                    <span class="label"><?php esc_html_e('Map', 'havato'); ?></span>
                </button>
                <button class="nav-item" data-tab="chats">
                    <span class="icon">💬</span>
                    <span class="label"><?php esc_html_e('Chats', 'havato'); ?></span>
                </button>
                <button class="nav-item" data-tab="profile">
                    <span class="icon">👤</span>
                    <span class="label"><?php esc_html_e('Profile', 'havato'); ?></span>
                </button>
            </nav>
        </div>

        <script>
            // Minimal inline boot to prevent FOUC
            document.addEventListener('DOMContentLoaded', function() {
                if (typeof window.HavatoApp !== 'undefined') {
                    window.HavatoApp.init();
                }
            });
        </script>
        <?php
        return ob_get_clean();
    }

    private function renderAuthWall(): string
    {
        ob_start();
        ?>
        <div class="havato-auth-wall">
            <div class="auth-container">
                <div class="auth-logo">
                    <h1>Havato</h1>
                    <p class="tagline"><?php esc_html_e('Connect over coffee', 'havato'); ?></p>
                </div>

                <div class="auth-actions">
                    <!-- Google Sign-In Button -->
                    <a href="<?php echo esc_url(\Havato\Auth\GoogleOAuth::getAuthorizationUrl()); ?>" class="btn btn-google glass">
                        <span class="google-icon">G</span>
                        <?php esc_html_e('Continue with Google', 'havato'); ?>
                    </a>

                    <div class="auth-divider">
                        <span><?php esc_html_e('or', 'havato'); ?></span>
                    </div>

                    <div class="cafe-owner-actions">
                        <a href="<?php echo esc_url(wp_login_url()); ?>" class="btn btn-outline glass">
                            <?php esc_html_e('Cafe Owner Login', 'havato'); ?>
                        </a>
                        <a href="<?php echo esc_url(wp_registration_url()); ?>" class="btn btn-outline glass">
                            <?php esc_html_e('Cafe Registration', 'havato'); ?>
                        </a>
                    </div>
                </div>
            </div>
        </div>
        <?php
        return ob_get_clean();
    }
}