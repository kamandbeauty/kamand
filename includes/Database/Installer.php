<?php
/**
 * Activation, deactivation, migrations, and seed data.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Database;

use AISEOContentStudio\Repositories\ProviderRepository;
use AISEOContentStudio\Repositories\PromptRepository;

if (! defined('ABSPATH')) {
    exit;
}

final class Installer {
    public const OPTION_VERSION = 'aiseocs_db_version';
    public const CRON_HOOK      = 'aiseocs_process_queue';

    /**
     * Runs activation tasks.
     */
    public static function activate(): void {
        self::create_tables();
        self::seed_providers();
        self::seed_prompts();
        update_option(self::OPTION_VERSION, Schema::VERSION, false);
        self::schedule_cron();
    }

    /**
     * Runs deactivation tasks.
     */
    public static function deactivate(): void {
        wp_clear_scheduled_hook(self::CRON_HOOK);
        wp_clear_scheduled_hook('aiseocs_daily_maintenance');
    }

    /**
     * Upgrades the database when plugin files are newer than the stored schema.
     */
    public static function maybe_upgrade(): void {
        $installed = (string) get_option(self::OPTION_VERSION, '0');
        if (version_compare($installed, Schema::VERSION, '<')) {
            self::create_tables();
            self::seed_providers();
            self::seed_prompts();
            update_option(self::OPTION_VERSION, Schema::VERSION, false);
        }

        self::schedule_cron();
    }

    /**
     * Creates or updates plugin tables.
     */
    public static function create_tables(): void {
        require_once ABSPATH . 'wp-admin/includes/upgrade.php';

        foreach (Schema::statements() as $statement) {
            dbDelta($statement);
        }
    }

    /**
     * Schedules queue processing.
     */
    public static function schedule_cron(): void {
        add_filter(
            'cron_schedules',
            static function (array $schedules): array {
                $schedules['aiseocs_every_minute'] = array(
                    'interval' => MINUTE_IN_SECONDS,
                    'display'  => __('Every Minute', 'aiseo-content-studio'),
                );
                return $schedules;
            }
        );

        if (! wp_next_scheduled(self::CRON_HOOK)) {
            wp_schedule_event(time() + MINUTE_IN_SECONDS, 'aiseocs_every_minute', self::CRON_HOOK);
        }
    }

    /**
     * Seeds the built-in AI providers.
     */
    private static function seed_providers(): void {
        $repository = new ProviderRepository();
        $providers  = array(
            array(
                'name'                => 'OpenAI',
                'slug'                => 'openai',
                'type'                => 'openai',
                'base_url'            => 'https://api.openai.com/v1',
                'endpoint_path'       => '/chat/completions',
                'image_endpoint_path' => '/images/generations',
                'default_model'       => 'gpt-4o-mini',
                'models'              => array('gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini', 'gpt-4.1'),
                'is_default'          => 1,
            ),
            array(
                'name'                => 'Google Gemini',
                'slug'                => 'gemini',
                'type'                => 'gemini',
                'base_url'            => 'https://generativelanguage.googleapis.com/v1beta',
                'endpoint_path'       => '/models/{model}:generateContent',
                'image_endpoint_path' => '',
                'default_model'       => 'gemini-1.5-flash',
                'models'              => array('gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-2.0-flash'),
                'is_default'          => 0,
            ),
            array(
                'name'                => 'Anthropic Claude',
                'slug'                => 'claude',
                'type'                => 'claude',
                'base_url'            => 'https://api.anthropic.com/v1',
                'endpoint_path'       => '/messages',
                'image_endpoint_path' => '',
                'default_model'       => 'claude-3-5-sonnet-latest',
                'models'              => array('claude-3-5-sonnet-latest', 'claude-3-5-haiku-latest', 'claude-3-opus-latest'),
                'is_default'          => 0,
            ),
            array(
                'name'                => 'DeepSeek',
                'slug'                => 'deepseek',
                'type'                => 'deepseek',
                'base_url'            => 'https://api.deepseek.com/v1',
                'endpoint_path'       => '/chat/completions',
                'image_endpoint_path' => '',
                'default_model'       => 'deepseek-chat',
                'models'              => array('deepseek-chat', 'deepseek-reasoner'),
                'is_default'          => 0,
            ),
            array(
                'name'                => 'OpenRouter',
                'slug'                => 'openrouter',
                'type'                => 'openrouter',
                'base_url'            => 'https://openrouter.ai/api/v1',
                'endpoint_path'       => '/chat/completions',
                'image_endpoint_path' => '',
                'default_model'       => 'openai/gpt-4o-mini',
                'models'              => array('openai/gpt-4o-mini', 'anthropic/claude-3.5-sonnet', 'google/gemini-flash-1.5'),
                'is_default'          => 0,
                'headers'             => array('HTTP-Referer' => home_url('/'), 'X-Title' => get_bloginfo('name')),
            ),
            array(
                'name'                => 'Groq',
                'slug'                => 'groq',
                'type'                => 'groq',
                'base_url'            => 'https://api.groq.com/openai/v1',
                'endpoint_path'       => '/chat/completions',
                'image_endpoint_path' => '',
                'default_model'       => 'llama-3.1-70b-versatile',
                'models'              => array('llama-3.1-70b-versatile', 'llama-3.1-8b-instant', 'mixtral-8x7b-32768'),
                'is_default'          => 0,
            ),
            array(
                'name'                => 'Ollama Local AI',
                'slug'                => 'ollama',
                'type'                => 'ollama',
                'base_url'            => 'http://localhost:11434/api',
                'endpoint_path'       => '/chat',
                'image_endpoint_path' => '',
                'default_model'       => 'llama3.1',
                'models'              => array('llama3.1', 'mistral', 'qwen2.5'),
                'is_default'          => 0,
            ),
        );

        foreach ($providers as $provider) {
            if (! $repository->find_by_slug((string) $provider['slug'])) {
                $repository->create($provider);
            }
        }
    }

    /**
     * Seeds useful default prompts.
     */
    private static function seed_prompts(): void {
        $repository = new PromptRepository();
        if ($repository->count() > 0) {
            return;
        }

        $defaults = array(
            array(
                'title'    => __('Persian SEO Product Description', 'aiseo-content-studio'),
                'slug'     => 'persian-seo-product-description',
                'category' => 'woocommerce',
                'language' => 'fa_IR',
                'content'  => 'برای محصول {{title}} یک توضیح محصول فارسی، انسانی، ساختارمند، مناسب ووکامرس و بهینه برای گوگل، رنک مث و یواست بنویس. از تیترها، مزایا، مشخصات، راهنمای خرید، سوالات متداول و دعوت به خرید استفاده کن.',
            ),
            array(
                'title'    => __('English Landing Page', 'aiseo-content-studio'),
                'slug'     => 'english-landing-page',
                'category' => 'marketing',
                'language' => 'en_US',
                'content'  => 'Write a conversion-focused landing page for {{topic}} with a compelling hero, benefits, proof, objections, FAQ, and a clear call to action.',
            ),
            array(
                'title'    => __('AI Humanizer', 'aiseo-content-studio'),
                'slug'     => 'ai-humanizer',
                'category' => 'rewrite',
                'language' => '',
                'content'  => 'Rewrite this text so it sounds natural, expert, human, and brand-safe while preserving facts and intent: {{text}}',
            ),
        );

        foreach ($defaults as $prompt) {
            $repository->create($prompt);
        }
    }
}
