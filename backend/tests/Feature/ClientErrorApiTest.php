<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Log;
use Tests\TestCase;

class ClientErrorApiTest extends TestCase
{
    public function test_valid_client_error_is_accepted_with_correlation_id(): void
    {
        $response = $this->withHeader('X-Request-ID', 'diagnostic-request-123')
            ->postJson('/api/v1/diagnostics/client-errors', [
                'error_code' => 'calendar.sync.failed',
                'category' => 'calendar',
                'message' => 'Provider returned a temporary failure.',
                'platform' => 'android',
                'app_version' => '4.1.0',
                'occurred_at' => '2026-07-26T10:00:00+07:00',
            ]);

        $response
            ->assertAccepted()
            ->assertHeader('X-Request-ID', 'diagnostic-request-123')
            ->assertJson([
                'status' => 'accepted',
                'request_id' => 'diagnostic-request-123',
            ]);
    }

    public function test_client_message_content_is_not_written_to_server_logs(): void
    {
        $message = 'Authorization: Bearer secret-token user@example.com';
        Log::shouldReceive('warning')
            ->once()
            ->with('Shift Tools client error', \\Mockery::on(
                static function (array $context) use ($message): bool {
                    $encoded = json_encode($context);

                    return ! array_key_exists('message', $context)
                        && $context['message_length'] === mb_strlen($message)
                        && ! str_contains((string) $encoded, 'secret-token')
                        && ! str_contains((string) $encoded, 'user@example.com');
                },
            ));

        $this->postJson('/api/v1/diagnostics/client-errors', [
            'error_code' => 'calendar.sync.failed',
            'category' => 'calendar',
            'message' => $message,
            'platform' => 'android',
            'app_version' => '4.1.0',
            'occurred_at' => '2026-07-26T10:00:00+07:00',
        ])->assertAccepted();
    }

    public function test_sensitive_or_unstructured_fields_are_rejected(): void
    {
        $this->postJson('/api/v1/diagnostics/client-errors', [
            'error_code' => 'invalid code with spaces',
            'category' => 'calendar',
            'message' => 'Failure',
            'platform' => 'android',
            'app_version' => '4.1.0',
            'occurred_at' => 'not-a-date',
            'access_token' => 'must-not-be-accepted',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['error_code', 'occurred_at', 'access_token']);
    }
}
