<?php
/**
 * PSR-4 style autoloader for the plugin namespace.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio;

if (! defined('ABSPATH')) {
    exit;
}

final class Autoloader {
    /**
     * Registers the autoloader.
     */
    public static function register(): void {
        spl_autoload_register(array(__CLASS__, 'autoload'));
    }

    /**
     * Loads a class from the includes directory.
     *
     * @param string $class Fully qualified class name.
     */
    public static function autoload(string $class): void {
        $prefix = __NAMESPACE__ . '\\';

        if (0 !== strpos($class, $prefix)) {
            return;
        }

        $relative = substr($class, strlen($prefix));
        $relative = str_replace('\\', DIRECTORY_SEPARATOR, $relative);
        $file     = AISEOCS_PATH . 'includes/' . $relative . '.php';

        if (is_readable($file)) {
            require_once $file;
        }
    }
}
