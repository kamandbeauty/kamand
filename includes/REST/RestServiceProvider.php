<?php
/**
 * REST route provider.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\REST;

use AISEOContentStudio\REST\Controllers\ExportController;
use AISEOContentStudio\REST\Controllers\GenerationController;
use AISEOContentStudio\REST\Controllers\HistoryController;
use AISEOContentStudio\REST\Controllers\ProductController;
use AISEOContentStudio\REST\Controllers\PromptController;
use AISEOContentStudio\REST\Controllers\QueueController;
use AISEOContentStudio\REST\Controllers\SettingsController;

if (! defined('ABSPATH')) {
    exit;
}

final class RestServiceProvider {
    public const NAMESPACE = 'aiseocs/v1';

    /**
     * Registers hooks.
     */
    public function hooks(): void {
        add_action('rest_api_init', array($this, 'routes'));
    }

    /**
     * Registers routes.
     */
    public function routes(): void {
        (new SettingsController())->register();
        (new GenerationController())->register();
        (new ProductController())->register();
        (new PromptController())->register();
        (new HistoryController())->register();
        (new QueueController())->register();
        (new ExportController())->register();
    }
}
