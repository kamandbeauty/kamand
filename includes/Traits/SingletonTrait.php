<?php
/**
 * Singleton trait.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Traits;

if (! defined('ABSPATH')) {
    exit;
}

trait SingletonTrait {
    /**
     * Shared instance.
     *
     * @var static|null
     */
    protected static $instance = null;

    /**
     * Returns the shared instance.
     *
     * @return static
     */
    public static function instance() {
        if (null === static::$instance) {
            static::$instance = new static();
        }

        return static::$instance;
    }

    /**
     * Prevents direct construction from outside the class.
     */
    protected function __construct() {}

    /**
     * Prevents cloning.
     */
    final protected function __clone() {}

    /**
     * Prevents unserialization.
     */
    final public function __wakeup(): void {
        _doing_it_wrong(__METHOD__, esc_html__('Singleton instances cannot be unserialized.', 'aiseo-content-studio'), '1.0.0');
    }
}
