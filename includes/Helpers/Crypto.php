<?php
/**
 * Encryption helper for provider secrets.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Helpers;

if (! defined('ABSPATH')) {
    exit;
}

final class Crypto {
    /**
     * Encrypts a value with keys derived from WordPress salts.
     *
     * @param string $plain Plain text value.
     */
    public static function encrypt(string $plain): string {
        if ('' === $plain) {
            return '';
        }

        if (! function_exists('openssl_encrypt')) {
            return base64_encode($plain);
        }

        $iv     = random_bytes(16);
        $cipher = openssl_encrypt($plain, 'aes-256-cbc', self::key(), OPENSSL_RAW_DATA, $iv);

        if (false === $cipher) {
            return base64_encode($plain);
        }

        return 'enc:' . base64_encode($iv . $cipher);
    }

    /**
     * Decrypts an encrypted value.
     *
     * @param string|null $encrypted Encrypted text.
     */
    public static function decrypt(?string $encrypted): string {
        if (empty($encrypted)) {
            return '';
        }

        if (0 !== strpos($encrypted, 'enc:')) {
            $decoded = base64_decode($encrypted, true);
            return is_string($decoded) ? $decoded : $encrypted;
        }

        if (! function_exists('openssl_decrypt')) {
            return '';
        }

        $payload = base64_decode(substr($encrypted, 4), true);
        if (! is_string($payload) || strlen($payload) <= 16) {
            return '';
        }

        $iv     = substr($payload, 0, 16);
        $cipher = substr($payload, 16);
        $plain  = openssl_decrypt($cipher, 'aes-256-cbc', self::key(), OPENSSL_RAW_DATA, $iv);

        return is_string($plain) ? $plain : '';
    }

    /**
     * Builds the encryption key.
     */
    private static function key(): string {
        $salt = (defined('AUTH_KEY') ? AUTH_KEY : '') . (defined('SECURE_AUTH_SALT') ? SECURE_AUTH_SALT : '') . wp_salt('auth');
        return hash('sha256', $salt, true);
    }
}
