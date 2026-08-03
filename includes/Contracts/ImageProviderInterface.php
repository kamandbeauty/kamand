<?php
/**
 * Image provider contract.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Contracts;

if (! defined('ABSPATH')) {
    exit;
}

interface ImageProviderInterface {
    /**
     * Generates an image and returns provider payload with a url or base64 field.
     *
     * @param string              $prompt Image prompt.
     * @param array<string,mixed> $args Generation arguments.
     * @return array<string,mixed>
     */
    public function generate_image(string $prompt, array $args = array()): array;
}
