<?php
/**
 * Export service.
 *
 * @package AISEOContentStudio
 */

declare(strict_types=1);

namespace AISEOContentStudio\Services;

use AISEOContentStudio\Repositories\HistoryRepository;
use AISEOContentStudio\Repositories\PromptRepository;

if (! defined('ABSPATH')) {
    exit;
}

final class ExportService {
    /**
     * Exports history.
     *
     * @param string              $format Format.
     * @param array<string,mixed> $args Query args.
     * @return array{filename:string,content_type:string,body:string}
     */
    public function history(string $format, array $args = array()): array {
        $rows = (new HistoryRepository())->all(wp_parse_args($args, array('limit' => 200)));
        return $this->render($rows, $format, 'history');
    }

    /**
     * Exports prompts.
     *
     * @param string $format Format.
     * @return array{filename:string,content_type:string,body:string}
     */
    public function prompts(string $format): array {
        $rows = (new PromptRepository())->all(array('limit' => 200));
        return $this->render($rows, $format, 'prompts');
    }

    /**
     * Renders rows in a format.
     *
     * @param array<int,array<string,mixed>> $rows Rows.
     * @param string                         $format Format.
     * @param string                         $name Base name.
     * @return array{filename:string,content_type:string,body:string}
     */
    private function render(array $rows, string $format, string $name): array {
        $format = sanitize_key($format);
        $date   = gmdate('Y-m-d');

        return match ($format) {
            'csv'  => array('filename' => "aiseocs-{$name}-{$date}.csv", 'content_type' => 'text/csv; charset=utf-8', 'body' => $this->csv($rows)),
            'txt'  => array('filename' => "aiseocs-{$name}-{$date}.txt", 'content_type' => 'text/plain; charset=utf-8', 'body' => $this->txt($rows)),
            'pdf'  => array('filename' => "aiseocs-{$name}-{$date}.pdf", 'content_type' => 'application/pdf', 'body' => $this->pdf($rows, "AI SEO Content Studio {$name}")),
            default => array('filename' => "aiseocs-{$name}-{$date}.json", 'content_type' => 'application/json; charset=utf-8', 'body' => wp_json_encode($rows, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)),
        };
    }

    /**
     * CSV renderer.
     *
     * @param array<int,array<string,mixed>> $rows Rows.
     */
    private function csv(array $rows): string {
        $stream = fopen('php://temp', 'r+');
        if (false === $stream) {
            return '';
        }

        if (! empty($rows)) {
            fputcsv($stream, array_keys($rows[0]));
        }

        foreach ($rows as $row) {
            $line = array();
            foreach ($row as $value) {
                $line[] = is_array($value) ? wp_json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) : (string) $value;
            }
            fputcsv($stream, $line);
        }

        rewind($stream);
        $content = stream_get_contents($stream);
        fclose($stream);

        return is_string($content) ? "\xEF\xBB\xBF" . $content : '';
    }

    /**
     * TXT renderer.
     *
     * @param array<int,array<string,mixed>> $rows Rows.
     */
    private function txt(array $rows): string {
        $chunks = array();
        foreach ($rows as $row) {
            $chunks[] = wp_json_encode($row, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }

        return implode("\n\n---\n\n", array_filter($chunks));
    }

    /**
     * Minimal PDF renderer for administrative archives.
     *
     * @param array<int,array<string,mixed>> $rows Rows.
     * @param string                         $title Title.
     */
    private function pdf(array $rows, string $title): string {
        $text = $title . "\n\n" . wp_strip_all_tags($this->txt($rows));
        $text = preg_replace('/[^\x09\x0A\x0D\x20-\x7E]/', '?', (string) $text);
        $lines = array_slice(preg_split('/\R/', (string) $text) ?: array(), 0, 60);

        $content = "BT /F1 11 Tf 50 780 Td 14 TL ";
        foreach ($lines as $line) {
            $line = substr($line, 0, 95);
            $line = str_replace(array('\\', '(', ')'), array('\\\\', '\\(', '\\)'), $line);
            $content .= '(' . $line . ') Tj T* ';
        }
        $content .= 'ET';

        $objects = array(
            '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj',
            '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj',
            '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj',
            '4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj',
            '5 0 obj << /Length ' . strlen($content) . ' >> stream' . "\n" . $content . "\nendstream endobj",
        );

        $pdf = "%PDF-1.4\n";
        $xref = array(0);
        foreach ($objects as $object) {
            $xref[] = strlen($pdf);
            $pdf .= $object . "\n";
        }
        $start = strlen($pdf);
        $pdf .= "xref\n0 " . (count($objects) + 1) . "\n0000000000 65535 f \n";
        for ($i = 1; $i <= count($objects); $i++) {
            $pdf .= sprintf("%010d 00000 n \n", $xref[$i]);
        }
        $pdf .= "trailer << /Size " . (count($objects) + 1) . " /Root 1 0 R >>\nstartxref\n{$start}\n%%EOF";

        return $pdf;
    }
}
