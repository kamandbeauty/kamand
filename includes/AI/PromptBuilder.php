<?php
/**
 * Prompt construction service.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\AI;

use AISEOContentStudio\Helpers\Text;

if (! defined('ABSPATH')) {
    exit;
}

final class PromptBuilder {
    /**
     * Builds a general content prompt.
     *
     * @param array<string,mixed> $args Request args.
     */
    public function build(array $args): string {
        $feature  = sanitize_key((string) ($args['feature'] ?? 'blog_post'));
        $topic    = sanitize_textarea_field((string) ($args['topic'] ?? $args['prompt'] ?? ''));
        $language = sanitize_text_field((string) ($args['language'] ?? get_locale()));
        $tone     = sanitize_text_field((string) ($args['tone'] ?? 'professional'));
        $style    = sanitize_text_field((string) ($args['writing_style'] ?? 'seo_editorial'));
        $length   = sanitize_text_field((string) ($args['length'] ?? 'medium'));
        $keywords = Text::readable($args['keywords'] ?? '');
        $audience = sanitize_text_field((string) ($args['audience'] ?? __('target customers', 'aiseo-content-studio')));
        $source   = sanitize_textarea_field((string) ($args['source_text'] ?? $args['text'] ?? $args['topic'] ?? ''));

        $base = sprintf(
            "Language: %s\nTone: %s\nWriting style: %s\nLength: %s\nAudience: %s\nSEO keywords: %s\n\n",
            $language,
            $tone,
            $style,
            $length,
            '' !== $audience ? $audience : __('target customers', 'aiseo-content-studio'),
            '' !== $keywords ? $keywords : __('natural semantic keywords only', 'aiseo-content-studio')
        );

        $map = array(
            'blog_post'          => 'Write a complete, original SEO blog post with an engaging title, introduction, hierarchical headings, practical examples, FAQ, conclusion, and meta title/meta description suggestions.',
            'page'               => 'Write polished website page copy with a clear value proposition, scannable sections, credibility signals, and a conversion-focused call to action.',
            'category'           => 'Write SEO category archive content with a natural introduction, buying guidance, internal-linking suggestions, and FAQ suitable for a WordPress category page.',
            'tag'                => 'Write concise SEO tag archive content that explains the topic, helps users discover related content, and avoids thin-content patterns.',
            'seo_content'        => 'Create SEO-optimized content that satisfies search intent, covers entities and semantically related subtopics, and remains human-readable without keyword stuffing.',
            'faq'                => 'Create an FAQ section with clear questions and expert answers. Include JSON-LD FAQPage schema as valid JSON after the readable FAQ.',
            'how_to'             => 'Write a complete how-to guide with prerequisites, tools, numbered steps, warnings, tips, FAQ, and HowTo schema-ready structured data.',
            'product_review'     => 'Write a balanced product review with experience-based evaluation, features, benefits, drawbacks, ideal buyers, alternatives, verdict, and FAQ.',
            'comparison_article' => 'Write a comparison article with a decision matrix, similarities, differences, pros and cons, recommendation by use case, and FAQ.',
            'news'               => 'Write a news-style article with a factual headline, summary lead, context, implications, expert perspective, and neutral tone.',
            'landing_page'       => 'Write conversion-focused landing page copy with hero section, problem, solution, benefits, proof, objections, FAQ, and repeated calls to action.',
            'rewrite'            => 'Rewrite the provided text to improve clarity, flow, structure, originality, and brand voice while preserving meaning and facts.',
            'summarize'          => 'Summarize the provided text into the requested length with the most important points, decisions, and action items.',
            'expand'             => 'Expand the provided text with useful detail, examples, context, transitions, and SEO-friendly subtopics while preserving the original meaning.',
            'shorten'            => 'Shorten the provided text while preserving the core message, facts, tone, and conversion intent.',
            'translate'          => 'Translate the provided text into the requested language with native fluency, correct idioms, and localized wording.',
            'grammar'            => 'Improve grammar, punctuation, readability, rhythm, and professional tone without changing meaning.',
            'humanize'           => 'Humanize the provided AI-like text so it sounds natural, specific, warm, expert, and free from repetitive robotic phrasing.',
            'remove_ai_tone'     => 'Remove generic AI tone from the provided text. Replace empty claims with concrete, useful, human wording while preserving factual accuracy.',
        );

        $instruction = $map[$feature] ?? $map['blog_post'];

        if (in_array($feature, array('rewrite', 'summarize', 'expand', 'shorten', 'translate', 'grammar', 'humanize', 'remove_ai_tone'), true)) {
            return $base . $instruction . "\n\nSource text:\n" . $source;
        }

        return $base . $instruction . "\n\nTopic or brief:\n" . $topic;
    }

    /**
     * Builds a WooCommerce product prompt.
     *
     * @param string              $feature Product feature.
     * @param array<string,mixed> $context Product context.
     * @param array<string,mixed> $args Extra args.
     */
    public function product(string $feature, array $context, array $args = array()): string {
        $language = sanitize_text_field((string) ($args['language'] ?? 'fa_IR'));
        $tone     = sanitize_text_field((string) ($args['tone'] ?? 'professional'));
        $style    = sanitize_text_field((string) ($args['writing_style'] ?? 'seo_editorial'));
        $keywords = Text::readable($args['keywords'] ?? '');

        $context_text = $this->product_context_text($context);
        $shared       = "You are creating WooCommerce product content.\n"
            . "Output language: {$language}.\n"
            . "Tone: {$tone}. Writing style: {$style}.\n"
            . "Use natural, human, conversion-oriented SEO. Optimize for Google, AI search engines, Rank Math, Yoast, All in One SEO, and SEOPress without keyword stuffing.\n"
            . "When Persian is requested, write fluent natural Persian with correct half-spaces and shopping-friendly phrasing.\n"
            . "Use only product facts from context when factual precision is required. You may infer customer-facing benefits from the category, title, attributes, and price, but avoid false claims.\n"
            . ('' !== $keywords ? "Requested keywords: {$keywords}.\n" : '')
            . "\nProduct context:\n{$context_text}\n\n";

        $instructions = array(
            'seo_description'    => 'Generate a premium SEO WooCommerce product description of at least 1500 words, structured with HTML headings and sections: Introduction, Features, Advantages, Specifications, Who should buy, How to use, Why choose this product, Buying Guide, FAQ, Conclusion, and CTA. Keep it readable and persuasive.',
            'short_description'  => 'Generate a persuasive WooCommerce short description between 150 and 300 words, SEO optimized and suitable for the product excerpt field. Use clean HTML paragraphs and bullet points when helpful.',
            'seo_title'          => 'Generate one perfect SEO title with a maximum of 60 characters. Return only the title.',
            'meta_description'   => 'Generate one compelling meta description with a maximum of 155 characters. Return only the meta description.',
            'focus_keywords'     => 'Generate focus keywords grouped as Primary Keyword, Secondary Keywords, Long Tail Keywords, and LSI Keywords. Return a compact JSON object with keys primary, secondary, long_tail, lsi.',
            'product_slug'       => 'Generate one SEO-friendly lowercase product slug in Latin characters with hyphens only. Return only the slug.',
            'product_excerpt'    => 'Generate a short product excerpt of 40 to 70 words that is persuasive and SEO friendly.',
            'benefits'           => 'Generate a concise bullet list of product benefits focused on customer outcomes.',
            'features'           => 'Generate a professional feature list based on the product context.',
            'specifications'     => 'Generate an HTML specification table using known attributes and careful inferred labels only when useful.',
            'faq'                => 'Generate product FAQ with 6 to 10 questions and answers. Also include schema-ready JSON-LD FAQPage as valid JSON after the readable FAQ.',
            'pros_cons'          => 'Generate a professional pros and cons section with balanced, purchase-helpful wording.',
            'schema'             => 'Generate a valid JSON-LD Product schema object using only available context. Include name, description, sku, image, brand when available, offers with price/currency when available, and aggregateRating only if present in context.',
            'image_alt'          => 'Generate SEO ALT text for every product image in context. Return JSON array of objects with attachment_id and alt.',
            'image_title'        => 'Generate SEO image titles for every product image in context. Return JSON array of objects with attachment_id and title.',
            'image_caption'      => 'Generate useful image captions for every product image in context. Return JSON array of objects with attachment_id and caption.',
            'image_description'  => 'Generate media-library image descriptions for every product image in context. Return JSON array of objects with attachment_id and description.',
            'social_captions'    => 'Generate social media captions for Instagram, Telegram, WhatsApp, Facebook, LinkedIn, and Twitter/X. Include hashtags where appropriate and adapt each platform style.',
            'marketing_text'     => 'Generate marketing copy for Google Ads, Instagram Ads, SMS, Push Notification, and Email Marketing. Keep each channel concise and compliant.',
            'product_tags'       => 'Generate WooCommerce product tags as a JSON array of clean, useful tag names.',
            'product_naming'     => 'Generate 10 better product title options that are SEO-friendly, clear, and persuasive.',
            'internal_links'     => 'Suggest internal link opportunities. Return anchor text ideas and target page/product topics based on the product context.',
            'related_products'   => 'Suggest related WooCommerce product types or names that would pair naturally with this product. Return a categorized list.',
            'seo_score'          => 'Analyze the existing and generated product content context. Give a score out of 100 and explain prioritized improvements for title, headings, entities, keyword coverage, readability, schema, images, and conversion.',
            'rewrite_product'    => 'Rewrite the existing product long description and short description into a stronger WooCommerce SEO version. Return valid JSON with keys seo_description_html and short_description_html. Preserve accurate product facts, improve persuasion, structure, and readability.',
        );

        if ('product_bundle' === $feature) {
            return $shared . $this->bundle_instruction();
        }

        return $shared . ($instructions[$feature] ?? $instructions['seo_description']);
    }

    /**
     * Product bundle instruction for one-click generation.
     */
    private function bundle_instruction(): string {
        return 'Generate the complete WooCommerce SEO content package in one response. Return valid JSON only, with no markdown fences and no commentary. Use this exact object shape: '
            . '{"seo_description_html":"","short_description_html":"","seo_title":"","meta_description":"","focus_keywords":{"primary":"","secondary":[],"long_tail":[],"lsi":[]},"slug":"","excerpt":"","benefits":[],"features":[],"specifications":[{"label":"","value":""}],"faq":[{"question":"","answer":""}],"pros":[],"cons":[],"product_schema":{},"image_seo":[{"attachment_id":0,"alt":"","title":"","caption":"","description":""}],"social_captions":{"instagram":"","telegram":"","whatsapp":"","facebook":"","linkedin":"","twitter_x":""},"marketing_text":{"google_ads":"","instagram_ads":"","sms":"","push_notification":"","email_marketing":""},"product_tags":[],"improved_titles":[],"internal_links":[{"anchor":"","target":"","reason":""}],"related_products":[{"title":"","reason":""}],"seo_score":{"score":0,"improvements":[]}}. '
            . 'The seo_description_html must be at least 1500 words and include Introduction, Features, Advantages, Specifications, Who should buy, How to use, Why choose this product, Buying Guide, FAQ, Conclusion, and CTA as semantic HTML headings. Short description must be 150-300 words. SEO title max 60 characters. Meta description max 155 characters. Product slug must be lowercase Latin hyphenated text. FAQ answers must be schema-ready. Product schema must be a valid JSON-LD Product object.';
    }

    /**
     * Builds readable product context.
     *
     * @param array<string,mixed> $context Product context.
     */
    private function product_context_text(array $context): string {
        $lines = array();
        foreach ($context as $key => $value) {
            if (in_array($key, array('raw_meta'), true)) {
                continue;
            }
            $label = ucwords(str_replace('_', ' ', sanitize_key((string) $key)));
            if (is_array($value)) {
                $lines[] = $label . ': ' . wp_json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
            } else {
                $lines[] = $label . ': ' . Text::readable($value);
            }
        }

        return implode("\n", $lines);
    }
}
