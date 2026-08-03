<?php
/**
 * Cost estimation service.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Services;

if (! defined('ABSPATH')) {
    exit;
}

final class CostEstimator {
    /**
     * Approximate USD prices per one million tokens.
     *
     * @var array<string,array{input:float,output:float}>
     */
    private array $prices = array(
        'gpt-4o-mini'                => array('input' => 0.15, 'output' => 0.60),
        'gpt-4o'                     => array('input' => 5.00, 'output' => 15.00),
        'gpt-4.1-mini'               => array('input' => 0.40, 'output' => 1.60),
        'gemini-1.5-flash'           => array('input' => 0.35, 'output' => 1.05),
        'gemini-1.5-pro'             => array('input' => 3.50, 'output' => 10.50),
        'claude-3-5-sonnet-latest'   => array('input' => 3.00, 'output' => 15.00),
        'claude-3-5-haiku-latest'    => array('input' => 0.80, 'output' => 4.00),
        'deepseek-chat'              => array('input' => 0.14, 'output' => 0.28),
        'deepseek-reasoner'          => array('input' => 0.55, 'output' => 2.19),
        'llama-3.1-70b-versatile'    => array('input' => 0.59, 'output' => 0.79),
        'llama-3.1-8b-instant'       => array('input' => 0.05, 'output' => 0.08),
    );

    /**
     * Estimates request cost.
     *
     * @param string              $model Model identifier.
     * @param array<string,mixed> $usage Usage data.
     */
    public function estimate(string $model, array $usage): float {
        $normalized = $this->normalize_model($model);
        if (! isset($this->prices[$normalized])) {
            return 0.0;
        }

        $prompt     = (int) ($usage['prompt_tokens'] ?? $usage['input_tokens'] ?? 0);
        $completion = (int) ($usage['completion_tokens'] ?? $usage['output_tokens'] ?? 0);
        $price      = $this->prices[$normalized];

        return round((($prompt / 1000000) * $price['input']) + (($completion / 1000000) * $price['output']), 8);
    }

    /**
     * Normalizes routing prefixes such as openrouter models.
     *
     * @param string $model Model.
     */
    private function normalize_model(string $model): string {
        $model = strtolower($model);
        if (str_contains($model, '/')) {
            $parts = explode('/', $model);
            $model = (string) end($parts);
        }

        return $model;
    }
}
