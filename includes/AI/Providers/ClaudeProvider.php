<?php
/**
 * Anthropic Claude provider.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\AI\Providers;

use AISEOContentStudio\AI\DTO\GenerationRequest;
use AISEOContentStudio\AI\DTO\GenerationResponse;

if (! defined('ABSPATH')) {
    exit;
}

final class ClaudeProvider extends AbstractProvider {
    public function generate(GenerationRequest $request): GenerationResponse {
        if (! $this->is_configured()) {
            throw new \RuntimeException(__('Provider API key is not configured.', 'aiseo-content-studio'));
        }

        $system   = '';
        $messages = array();
        foreach ($this->messages($request) as $message) {
            if ('system' === $message['role']) {
                $system .= ('' === $system ? '' : "\n\n") . $message['content'];
                continue;
            }

            $messages[] = array(
                'role'    => 'assistant' === $message['role'] ? 'assistant' : 'user',
                'content' => $message['content'],
            );
        }

        $body = array(
            'model'       => $this->model($request),
            'max_tokens'  => $request->max_tokens(),
            'temperature' => $request->temperature(),
            'top_p'       => $request->top_p(),
            'system'      => $system,
            'messages'    => $messages,
        );

        $result = $this->post_json(
            $this->url((string) ($this->config['endpoint_path'] ?? '/messages')),
            $body,
            array(
                'x-api-key'         => $this->api_key(),
                'anthropic-version' => '2023-06-01',
            )
        );

        $json    = $result['json'];
        $content = '';
        if (! empty($json['content']) && is_array($json['content'])) {
            foreach ($json['content'] as $part) {
                if (is_array($part) && isset($part['text'])) {
                    $content .= (string) $part['text'];
                }
            }
        }

        if ('' === trim($content)) {
            throw new \RuntimeException(__('Claude returned an empty response.', 'aiseo-content-studio'));
        }

        return new GenerationResponse(
            $content,
            $json,
            isset($json['usage']) && is_array($json['usage']) ? array(
                'prompt_tokens'     => (int) ($json['usage']['input_tokens'] ?? 0),
                'completion_tokens' => (int) ($json['usage']['output_tokens'] ?? 0),
                'total_tokens'      => (int) ($json['usage']['input_tokens'] ?? 0) + (int) ($json['usage']['output_tokens'] ?? 0),
            ) : array(),
            array(
                'status_code'      => $result['status'],
                'response_time_ms' => $result['response_time_ms'],
                'endpoint'         => $result['url'],
            )
        );
    }
}
