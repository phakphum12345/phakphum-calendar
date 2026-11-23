<?php

namespace Tests\Feature;

use Tests\TestCase;

class HealthApiTest extends TestCase
{
    public function test_liveness_returns_service_status_and_request_id(): void
    {
        $response = $this->withHeader('X-Request-ID', 'test-request-123')
            ->getJson('/api/v1/health');

        $response
            ->assertOk()
            ->assertHeader('X-Request-ID', 'test-request-123')
            ->assertJson([
                'status' => 'ok',
                'request_id' => 'test-request-123',
            ]);
    }

    public function test_invalid_request_id_is_replaced_with_a_generated_id(): void
    {
        $response = $this->withHeader('X-Request-ID', 'bad')
            ->getJson('/api/v1/health');

        $requestId = $response->headers->get('X-Request-ID');

        $response
            ->assertOk()
            ->assertJsonPath('request_id', $requestId);

        $this->assertNotSame('bad', $requestId);
        $this->assertMatchesRegularExpression('/^[0-9a-f-]{36}$/', (string) $requestId);
    }

    public function test_readiness_checks_the_database(): void
    {
        $this->getJson('/api/v1/ready')
            ->assertOk()
            ->assertJsonPath('status', 'ready')
            ->assertJsonPath('checks.database', 'ok');
    }
}
