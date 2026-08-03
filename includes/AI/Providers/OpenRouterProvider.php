<?php
/**
 * OpenRouter provider.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\AI\Providers;

if (! defined('ABSPATH')) {
    exit;
}

final class OpenRouterProvider extends OpenAICompatibleProvider {
    /**
     * Adds OpenRouter attribution headers.
     *
     * @return array<string,string>
     */
    protected function headers(): array {
        $headers = parent::headers();
        $headers['HTTP-Referer'] = home_url('/');
        $headers['X-Title']      = get_bloginfo('name');
        return $headers;
    }
}
