<?php

namespace Tests\Feature;

use Tests\TestCase;

class ApiCorsTest extends TestCase
{

    public function test_browser_clients_can_read_the_request_correlation_response_header(): void
    {
        $origin = 'https://phakphum12345.github.io';
        $requestId = 'browser-correlation-123';

        $response = $this->withHeaders([
            'Origin' => $origin,
            'X-Request-ID' => $requestId,
        ])->getJson('/api/v1/me');

        $response
            ->assertUnauthorized()
            ->assertHeader('Access-Control-Allow-Origin', $origin)
            ->assertHeader('Access-Control-Expose-Headers', 'X-Request-ID')
            ->assertHeader('X-Request-ID', $requestId);
    }

    public function test_browser_preflight_allows_membership_patch_and_delete_requests(): void
    {
        $origin = 'https://phakphum12345.github.io';
        $path = '/api/v1/organizations/00000000-0000-4000-8000-000000000001/members/123';

        foreach (['PATCH', 'DELETE'] as $method) {
            $response = $this->withHeaders([
                'Origin' => $origin,
                'Access-Control-Request-Method' => $method,
                'Access-Control-Request-Headers' => 'authorization,content-type,x-request-id',
            ])->options($path);

            $response
                ->assertNoContent()
                ->assertHeader('Access-Control-Allow-Origin', $origin);

            $allowedMethods = array_map(
                'trim',
                explode(',', (string) $response->headers->get('Access-Control-Allow-Methods')),
            );
            $allowedHeaders = strtolower((string) $response->headers->get('Access-Control-Allow-Headers'));

            $this->assertContains($method, $allowedMethods);
            $this->assertStringContainsString('x-request-id', $allowedHeaders);
        }
    }
}
