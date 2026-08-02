<?php namespace AISEO\AI; abstract class AI_Provider { abstract public function generate(string $prompt, array $opts): array; abstract public function get_name(): string; }
