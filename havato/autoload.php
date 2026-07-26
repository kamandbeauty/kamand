<?php
/**
 * PSR-4 Autoloader fallback for Havato
 */

spl_autoload_register(function (string $class): void {
    $prefix = 'Havato\\';
    $baseDir = __DIR__ . '/includes/';

    if (strncmp($prefix, $class, strlen($prefix)) !== 0) {
        return;
    }

    $relativeClass = substr($class, strlen($prefix));
    $file = $baseDir . str_replace('\\', '/', $relativeClass) . '.php';

    if (file_exists($file)) {
        require $file;
    }
});