<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CalendarSyncCoordinationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'calendar_id' => ['sometimes', 'string', 'max:512'],
            'limit' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);
        $query = DB::table('calendar_sync_runs')
            ->where('owner_user_id', $request->user()->id);
        if (isset($filters['calendar_id'])) {
            $query->where('calendar_id', $filters['calendar_id']);
        }
        $runs = $query->orderByDesc('started_at')
            ->limit($filters['limit'] ?? 50)
            ->get();

        return response()->json(['data' => $runs->map(function (object $run): array {
            return $this->runResource($run);
        })]);
    }

    public function show(Request $request, string $runId): JsonResponse
    {
        $run = DB::table('calendar_sync_runs')
            ->where('owner_user_id', $request->user()->id)
            ->where('id', $runId)
            ->first();
        if ($run === null) {
            return response()->json(['error' => ['code' => 'calendar_sync_run_not_found', 'message' => 'The synchronization run was not found.']], 404);
        }

        return response()->json(['data' => $this->runResource($run)]);
    }

    public function operations(Request $request, string $runId): JsonResponse
    {
        $run = DB::table('calendar_sync_runs')
            ->where('owner_user_id', $request->user()->id)
            ->where('id', $runId)
            ->first();
        if ($run === null) {
            return response()->json(['error' => ['code' => 'calendar_sync_run_not_found', 'message' => 'The synchronization run was not found.']], 404);
        }

        $operations = DB::table('calendar_sync_operations')
            ->where('owner_user_id', $request->user()->id)
            ->where('run_id', $runId)
            ->orderBy('id')
            ->get()
            ->map(fn (object $operation): array => $this->operationResource($operation));

        return response()->json(['data' => $operations]);
    }

    public function acquire(Request $request): JsonResponse
    {
        $data = $request->validate([
            'run_id' => ['required', 'uuid'],
            'calendar_id' => ['required', 'string', 'max:512'],
            'schedule_id' => ['required', 'string', 'max:128'],
            'client_instance_id' => ['required', 'string', 'max:128'],
            'ttl_seconds' => ['sometimes', 'integer', 'min:15', 'max:300'],
        ]);
        $ownerId = $request->user()->id;
        $now = now();
        $ttl = $data['ttl_seconds'] ?? 60;

        $result = DB::transaction(function () use ($data, $ownerId, $now, $ttl): array {
            $lease = DB::table('calendar_sync_leases')
                ->where('owner_user_id', $ownerId)
                ->where('calendar_id', $data['calendar_id'])
                ->lockForUpdate()
                ->first();

            if ($lease !== null && Carbon::parse($lease->expires_at)->isFuture()) {
                if ($lease->run_id === $data['run_id'] &&
                    $lease->client_instance_id === $data['client_instance_id'] &&
                    $lease->schedule_id === $data['schedule_id']) {
                    $expiresAt = $now->copy()->addSeconds($ttl);
                    DB::table('calendar_sync_leases')->where('id', $lease->id)->update([
                        'expires_at' => $expiresAt,
                        'heartbeat_at' => $now,
                        'updated_at' => $now,
                    ]);
                    DB::table('calendar_sync_runs')->where('id', $lease->run_id)->update([
                        'heartbeat_at' => $now,
                        'updated_at' => $now,
                    ]);

                    return ['status' => 200, 'lease_token' => $lease->lease_token, 'expires_at' => $expiresAt->toISOString()];
                }

                return ['status' => 409, 'error' => 'calendar_sync_already_running'];
            }

            $token = Str::random(64);
            $expiresAt = $now->copy()->addSeconds($ttl);
            DB::table('calendar_sync_runs')->insert([
                'id' => $data['run_id'],
                'owner_user_id' => $ownerId,
                'calendar_id' => $data['calendar_id'],
                'schedule_id' => $data['schedule_id'],
                'client_instance_id' => $data['client_instance_id'],
                'status' => 'running',
                'started_at' => $now,
                'heartbeat_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            if ($lease === null) {
                $inserted = DB::table('calendar_sync_leases')->insertOrIgnore([
                    'owner_user_id' => $ownerId,
                    'calendar_id' => $data['calendar_id'],
                    'schedule_id' => $data['schedule_id'],
                    'run_id' => $data['run_id'],
                    'client_instance_id' => $data['client_instance_id'],
                    'lease_token' => $token,
                    'expires_at' => $expiresAt,
                    'heartbeat_at' => $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
                if ($inserted !== 1) {
                    DB::table('calendar_sync_runs')->where('id', $data['run_id'])->delete();

                    return ['status' => 409, 'error' => 'calendar_sync_already_running'];
                }
            } else {
                $updated = DB::table('calendar_sync_leases')
                    ->where('id', $lease->id)
                    ->where('expires_at', '<=', $now)
                    ->update([
                        'schedule_id' => $data['schedule_id'],
                        'run_id' => $data['run_id'],
                        'client_instance_id' => $data['client_instance_id'],
                        'lease_token' => $token,
                        'expires_at' => $expiresAt,
                        'heartbeat_at' => $now,
                        'updated_at' => $now,
                    ]);
                if ($updated !== 1) {
                    DB::table('calendar_sync_runs')->where('id', $data['run_id'])->delete();

                    return ['status' => 409, 'error' => 'calendar_sync_already_running'];
                }
                DB::table('calendar_sync_runs')->where('id', $lease->run_id)->update([
                    'status' => 'expired',
                    'finished_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            return ['status' => 201, 'lease_token' => $token, 'expires_at' => $expiresAt->toISOString()];
        });

        if ($result['status'] === 409) {
            return response()->json(['error' => ['code' => $result['error'], 'message' => 'Another device is already synchronizing this calendar.']], 409);
        }

        return response()->json(['data' => [
            'run_id' => $data['run_id'],
            'lease_token' => $result['lease_token'],
            'expires_at' => $result['expires_at'],
        ]], $result['status']);
    }

    public function heartbeat(Request $request, string $runId): JsonResponse
    {
        $data = $request->validate([
            'lease_token' => ['required', 'string', 'size:64'],
            'ttl_seconds' => ['sometimes', 'integer', 'min:15', 'max:300'],
        ]);
        $now = now();
        $expiresAt = $now->copy()->addSeconds($data['ttl_seconds'] ?? 60);
        $updated = DB::table('calendar_sync_leases')
            ->where('owner_user_id', $request->user()->id)
            ->where('run_id', $runId)
            ->where('lease_token', $data['lease_token'])
            ->where('expires_at', '>', $now)
            ->update(['expires_at' => $expiresAt, 'heartbeat_at' => $now, 'updated_at' => $now]);

        if ($updated !== 1) {
            return response()->json(['error' => ['code' => 'calendar_sync_lease_lost', 'message' => 'The synchronization lease is missing or expired.']], 409);
        }

        DB::table('calendar_sync_runs')->where('id', $runId)->where('owner_user_id', $request->user()->id)->update([
            'heartbeat_at' => $now,
            'updated_at' => $now,
        ]);

        return response()->json(['data' => ['run_id' => $runId, 'expires_at' => $expiresAt->toISOString()]]);
    }

    public function release(Request $request, string $runId): JsonResponse
    {
        $data = $request->validate([
            'lease_token' => ['required', 'string', 'size:64'],
            'status' => ['required', 'in:success,partial_success,failed,cancelled'],
        ]);
        $now = now();

        $released = DB::transaction(function () use ($request, $runId, $data, $now): bool {
            $lease = DB::table('calendar_sync_leases')
                ->where('owner_user_id', $request->user()->id)
                ->where('run_id', $runId)
                ->where('lease_token', $data['lease_token'])
                ->where('expires_at', '>', $now)
                ->lockForUpdate()
                ->first();
            if ($lease === null) {
                return false;
            }

            DB::table('calendar_sync_runs')->where('id', $runId)->where('owner_user_id', $request->user()->id)->update([
                'status' => $data['status'],
                'finished_at' => $now,
                'updated_at' => $now,
            ]);
            DB::table('calendar_sync_leases')->where('id', $lease->id)->delete();

            return true;
        });

        if ($released === false) {
            return response()->json(['error' => ['code' => 'calendar_sync_lease_lost', 'message' => 'The synchronization lease is missing.']], 409);
        }

        return response()->json(['data' => ['run_id' => $runId, 'status' => $data['status']]]);
    }

    public function recordOperation(Request $request, string $runId): JsonResponse
    {
        $data = $request->validate([
            'lease_token' => ['required', 'string', 'size:64'],
            'operation_key' => ['required', 'string', 'max:128'],
            'operation_type' => ['required', 'in:insert,update,delete'],
            'payload_hash' => ['required', 'regex:/^[a-f0-9]{64}$/'],
            'operation_payload' => ['required', 'array', 'max:24'],
        ]);

        $payloadJson = json_encode($this->canonicalizePayload($data['operation_payload']), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR);
        if (hash_equals(hash('sha256', $payloadJson), $data['payload_hash']) === false) {
            return response()->json(['error' => ['code' => 'calendar_sync_payload_hash_mismatch', 'message' => 'The operation payload does not match its SHA-256 hash.']], 422);
        }
        $payloadCiphertext = Crypt::encryptString($payloadJson);

        $result = DB::transaction(function () use ($request, $runId, $data, $payloadCiphertext): array {
            if ($this->lockActiveLease($request, $runId, $data['lease_token']) === false) {
                return ['status' => 409, 'error' => 'calendar_sync_lease_lost'];
            }

            $existing = DB::table('calendar_sync_operations')
                ->where('owner_user_id', $request->user()->id)
                ->where('run_id', $runId)
                ->where('operation_key', $data['operation_key'])
                ->lockForUpdate()
                ->first();

            if ($existing !== null) {
                if (
                    $existing->operation_type !== $data['operation_type']
                    || hash_equals($existing->payload_hash, $data['payload_hash']) === false
                ) {
                    return ['status' => 409, 'error' => 'calendar_sync_operation_conflict'];
                }

                return [
                    'status' => 200,
                    'data' => $this->operationResource($existing),
                ];
            }

            $now = now();
            $inserted = DB::table('calendar_sync_operations')->insertOrIgnore([
                'run_id' => $runId,
                'owner_user_id' => $request->user()->id,
                'operation_key' => $data['operation_key'],
                'operation_type' => $data['operation_type'],
                'status' => 'prepared',
                'payload_hash' => $data['payload_hash'],
                'payload_ciphertext' => $payloadCiphertext,
                'attempt_count' => 0,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $record = DB::table('calendar_sync_operations')
                ->where('owner_user_id', $request->user()->id)
                ->where('run_id', $runId)
                ->where('operation_key', $data['operation_key'])
                ->lockForUpdate()
                ->first();

            if (
                $record === null
                || $record->operation_type !== $data['operation_type']
                || hash_equals($record->payload_hash, $data['payload_hash']) === false
            ) {
                return ['status' => 409, 'error' => 'calendar_sync_operation_conflict'];
            }

            return [
                'status' => $inserted === 1 ? 201 : 200,
                'data' => $this->operationResource($record),
            ];
        });

        if ($result['status'] === 409) {
            return response()->json([
                'error' => [
                    'code' => $result['error'],
                    'message' => $result['error'] === 'calendar_sync_lease_lost'
                        ? 'The synchronization lease is missing or expired.'
                        : 'The operation key was already used with different content.',
                ],
            ], 409);
        }

        return response()->json(['data' => $result['data']], $result['status']);
    }

    public function updateOperation(Request $request, string $runId, string $operationKey): JsonResponse
    {
        $data = $request->validate([
            'lease_token' => ['required', 'string', 'size:64'],
            'status' => ['required', 'in:prepared,running,succeeded,failed'],
            'attempt_count' => ['required', 'integer', 'min:0', 'max:65535'],
            'provider_event_id' => ['nullable', 'string', 'max:512'],
            'last_error' => ['nullable', 'string', 'max:4000'],
        ]);

        $result = DB::transaction(function () use ($request, $runId, $operationKey, $data): array {
            if ($this->lockActiveLease($request, $runId, $data['lease_token']) === false) {
                return ['status' => 409, 'error' => 'calendar_sync_lease_lost'];
            }

            $operation = DB::table('calendar_sync_operations')
                ->where('owner_user_id', $request->user()->id)
                ->where('run_id', $runId)
                ->where('operation_key', $operationKey)
                ->lockForUpdate()
                ->first();

            if ($operation === null) {
                return ['status' => 404, 'error' => 'calendar_sync_operation_not_found'];
            }

            if ($data['attempt_count'] < $operation->attempt_count) {
                return ['status' => 409, 'error' => 'calendar_sync_attempt_regression'];
            }

            $allowedTransitions = match ($operation->status) {
                'prepared' => ['prepared', 'running', 'failed'],
                'running' => ['running', 'succeeded', 'failed'],
                'failed' => ['failed', 'running'],
                'succeeded' => ['succeeded'],
                default => [],
            };
            if (
                in_array($data['status'], $allowedTransitions, true) === false
                || (
                    $operation->status === 'failed'
                    && $data['status'] === 'running'
                    && $data['attempt_count'] <= $operation->attempt_count
                )
            ) {
                return ['status' => 409, 'error' => 'calendar_sync_operation_transition_invalid'];
            }

            $now = now();
            DB::table('calendar_sync_operations')->where('id', $operation->id)->update([
                'status' => $data['status'],
                'attempt_count' => $data['attempt_count'],
                'provider_event_id' => $data['provider_event_id'] ?? $operation->provider_event_id,
                'last_error' => $data['last_error'] ?? null,
                'started_at' => $data['status'] === 'running' ? ($operation->started_at ?? $now) : $operation->started_at,
                'finished_at' => in_array($data['status'], ['succeeded', 'failed'], true) ? $now : null,
                'updated_at' => $now,
            ]);

            $updated = DB::table('calendar_sync_operations')->where('id', $operation->id)->first();

            return [
                'status' => 200,
                'data' => $this->operationResource($updated),
            ];
        });

        if ($result['status'] !== 200) {
            $messages = [
                'calendar_sync_lease_lost' => 'The synchronization lease is missing or expired.',
                'calendar_sync_operation_not_found' => 'The operation has not been recorded.',
                'calendar_sync_attempt_regression' => 'Attempt count cannot move backwards.',
                'calendar_sync_operation_transition_invalid' => 'The operation status transition is not allowed.',
            ];

            return response()->json([
                'error' => [
                    'code' => $result['error'],
                    'message' => $messages[$result['error']] ?? 'The operation update was rejected.',
                ],
            ], $result['status']);
        }

        return response()->json(['data' => $result['data']]);
    }

    /**
     * Lock and validate the lease in the same transaction as the ledger write.
     * This prevents a stale client from passing a separate preflight check and
     * then writing after another client has reclaimed the Calendar lease.
     */
    private function lockActiveLease(Request $request, string $runId, string $token): bool
    {
        return DB::table('calendar_sync_leases')
            ->where('owner_user_id', $request->user()->id)
            ->where('run_id', $runId)
            ->where('lease_token', $token)
            ->where('expires_at', '>', now())
            ->lockForUpdate()
            ->first() !== null;
    }

    private function leaseLost(): JsonResponse
    {
        return response()->json(['error' => ['code' => 'calendar_sync_lease_lost', 'message' => 'The synchronization lease is missing or expired.']], 409);
    }

    private function runResource(object $run): array
    {
        return [
            'run_id' => $run->id,
            'calendar_id' => $run->calendar_id,
            'schedule_id' => $run->schedule_id,
            'client_instance_id' => $run->client_instance_id,
            'status' => $run->status,
            'started_at' => $run->started_at,
            'heartbeat_at' => $run->heartbeat_at,
            'finished_at' => $run->finished_at,
            'operation_count' => DB::table('calendar_sync_operations')
                ->where('run_id', $run->id)
                ->count(),
        ];
    }

    private function canonicalizePayload(array $value): array
    {
        foreach ($value as $key => $item) {
            if (is_array($item)) {
                $value[$key] = $this->canonicalizePayload($item);
            }
        }

        if (array_is_list($value) === false) {
            ksort($value);
        }

        return $value;
    }

    private function operationResource(object $operation): array
    {
        return [
            'operation_key' => $operation->operation_key,
            'operation_type' => $operation->operation_type,
            'status' => $operation->status,
            'payload_hash' => $operation->payload_hash,
            'operation_payload' => json_decode(Crypt::decryptString($operation->payload_ciphertext), true, 512, JSON_THROW_ON_ERROR),
            'attempt_count' => $operation->attempt_count,
            'provider_event_id' => $operation->provider_event_id,
            'last_error' => $operation->last_error,
            'started_at' => $operation->started_at,
            'finished_at' => $operation->finished_at,
        ];
    }
}
