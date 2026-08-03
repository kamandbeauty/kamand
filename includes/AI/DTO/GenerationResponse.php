<?php
/**
 * AI generation response DTO.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\AI\DTO;

if (! defined('ABSPATH')) {
    exit;
}

final class GenerationResponse {
    private string $content;
    /** @var array<string,mixed> */
    private array $raw;
    /** @var array<string,mixed> */
    private array $usage;
    /** @var array<string,mixed> */
    private array $meta;

    /**
     * @param array<string,mixed> $raw Raw provider payload.
     * @param array<string,mixed> $usage Token usage payload.
     * @param array<string,mixed> $meta Meta payload.
     */
    public function __construct(string $content, array $raw = array(), array $usage = array(), array $meta = array()) {
        $this->content = $content;
        $this->raw     = $raw;
        $this->usage   = $usage;
        $this->meta    = $meta;
    }

    public function content(): string {
        return $this->content;
    }

    /** @return array<string,mixed> */
    public function raw(): array {
        return $this->raw;
    }

    /** @return array<string,mixed> */
    public function usage(): array {
        return $this->usage;
    }

    /** @return array<string,mixed> */
    public function meta(): array {
        return $this->meta;
    }

    /** @return array<string,mixed> */
    public function to_array(): array {
        return array(
            'content' => $this->content,
            'raw'     => $this->raw,
            'usage'   => $this->usage,
            'meta'    => $this->meta,
        );
    }
}
