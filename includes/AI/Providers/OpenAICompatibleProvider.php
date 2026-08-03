<?php
/**
 * OpenAI-compatible provider.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\AI\Providers;

use AISEOContentStudio\AI\DTO\GenerationRequest;
use AISEOContentStudio\AI\DTO\GenerationResponse;
use AISEOContentStudio\Contracts\ImageProviderInterface;

if (! defined('ABSPATH')) {
    exit;
}

class OpenAICompatibleProvider extends AbstractProvider implements ImageProviderInterface {
    public function generate(GenerationRequest $request): GenerationResponse {
        if (! $this->is_configured()) {
            throw new \RuntimeException(__('Provider API key is not configured.', 'aiseo-content-studio'));
        }

        $endpoint = (string) ($this->config['endpoint_path'] ?? '/chat/completions');
        $body     = array(
            'model'             => $this->model($request),
            'messages'          => $this->messages($request),
            'temperature'       => $request->temperature(),
            'top_p'             => $request->top_p(),
            'presence_penalty'  => $request->presence_penalty(),
            'frequency_penalty' => $request->frequency_penalty(),
        );

        if ($request->max_tokens() > 0) {
            $body['max_tokens'] = $request->max_tokens();
        }

        if ($request->wants_json()) {
            $body['response_format'] = array('type' => 'json_object');
        }

        $result  = $this->post_json($this->url($endpoint), $body, $this->headers());
        $json    = $result['json'];
        $content = (string) ($json['choices'][0]['message']['content'] ?? $json['choices'][0]['text'] ?? '');

        if ('' === trim($content)) {
            throw new \RuntimeException(__('The AI provider returned an empty response.', 'aiseo-content-studio'));
        }

        return new GenerationResponse(
            $content,
            $json,
            isset($json['usage']) && is_array($json['usage']) ? $json['usage'] : array(),
            array(
                'status_code'       => $result['status'],
                'response_time_ms'  => $result['response_time_ms'],
                'endpoint'          => $result['url'],
            )
        );
    }

    /**
     * Generates an image.
     *
     * @param string              $prompt Prompt.
     * @param array<string,mixed> $args Args.
     * @return array<string,mixed>
     */
    public function generate_image(string $prompt, array $args = array()): array {
        if (! $this->is_configured()) {
            throw new \RuntimeException(__('Provider API key is not configured.', 'aiseo-content-studio'));
        }

        $endpoint = (string) ($this->config['image_endpoint_path'] ?? '');
        if ('' === $endpoint) {
            throw new \RuntimeException(__('This provider does not expose an image endpoint.', 'aiseo-content-studio'));
        }

        $body = array(
            'model'           => sanitize_text_field((string) ($args['model'] ?? 'gpt-image-1')),
            'prompt'          => sanitize_textarea_field($prompt),
            'size'            => sanitize_text_field((string) ($args['size'] ?? '1024x1024')),
            'n'               => max(1, min(4, absint($args['n'] ?? 1))),
            'response_format' => 'b64_json',
        );

        if (! empty($args['transparent'])) {
            $body['background'] = 'transparent';
        }

        $result = $this->post_json($this->url($endpoint), $body, $this->headers());
        $json   = $result['json'];
        $data   = isset($json['data'][0]) && is_array($json['data'][0]) ? $json['data'][0] : array();

        if (empty($data)) {
            throw new \RuntimeException(__('The image provider returned no image data.', 'aiseo-content-studio'));
        }

        return array(
            'data'             => $data,
            'raw'              => $json,
            'status_code'      => $result['status'],
            'response_time_ms' => $result['response_time_ms'],
            'endpoint'         => $result['url'],
        );
    }

    /**
     * Provider headers.
     *
     * @return array<string,string>
     */
    protected function headers(): array {
        $headers = array();
        $api_key = $this->api_key();
        if ('' !== $api_key) {
            $headers['Authorization'] = 'Bearer ' . $api_key;
        }

        if (! empty($this->config['headers']) && is_array($this->config['headers'])) {
            foreach ($this->config['headers'] as $key => $value) {
                $headers[sanitize_text_field((string) $key)] = sanitize_text_field((string) $value);
            }
        }

        return $headers;
    }
}
