<?php

$allowedOrigins = array_filter(array_map(
    'trim',
    explode(
        ',',
        env(
            'FRONTEND_ALLOWED_ORIGINS',
            'http://localhost:8080,http://127.0.0.1:8080,https://phakphum12345.github.io',
        ),
    ),
));

return [
    'paths' => ['api/*'],
    'allowed_methods' => ['GET', 'POST', 'PUT', 'OPTIONS'],
    'allowed_origins' => array_values($allowedOrigins),
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['Accept', 'Authorization', 'Content-Type', 'X-Request-ID'],
    'exposed_headers' => ['X-Request-ID'],
    'max_age' => 600,
    'supports_credentials' => false,
];
