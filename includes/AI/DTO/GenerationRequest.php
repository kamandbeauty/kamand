<?php
/**
 * AI generation request DTO.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\AI\DTO;

use AISEOContentStudio\Helpers\Sanitizer;

if (! defined('ABSPATH')) {
    exit;
}

final class GenerationRequest {
    /** @var array<int,array{role:string,content:string}> */
    private array $messages;
    private string $prompt;
    private string $model;
    private string $language;
    private int $max_tokens;
    private float $temperature;
    private float $top_p;
    private float $presence_penalty;
    private float $frequency_penalty;
    private bool $json_response;
    /** @var array<string,mixed> */
    private array $options;

    /**
     * @param array<int,array{role:string,content:string}> $messages Messages.
     * @param array<string,mixed>                         $options Additional options.
     */
    public function __construct(
        array $messages,
        string $prompt,
        string $model,
        string $language,
        int $max_tokens,
        float $temperature,
        float $top_p,
        float $presence_penalty,
        float $frequency_penalty,
        bool $json_response = false,
        array $options = array()
    ) {
        $this->messages          = $messages;
        $this->prompt            = $prompt;
        $this->model             = $model;
        $this->language          = $language;
        $this->max_tokens        = $max_tokens;
        $this->temperature       = $temperature;
        $this->top_p             = $top_p;
        $this->presence_penalty  = $presence_penalty;
        $this->frequency_penalty = $frequency_penalty;
        $this->json_response     = $json_response;
        $this->options           = $options;
    }

    /**
     * Builds from an array.
     *
     * @param array<string,mixed> $data Raw request data.
     */
    public static function from_array(array $data): self {
        $prompt   = isset($data['prompt']) ? sanitize_textarea_field((string) $data['prompt']) : '';
        $model    = isset($data['model']) ? Sanitizer::model((string) $data['model']) : '';
        $language = isset($data['language']) ? sanitize_text_field((string) $data['language']) : get_locale();

        $messages = array();
        if (! empty($data['messages']) && is_array($data['messages'])) {
            foreach ($data['messages'] as $message) {
                if (! is_array($message)) {
                    continue;
                }
                $role    = isset($message['role']) ? sanitize_key((string) $message['role']) : 'user';
                $content = isset($message['content']) ? sanitize_textarea_field((string) $message['content']) : '';
                if ('' !== $content) {
                    $messages[] = array(
                        'role'    => in_array($role, array('system', 'user', 'assistant'), true) ? $role : 'user',
                        'content' => $content,
                    );
                }
            }
        }

        if (empty($messages) && '' !== $prompt) {
            $messages[] = array(
                'role'    => 'user',
                'content' => $prompt,
            );
        }

        return new self(
            $messages,
            $prompt,
            $model,
            $language,
            isset($data['max_tokens']) ? max(256, absint($data['max_tokens'])) : 4096,
            isset($data['temperature']) ? (float) min(2, max(0, (float) $data['temperature'])) : 0.7,
            isset($data['top_p']) ? (float) min(1, max(0, (float) $data['top_p'])) : 1.0,
            isset($data['presence_penalty']) ? (float) min(2, max(-2, (float) $data['presence_penalty'])) : 0.0,
            isset($data['frequency_penalty']) ? (float) min(2, max(-2, (float) $data['frequency_penalty'])) : 0.0,
            ! empty($data['json_response']),
            isset($data['options']) && is_array($data['options']) ? Sanitizer::recursive($data['options']) : array()
        );
    }

    /** @return array<int,array{role:string,content:string}> */
    public function messages(): array {
        return $this->messages;
    }

    public function prompt(): string {
        return $this->prompt;
    }

    public function model(): string {
        return $this->model;
    }

    public function language(): string {
        return $this->language;
    }

    public function max_tokens(): int {
        return $this->max_tokens;
    }

    public function temperature(): float {
        return $this->temperature;
    }

    public function top_p(): float {
        return $this->top_p;
    }

    public function presence_penalty(): float {
        return $this->presence_penalty;
    }

    public function frequency_penalty(): float {
        return $this->frequency_penalty;
    }

    public function wants_json(): bool {
        return $this->json_response;
    }

    /** @return array<string,mixed> */
    public function options(): array {
        return $this->options;
    }

    /** @return array<string,mixed> */
    public function to_array(): array {
        return array(
            'messages'          => $this->messages,
            'prompt'            => $this->prompt,
            'model'             => $this->model,
            'language'          => $this->language,
            'max_tokens'        => $this->max_tokens,
            'temperature'       => $this->temperature,
            'top_p'             => $this->top_p,
            'presence_penalty'  => $this->presence_penalty,
            'frequency_penalty' => $this->frequency_penalty,
            'json_response'     => $this->json_response,
            'options'           => $this->options,
        );
    }
}
