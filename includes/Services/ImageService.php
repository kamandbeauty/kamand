<?php
/**
 * AI image service.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Services;

use AISEOContentStudio\AI\ProviderFactory;
use AISEOContentStudio\Contracts\ImageProviderInterface;
use AISEOContentStudio\Helpers\Sanitizer;
use AISEOContentStudio\Repositories\LogRepository;

if (! defined('ABSPATH')) {
    exit;
}

final class ImageService {
    private ProviderFactory $factory;
    private LogRepository $logs;

    public function __construct() {
        $this->factory = new ProviderFactory();
        $this->logs    = new LogRepository();
    }

    /**
     * Generates and stores an image in the media library.
     *
     * @param string              $prompt Image prompt.
     * @param array<string,mixed> $args Args.
     * @return array<string,mixed>
     */
    public function generate(string $prompt, array $args = array()): array {
        if (! current_user_can('upload_files')) {
            throw new \RuntimeException(__('You do not have permission to upload files.', 'aiseo-content-studio'));
        }

        $provider = $this->factory->make(sanitize_key((string) ($args['provider'] ?? '')));
        if (! $provider instanceof ImageProviderInterface) {
            throw new \RuntimeException(__('Selected provider cannot generate images.', 'aiseo-content-studio'));
        }

        $payload = $provider->generate_image($prompt, Sanitizer::recursive($args));
        $data    = isset($payload['data']) && is_array($payload['data']) ? $payload['data'] : array();
        $file    = '';

        if (! empty($data['b64_json'])) {
            $file = $this->save_base64((string) $data['b64_json'], ! empty($args['transparent']) ? 'png' : 'png');
        } elseif (! empty($data['url'])) {
            $file = $this->download((string) $data['url']);
        }

        if ('' === $file || ! file_exists($file)) {
            throw new \RuntimeException(__('Unable to save the generated image.', 'aiseo-content-studio'));
        }

        $attachment_id = $this->insert_attachment($file, sanitize_text_field((string) ($args['title'] ?? __('AI generated image', 'aiseo-content-studio'))), $prompt);

        $this->logs->create(
            array(
                'provider'         => $provider->slug(),
                'model'            => sanitize_text_field((string) ($args['model'] ?? 'image')),
                'endpoint'         => (string) ($payload['endpoint'] ?? ''),
                'response_time_ms' => (int) ($payload['response_time_ms'] ?? 0),
                'status_code'      => (int) ($payload['status_code'] ?? 200),
                'status'           => 'success',
            )
        );

        return array(
            'attachment_id' => $attachment_id,
            'url'           => wp_get_attachment_url($attachment_id),
            'provider'      => $provider->slug(),
            'meta'          => $payload,
        );
    }

    /**
     * Saves base64 image data.
     *
     * @param string $base64 Image base64.
     * @param string $extension File extension.
     */
    private function save_base64(string $base64, string $extension): string {
        $binary = base64_decode($base64, true);
        if (! is_string($binary)) {
            return '';
        }

        $filename = 'aiseocs-image-' . gmdate('Ymd-His') . '-' . wp_generate_password(8, false, false) . '.' . sanitize_key($extension);
        $upload   = wp_upload_bits($filename, null, $binary);

        if (! empty($upload['error'])) {
            return '';
        }

        return (string) $upload['file'];
    }

    /**
     * Downloads an image URL through WordPress HTTP APIs.
     *
     * @param string $url Image URL.
     */
    private function download(string $url): string {
        require_once ABSPATH . 'wp-admin/includes/file.php';

        $tmp = download_url(esc_url_raw($url), 120);
        if (is_wp_error($tmp)) {
            return '';
        }

        $uploads  = wp_upload_dir();
        $filename = 'aiseocs-image-' . gmdate('Ymd-His') . '-' . wp_generate_password(8, false, false) . '.png';
        $target   = trailingslashit((string) $uploads['path']) . $filename;

        if (! wp_mkdir_p((string) $uploads['path'])) {
            @unlink($tmp);
            return '';
        }

        if (! @rename($tmp, $target)) {
            @unlink($tmp);
            return '';
        }

        return $target;
    }

    /**
     * Inserts a media attachment.
     *
     * @param string $file File path.
     * @param string $title Title.
     * @param string $description Description.
     */
    private function insert_attachment(string $file, string $title, string $description): int {
        require_once ABSPATH . 'wp-admin/includes/image.php';

        $mime = wp_check_filetype(basename($file));
        $id   = wp_insert_attachment(
            array(
                'guid'           => $file,
                'post_mime_type' => $mime['type'] ?: 'image/png',
                'post_title'     => $title,
                'post_content'   => sanitize_textarea_field($description),
                'post_excerpt'   => $title,
                'post_status'    => 'inherit',
            ),
            $file
        );

        if (is_wp_error($id)) {
            throw new \RuntimeException($id->get_error_message());
        }

        $metadata = wp_generate_attachment_metadata((int) $id, $file);
        wp_update_attachment_metadata((int) $id, $metadata);
        update_post_meta((int) $id, '_wp_attachment_image_alt', $title);

        return (int) $id;
    }
}
