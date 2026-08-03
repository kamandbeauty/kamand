<?php
/**
 * Google Gemini provider.
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

final class GeminiProvider extends AbstractProvider {
    public function generate(GenerationRequest $request): GenerationResponse {
        if (! $this->is_configured()) {
            throw new \RuntimeException(__('Provider API key is not configured.', 'aiseo-content-studio'));
        }

        $contents           = array();
        $system_instruction = '';

        foreach ($this->messages($request) as $message) {
            if ('system' === $message['role']) {
                $system_instruction .= ('' === $system_instruction ? '' : "\n\n") . $message['content'];
                continue;
            }

            $contents[] = array(
                'role'  => 'assistant' === $message['role'] ? 'model' : 'user',
                'parts' => array(array('text' => $message['content'])),
            );
        }

        $body = array(
            'contents'         => $contents,
            'generationConfig' => array(
                'temperature'     => $request->temperature(),
                'topP'            => $request->top_p(),
                'maxOutputTokens' => $request->max_tokens(),
            ),
        );

        if ('' !== $system_instruction) {
            $body['systemInstruction'] = array('parts' => array(array('text' => $system_instruction)));
        }

        if ($request->wants_json()) {
            $body['generationConfig']['responseMimeType'] = 'application/json';
        }

        $endpoint = str_replace('{model}', rawurlencode($this->model($request)), (string) ($this->config['endpoint_path'] ?? '/models/{model}:generateContent'));
        $url      = add_query_arg('key', rawurlencode($this->api_key()), $this->url($endpoint));
        $result   = $this->post_json($url, $body, array());
        $json     = $result['json'];
        $content  = '';

        if (! empty($json['candidates'][0]['content']['parts']) && is_array($json['candidates'][0]['content']['parts'])) {
            foreach ($json['candidates'][0]['content']['parts'] as $part) {
                if (is_array($part) && isset($part['text'])) {
                    $content .= (string) $part['text'];
                }
            }
        }

        if ('' === trim($content)) {
            throw new \RuntimeException(__('Gemini returned an empty response.', 'aiseo-content-studio'));
        }

        $usage = array();
        if (isset($json['usageMetadata']) && is_array($json['usageMetadata'])) {
            $usage = array(
                'prompt_tokens'     => (int) ($json['usageMetadata']['promptTokenCount'] ?? 0),
                'completion_tokens' => (int) ($json['usageMetadata']['candidatesTokenCount'] ?? 0),
                'total_tokens'      => (int) ($json['usageMetadata']['totalTokenCount'] ?? 0),
            );
        }

        return new GenerationResponse(
            $content,
            $json,
            $usage,
            array(
                'status_code'      => $result['status'],
                'response_time_ms' => $result['response_time_ms'],
                'endpoint'         => remove_query_arg('key', $result['url']),
            )
        );
    }
}
