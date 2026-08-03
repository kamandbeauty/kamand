<?php
/**
 * High-level AI orchestration.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\AI;

use AISEOContentStudio\AI\DTO\GenerationRequest;
use AISEOContentStudio\Helpers\Sanitizer;
use AISEOContentStudio\Helpers\Text;
use AISEOContentStudio\Repositories\CacheRepository;
use AISEOContentStudio\Repositories\HistoryRepository;
use AISEOContentStudio\Repositories\LogRepository;
use AISEOContentStudio\Repositories\ProviderRepository;
use AISEOContentStudio\Services\CostEstimator;
use AISEOContentStudio\Services\SettingsService;

if (! defined('ABSPATH')) {
    exit;
}

final class AIService {
    private SettingsService $settings;
    private ProviderRepository $providers;
    private ProviderFactory $factory;
    private PromptBuilder $prompts;
    private CacheRepository $cache;
    private HistoryRepository $history;
    private LogRepository $logs;
    private CostEstimator $costs;

    public function __construct() {
        $this->settings  = new SettingsService();
        $this->providers = new ProviderRepository();
        $this->factory   = new ProviderFactory($this->providers);
        $this->prompts   = new PromptBuilder();
        $this->cache     = new CacheRepository();
        $this->history   = new HistoryRepository();
        $this->logs      = new LogRepository();
        $this->costs     = new CostEstimator();
    }

    /**
     * Generates general content.
     *
     * @param array<string,mixed> $data Raw request data.
     * @param array<string,mixed> $context Context for history.
     * @return array<string,mixed>
     */
    public function generate(array $data, array $context = array()): array {
        $settings = $this->settings->all();
        $data     = wp_parse_args($data, array(
            'provider'          => $settings['default_provider'],
            'model'             => $settings['default_model'],
            'language'          => $settings['language'],
            'tone'              => $settings['tone'],
            'writing_style'     => $settings['writing_style'],
            'length'            => $settings['length'],
            'temperature'       => $settings['temperature'],
            'top_p'             => $settings['top_p'],
            'presence_penalty'  => $settings['presence_penalty'],
            'frequency_penalty' => $settings['frequency_penalty'],
            'max_tokens'        => $settings['max_tokens'],
            'feature'           => 'blog_post',
        ));

        if (empty($data['prompt'])) {
            $data['prompt'] = $this->prompts->build($data);
        } else {
            $data['prompt'] = sanitize_textarea_field((string) $data['prompt']);
        }

        return $this->run($data, $context);
    }

    /**
     * Generates WooCommerce product content.
     *
     * @param string              $feature Product feature.
     * @param array<string,mixed> $product_context Product context.
     * @param array<string,mixed> $args Extra args.
     * @return array<string,mixed>
     */
    public function generate_product(string $feature, array $product_context, array $args = array()): array {
        $settings = $this->settings->all();
        $feature  = sanitize_key($feature);
        $args     = wp_parse_args($args, array(
            'provider'          => $settings['default_provider'],
            'model'             => $settings['default_model'],
            'language'          => $settings['language'],
            'tone'              => $settings['tone'],
            'writing_style'     => $settings['writing_style'],
            'temperature'       => $settings['temperature'],
            'top_p'             => $settings['top_p'],
            'presence_penalty'  => $settings['presence_penalty'],
            'frequency_penalty' => $settings['frequency_penalty'],
            'max_tokens'        => 'product_bundle' === $feature || 'seo_description' === $feature ? 12000 : $settings['max_tokens'],
            'json_response'     => in_array($feature, array('product_bundle', 'rewrite_product', 'focus_keywords', 'schema', 'image_alt', 'image_title', 'image_caption', 'image_description', 'product_tags'), true),
            'feature'           => $feature,
        ));

        $args['prompt'] = $this->prompts->product($feature, $product_context, $args);

        return $this->run(
            $args,
            array(
                'object_type' => 'product',
                'object_id'   => absint($product_context['id'] ?? 0),
                'feature'     => $feature,
            )
        );
    }

    /**
     * Sends a chat request.
     *
     * @param array<int,array{role:string,content:string}> $messages Messages.
     * @param array<string,mixed>                          $args Args.
     * @return array<string,mixed>
     */
    public function chat(array $messages, array $args = array()): array {
        $settings = $this->settings->all();
        $args     = wp_parse_args($args, array(
            'provider'          => $settings['default_provider'],
            'model'             => $settings['default_model'],
            'language'          => $settings['language'],
            'temperature'       => $settings['temperature'],
            'top_p'             => $settings['top_p'],
            'presence_penalty'  => $settings['presence_penalty'],
            'frequency_penalty' => $settings['frequency_penalty'],
            'max_tokens'        => $settings['max_tokens'],
            'feature'           => 'chat',
        ));
        $args['messages'] = $messages;
        $args['prompt']   = implode("\n", array_map(static fn($message) => ($message['role'] ?? 'user') . ': ' . ($message['content'] ?? ''), $messages));

        return $this->run($args, array('object_type' => 'chat', 'feature' => 'chat'));
    }

    /**
     * Executes provider request with cache, logs and history.
     *
     * @param array<string,mixed> $data Request data.
     * @param array<string,mixed> $context History context.
     * @return array<string,mixed>
     */
    private function run(array $data, array $context): array {
        $provider_slug = sanitize_key((string) ($data['provider'] ?? ''));
        $provider_row  = '' !== $provider_slug ? $this->providers->find_by_slug($provider_slug) : $this->providers->default();

        if (! $provider_row) {
            throw new \RuntimeException(__('Selected provider does not exist.', 'aiseo-content-studio'));
        }

        $model = ! empty($data['model']) ? Sanitizer::model((string) $data['model']) : sanitize_text_field((string) ($provider_row['default_model'] ?? ''));
        $data['model'] = $model;
        $provider      = $this->factory->from_config($provider_row);
        $request       = GenerationRequest::from_array($data);
        $request_hash  = Text::hash($request->to_array() + array('provider' => $provider->slug()));
        $cache_key     = Text::hash(array('provider' => $provider->slug(), 'request' => $request->to_array()));
        $settings      = $this->settings->all();

        if (! empty($settings['cache_enabled'])) {
            $cached = $this->cache->get($cache_key);
            if ($cached) {
                $cached['cached'] = true;
                return $cached;
            }
        }

        try {
            $response = $provider->generate($request);
            $usage    = $this->normalize_usage($response->usage());
            $cost     = $this->costs->estimate($model, $usage);
            $parsed   = Text::extract_json($response->content());
            $result   = array(
                'content'      => $response->content(),
                'parsed'       => $parsed,
                'provider'     => $provider->slug(),
                'model'        => $model,
                'usage'        => $usage,
                'cost'         => $cost,
                'meta'         => $response->meta(),
                'cached'       => false,
                'history_id'   => 0,
            );

            $history_id = $this->history->create(
                array(
                    'object_type'     => $context['object_type'] ?? 'content',
                    'object_id'       => $context['object_id'] ?? 0,
                    'feature'         => $context['feature'] ?? ($data['feature'] ?? ''),
                    'provider'        => $provider->slug(),
                    'model'           => $model,
                    'prompt_hash'     => $request_hash,
                    'prompt'          => $request->prompt(),
                    'request'         => $request->to_array(),
                    'response'        => $response->content(),
                    'parsed_response' => $parsed,
                    'status'          => 'success',
                )
            );
            $result['history_id'] = $history_id;

            $meta = $response->meta();
            $this->logs->create(
                array(
                    'provider'          => $provider->slug(),
                    'model'             => $model,
                    'endpoint'          => (string) ($meta['endpoint'] ?? ''),
                    'prompt_tokens'     => $usage['prompt_tokens'],
                    'completion_tokens' => $usage['completion_tokens'],
                    'total_tokens'      => $usage['total_tokens'],
                    'estimated_cost'    => $cost,
                    'response_time_ms'  => (int) ($meta['response_time_ms'] ?? 0),
                    'status_code'       => (int) ($meta['status_code'] ?? 200),
                    'status'            => 'success',
                    'request_hash'      => $request_hash,
                )
            );

            if (! empty($settings['cache_enabled'])) {
                $this->cache->set($cache_key, $provider->slug(), $model, $result, $usage, (int) $settings['cache_ttl']);
            }

            return $result;
        } catch (\Throwable $exception) {
            $this->logs->create(
                array(
                    'provider'      => $provider->slug(),
                    'model'         => $model,
                    'status'        => 'error',
                    'error_message' => $exception->getMessage(),
                    'request_hash'  => $request_hash,
                )
            );

            throw $exception;
        }
    }

    /**
     * Normalizes provider usage shape.
     *
     * @param array<string,mixed> $usage Usage.
     * @return array{prompt_tokens:int,completion_tokens:int,total_tokens:int}
     */
    private function normalize_usage(array $usage): array {
        $prompt     = (int) ($usage['prompt_tokens'] ?? $usage['input_tokens'] ?? 0);
        $completion = (int) ($usage['completion_tokens'] ?? $usage['output_tokens'] ?? 0);
        $total      = (int) ($usage['total_tokens'] ?? ($prompt + $completion));

        return array(
            'prompt_tokens'     => $prompt,
            'completion_tokens' => $completion,
            'total_tokens'      => $total,
        );
    }
}
