<?php
/**
 * Ollama local AI provider.
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

final class OllamaProvider extends AbstractProvider {
    public function is_configured(): bool {
        return '' !== (string) ($this->config['base_url'] ?? '');
    }

    public function generate(GenerationRequest $request): GenerationResponse {
        $body = array(
            'model'    => $this->model($request),
            'messages' => $this->messages($request),
            'stream'   => false,
            'options'  => array(
                'temperature'       => $request->temperature(),
                'top_p'             => $request->top_p(),
                'presence_penalty'  => $request->presence_penalty(),
                'frequency_penalty' => $request->frequency_penalty(),
                'num_predict'       => $request->max_tokens(),
            ),
        );

        $result  = $this->post_json($this->url((string) ($this->config['endpoint_path'] ?? '/chat')), $body, array());
        $json    = $result['json'];
        $content = (string) ($json['message']['content'] ?? $json['response'] ?? '');

        if ('' === trim($content)) {
            throw new \RuntimeException(__('Ollama returned an empty response.', 'aiseo-content-studio'));
        }

        $prompt_tokens     = (int) ($json['prompt_eval_count'] ?? 0);
        $completion_tokens = (int) ($json['eval_count'] ?? 0);

        return new GenerationResponse(
            $content,
            $json,
            array(
                'prompt_tokens'     => $prompt_tokens,
                'completion_tokens' => $completion_tokens,
                'total_tokens'      => $prompt_tokens + $completion_tokens,
            ),
            array(
                'status_code'      => $result['status'],
                'response_time_ms' => $result['response_time_ms'],
                'endpoint'         => $result['url'],
            )
        );
    }
}
