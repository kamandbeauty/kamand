<?php
/**
 * Base HTTP provider.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\AI\Providers;

use AISEOContentStudio\AI\DTO\GenerationRequest;
use AISEOContentStudio\Contracts\ProviderInterface;
use AISEOContentStudio\Helpers\Crypto;

if (! defined('ABSPATH')) {
    exit;
}

abstract class AbstractProvider implements ProviderInterface {
    /** @var array<string,mixed> */
    protected array $config;

    /**
     * @param array<string,mixed> $config Provider configuration.
     */
    public function __construct(array $config) {
        $this->config = $config;
    }

    public function slug(): string {
        return sanitize_key((string) ($this->config['slug'] ?? ''));
    }

    public function label(): string {
        return sanitize_text_field((string) ($this->config['name'] ?? $this->slug()));
    }

    public function default_model(): string {
        return sanitize_text_field((string) ($this->config['default_model'] ?? ''));
    }

    public function is_configured(): bool {
        return '' !== $this->api_key() || 'ollama' === $this->slug();
    }

    /**
     * Returns decrypted API key.
     */
    protected function api_key(): string {
        return Crypto::decrypt(isset($this->config['api_key_encrypted']) ? (string) $this->config['api_key_encrypted'] : '');
    }

    /**
     * Resolves a model from request and provider defaults.
     */
    protected function model(GenerationRequest $request): string {
        return $request->model() ?: $this->default_model();
    }

    /**
     * Builds a full URL from base and endpoint.
     *
     * @param string $path Endpoint path.
     */
    protected function url(string $path): string {
        $base = rtrim((string) ($this->config['base_url'] ?? ''), '/');
        $path = '/' . ltrim($path, '/');
        return $base . $path;
    }

    /**
     * Sends a JSON request.
     *
     * @param string              $url URL.
     * @param array<string,mixed> $body Body.
     * @param array<string,string> $headers Headers.
     * @return array{json:array<string,mixed>,status:int,response_time_ms:int,url:string}
     */
    protected function post_json(string $url, array $body, array $headers): array {
        $started  = microtime(true);
        $response = wp_remote_post(
            $url,
            array(
                'timeout'     => 120,
                'redirection' => 3,
                'headers'     => array_merge(array('Content-Type' => 'application/json'), $headers),
                'body'        => wp_json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            )
        );
        $elapsed = (int) round((microtime(true) - $started) * 1000);

        if (is_wp_error($response)) {
            throw new \RuntimeException($response->get_error_message());
        }

        $status = (int) wp_remote_retrieve_response_code($response);
        $raw    = (string) wp_remote_retrieve_body($response);
        $json   = json_decode($raw, true);

        if ($status < 200 || $status >= 300) {
            $message = $this->error_message(is_array($json) ? $json : array(), $raw);
            throw new \RuntimeException(sprintf('%s (%d)', $message, $status));
        }

        if (! is_array($json)) {
            throw new \RuntimeException(__('The AI provider returned an invalid JSON response.', 'aiseo-content-studio'));
        }

        return array(
            'json'             => $json,
            'status'           => $status,
            'response_time_ms' => $elapsed,
            'url'              => $url,
        );
    }

    /**
     * Extracts provider error message.
     *
     * @param array<string,mixed> $json JSON.
     * @param string              $raw Raw body.
     */
    protected function error_message(array $json, string $raw): string {
        if (isset($json['error']['message'])) {
            return sanitize_text_field((string) $json['error']['message']);
        }
        if (isset($json['message'])) {
            return sanitize_text_field((string) $json['message']);
        }

        $message = wp_strip_all_tags($raw);
        return '' !== $message ? substr($message, 0, 300) : __('AI provider request failed.', 'aiseo-content-studio');
    }

    /**
     * Returns request messages with a standard system instruction.
     *
     * @return array<int,array{role:string,content:string}>
     */
    protected function messages(GenerationRequest $request): array {
        $messages = $request->messages();
        if (empty($messages) || 'system' !== $messages[0]['role']) {
            array_unshift(
                $messages,
                array(
                    'role'    => 'system',
                    'content' => __('You are an expert WordPress SEO writer, WooCommerce copywriter, schema specialist, Persian and English editor, and conversion strategist. Return accurate, safe, original, helpful content. Do not invent unavailable product facts; infer only when clearly reasonable and phrase uncertain details conservatively.', 'aiseo-content-studio'),
                )
            );
        }

        return $messages;
    }
}
