<?php
/**
 * Provider factory.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\AI;

use AISEOContentStudio\AI\Providers\ClaudeProvider;
use AISEOContentStudio\AI\Providers\CustomProvider;
use AISEOContentStudio\AI\Providers\DeepSeekProvider;
use AISEOContentStudio\AI\Providers\GeminiProvider;
use AISEOContentStudio\AI\Providers\GroqProvider;
use AISEOContentStudio\AI\Providers\OllamaProvider;
use AISEOContentStudio\AI\Providers\OpenAIProvider;
use AISEOContentStudio\AI\Providers\OpenRouterProvider;
use AISEOContentStudio\Contracts\ProviderInterface;
use AISEOContentStudio\Repositories\ProviderRepository;

if (! defined('ABSPATH')) {
    exit;
}

final class ProviderFactory {
    private ProviderRepository $repository;

    public function __construct(?ProviderRepository $repository = null) {
        $this->repository = $repository ?: new ProviderRepository();
    }

    /**
     * Creates a provider by slug or returns default provider.
     *
     * @param string $slug Provider slug.
     */
    public function make(string $slug = ''): ProviderInterface {
        $config = '' !== $slug ? $this->repository->find_by_slug($slug) : $this->repository->default();
        if (! $config) {
            throw new \RuntimeException(__('No active AI provider is configured.', 'aiseo-content-studio'));
        }

        return $this->from_config($config);
    }

    /**
     * Creates from a provider configuration row.
     *
     * @param array<string,mixed> $config Config.
     */
    public function from_config(array $config): ProviderInterface {
        $type = sanitize_key((string) ($config['type'] ?? 'custom'));

        return match ($type) {
            'openai'     => new OpenAIProvider($config),
            'gemini'     => new GeminiProvider($config),
            'claude'     => new ClaudeProvider($config),
            'deepseek'   => new DeepSeekProvider($config),
            'openrouter' => new OpenRouterProvider($config),
            'groq'       => new GroqProvider($config),
            'ollama'     => new OllamaProvider($config),
            default      => new CustomProvider($config),
        };
    }
}
