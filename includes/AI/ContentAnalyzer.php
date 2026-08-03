<?php
/**
 * Lightweight SEO analyzer.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\AI;

use AISEOContentStudio\Helpers\Text;

if (! defined('ABSPATH')) {
    exit;
}

final class ContentAnalyzer {
    /**
     * Scores generated content using deterministic SEO/readability checks.
     *
     * @param string              $content Content.
     * @param array<string,mixed> $context Context.
     * @return array{score:int,improvements:array<int,string>}
     */
    public function score(string $content, array $context = array()): array {
        $plain        = trim(wp_strip_all_tags($content));
        $word_count   = str_word_count($plain);
        $heading_hits = preg_match_all('/<h[2-4][^>]*>/i', $content);
        $score        = 35;
        $improvements = array();

        if ($word_count >= 1200) {
            $score += 20;
        } elseif ($word_count >= 600) {
            $score += 12;
            $improvements[] = __('Increase depth to cover buyer questions, comparisons, specifications, and use cases.', 'aiseo-content-studio');
        } else {
            $improvements[] = __('Content is thin. Add more original details, benefits, specifications, FAQ, and buying guidance.', 'aiseo-content-studio');
        }

        if ($heading_hits >= 6) {
            $score += 12;
        } else {
            $improvements[] = __('Use more semantic headings to improve scannability and SEO structure.', 'aiseo-content-studio');
        }

        if (false !== stripos($content, 'faq') || $this->contains($content, 'سوال')) {
            $score += 8;
        } else {
            $improvements[] = __('Add a practical FAQ section to capture long-tail questions.', 'aiseo-content-studio');
        }

        if (false !== stripos($content, '<table') || $this->contains($content, 'مشخصات')) {
            $score += 8;
        } else {
            $improvements[] = __('Add a specification table or clearly formatted attributes.', 'aiseo-content-studio');
        }

        $title = Text::readable($context['title'] ?? '');
        if ('' !== $title && $this->contains($plain, $title)) {
            $score += 7;
        }

        if (false !== stripos($content, 'schema') || false !== stripos($content, 'application/ld+json')) {
            $score += 5;
        }

        if ($this->has_cta($plain)) {
            $score += 5;
        } else {
            $improvements[] = __('Add a clear call to action that matches buyer intent.', 'aiseo-content-studio');
        }

        return array(
            'score'        => min(100, $score),
            'improvements' => array_values(array_unique($improvements)),
        );
    }

    /**
     * Checks for CTA phrases in Persian and English.
     *
     * @param string $plain Plain text.
     */
    private function has_cta(string $plain): bool {
        $phrases = array('buy', 'order', 'shop', 'contact', 'خرید', 'سفارش', 'همین حالا', 'سبد خرید', 'تماس');
        foreach ($phrases as $phrase) {
            if ($this->contains($plain, $phrase)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Case-insensitive containment that works without mbstring.
     *
     * @param string $haystack Haystack.
     * @param string $needle Needle.
     */
    private function contains(string $haystack, string $needle): bool {
        if ('' === $needle) {
            return true;
        }

        if (function_exists('mb_stripos')) {
            return false !== mb_stripos($haystack, $needle);
        }

        return false !== stripos($haystack, $needle);
    }
}
