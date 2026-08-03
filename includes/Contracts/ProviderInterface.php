<?php
/**
 * Provider contract.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Contracts;

use AISEOContentStudio\AI\DTO\GenerationRequest;
use AISEOContentStudio\AI\DTO\GenerationResponse;

if (! defined('ABSPATH')) {
    exit;
}

interface ProviderInterface {
    public function slug(): string;

    public function label(): string;

    public function is_configured(): bool;

    public function default_model(): string;

    /**
     * Generates text content.
     *
     * @throws \RuntimeException When the provider returns an invalid response.
     */
    public function generate(GenerationRequest $request): GenerationResponse;
}
