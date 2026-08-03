<?php
/**
 * Queue processing service.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Services;

use AISEOContentStudio\AI\AIService;
use AISEOContentStudio\Repositories\QueueRepository;
use AISEOContentStudio\WooCommerce\ProductContentApplier;
use AISEOContentStudio\WooCommerce\ProductContextBuilder;

if (! defined('ABSPATH')) {
    exit;
}

final class QueueService {
    private QueueRepository $queue;
    private SettingsService $settings;

    public function __construct() {
        $this->queue    = new QueueRepository();
        $this->settings = new SettingsService();
    }

    /**
     * Enqueues product generation tasks.
     *
     * @param array<int,int>      $product_ids Product IDs.
     * @param array<int,string>   $actions Actions.
     * @param array<string,mixed> $payload Payload.
     * @return array<int,int>
     */
    public function enqueue_products(array $product_ids, array $actions, array $payload = array()): array {
        $ids = array();
        foreach ($product_ids as $product_id) {
            $product_id = absint($product_id);
            if (! $product_id || ! current_user_can('edit_post', $product_id)) {
                continue;
            }

            foreach ($actions as $action) {
                $ids[] = $this->queue->enqueue(
                    array(
                        'job_type'    => 'product_generation',
                        'object_type' => 'product',
                        'object_id'   => $product_id,
                        'action'      => sanitize_key($action),
                        'payload'     => $payload,
                    )
                );
            }
        }

        return $ids;
    }

    /**
     * Processes pending jobs.
     *
     * @param int|null $limit Limit.
     * @return array<string,mixed>
     */
    public function process(?int $limit = null): array {
        $limit     = $limit ?: (int) $this->settings->get('queue_batch_size', 3);
        $jobs      = $this->queue->next($limit);
        $processed = 0;
        $failed    = 0;
        $results   = array();

        foreach ($jobs as $job) {
            $this->queue->mark_running((int) $job['id']);
            try {
                $result = $this->process_job($job);
                $this->queue->complete((int) $job['id'], $result);
                $results[] = $result;
                ++$processed;
            } catch (\Throwable $exception) {
                $this->queue->fail((int) $job['id'], $exception->getMessage());
                ++$failed;
            }
        }

        return array(
            'processed' => $processed,
            'failed'    => $failed,
            'results'   => $results,
        );
    }

    /**
     * Processes one job.
     *
     * @param array<string,mixed> $job Job.
     * @return array<string,mixed>
     */
    private function process_job(array $job): array {
        if ('product_generation' !== $job['job_type']) {
            throw new \RuntimeException(__('Unsupported queue job type.', 'aiseo-content-studio'));
        }

        $builder  = new ProductContextBuilder();
        $ai       = new AIService();
        $applier  = new ProductContentApplier();
        $context  = $builder->build((int) $job['object_id']);
        $payload  = is_array($job['payload']) ? $job['payload'] : array();
        $feature  = sanitize_key((string) $job['action']);
        $response = $ai->generate_product($feature, $context, $payload);
        $parsed   = is_array($response['parsed'] ?? null) ? $response['parsed'] : array();

        if (! empty($payload['apply']) && ! empty($parsed)) {
            $applier->apply((int) $job['object_id'], $parsed, isset($payload['fields']) && is_array($payload['fields']) ? $payload['fields'] : array());
        }

        return array(
            'product_id' => (int) $job['object_id'],
            'feature'    => $feature,
            'history_id' => (int) ($response['history_id'] ?? 0),
            'applied'    => ! empty($payload['apply']) && ! empty($parsed),
        );
    }
}
