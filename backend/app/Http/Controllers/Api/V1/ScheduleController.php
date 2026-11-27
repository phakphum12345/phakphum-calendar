<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ScheduleController extends Controller
{
    public function show(Request $request, string $scheduleId): JsonResponse
    {
        $record = DB::table('schedule_records')
            ->where('owner_user_id', $request->user()->id)
            ->where('schedule_id', $scheduleId)
            ->first();

        if ($record === null) {
            return response()->json([
                'data' => null,
                'revision' => $this->absentRevision($request->user()->id, $scheduleId),
                'state' => 'absent',
            ], 200);
        }

        if ($record->state === 'deleted') {
            return response()->json([
                'data' => null,
                'revision' => $this->revision($record),
                'state' => 'deleted',
            ], 200);
        }

        return response()->json([
            'data' => json_decode($record->schedule_payload, true, 512, JSON_THROW_ON_ERROR),
            'revision' => $this->revision($record),
            'state' => 'live',
        ]);
    }

    public function store(Request $request, string $scheduleId): JsonResponse
    {
        $validated = $request->validate([
            'expected_revision' => ['required', 'string', 'max:160'],
            'schedule' => ['required', 'array:format,version,schedule'],
            'schedule.format' => ['required', 'in:shift-tools.canonical-schedule'],
            'schedule.version' => ['required', 'integer', 'in:1'],
            'schedule.schedule' => ['required', 'array:id,name,departments,employees,shiftTypes,months'],
            'schedule.schedule.id' => ['required', 'string', 'max:128', 'in:'.$scheduleId],
            'schedule.schedule.name' => ['required', 'string', 'max:200'],
            'schedule.schedule.departments' => ['sometimes', 'array'],
            'schedule.schedule.employees' => ['sometimes', 'array'],
            'schedule.schedule.shiftTypes' => ['sometimes', 'array'],
            'schedule.schedule.months' => ['sometimes', 'array'],
        ]);

        $payload = json_encode($validated['schedule'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR);
        $fingerprint = hash('sha256', $payload);
        $ownerId = $request->user()->id;
        $expected = $validated['expected_revision'];

        if ($expected === $this->absentRevision($ownerId, $scheduleId)) {
            try {
                $id = DB::table('schedule_records')->insertGetId([
                    'owner_user_id' => $ownerId,
                    'schedule_id' => $scheduleId,
                    'generation' => 1,
                    'state' => 'live',
                    'schedule_payload' => $payload,
                    'fingerprint' => $fingerprint,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            } catch (QueryException $exception) {
                if (! $this->isUniqueConstraintViolation($exception)) {
                    throw $exception;
                }

                $recordExists = DB::table('schedule_records')
                    ->where('owner_user_id', $ownerId)
                    ->where('schedule_id', $scheduleId)
                    ->exists();

                if (! $recordExists) {
                    throw $exception;
                }

                return $this->conflict($ownerId, $scheduleId);
            }

            $record = DB::table('schedule_records')->where('id', $id)->first();

            return $this->saved($record, 201);
        }

        if (preg_match('/^v([1-9][0-9]*):([a-f0-9]{64})$/', $expected, $matches) !== 1) {
            throw ValidationException::withMessages([
                'expected_revision' => ['The supplied revision token is invalid.'],
            ]);
        }

        $generation = (int) $matches[1];
        $expectedFingerprint = $matches[2];

        $updated = DB::table('schedule_records')
            ->where('owner_user_id', $ownerId)
            ->where('schedule_id', $scheduleId)
            ->where('state', 'live')
            ->where('generation', $generation)
            ->where('fingerprint', $expectedFingerprint)
            ->update([
                'generation' => DB::raw('generation + 1'),
                'schedule_payload' => $payload,
                'fingerprint' => $fingerprint,
                'updated_at' => now(),
            ]);

        if ($updated !== 1) {
            return $this->conflict($ownerId, $scheduleId);
        }

        return $this->saved(
            DB::table('schedule_records')
                ->where('owner_user_id', $ownerId)
                ->where('schedule_id', $scheduleId)
                ->first(),
        );
    }

    public function destroy(Request $request, string $scheduleId): JsonResponse
    {
        $validated = $request->validate([
            'expected_revision' => ['required', 'string', 'max:160'],
        ]);
        $expected = $validated['expected_revision'];
        $ownerId = $request->user()->id;
        $absentRevision = $this->absentRevision($ownerId, $scheduleId);
        $isAbsentRevision = hash_equals($absentRevision, $expected);
        $matchesLiveRevision = preg_match(
            '/^v([1-9][0-9]*):([a-f0-9]{64})$/',
            $expected,
            $matches,
        ) === 1;
        if (! $isAbsentRevision && ! $matchesLiveRevision) {
            throw ValidationException::withMessages([
                'expected_revision' => ['The supplied Schedule revision is invalid.'],
            ]);
        }

        $result = DB::transaction(function () use (
            $ownerId,
            $scheduleId,
            $expected,
            $isAbsentRevision,
            $matchesLiveRevision,
            $matches,
        ): array {
            $record = DB::table('schedule_records')
                ->where('owner_user_id', $ownerId)
                ->where('schedule_id', $scheduleId)
                ->lockForUpdate()
                ->first();

            if ($record === null) {
                if (! $isAbsentRevision) {
                    return ['status' => 409];
                }
                $inserted = DB::table('schedule_records')->insertOrIgnore([
                    'owner_user_id' => $ownerId,
                    'schedule_id' => $scheduleId,
                    'generation' => 1,
                    'state' => 'deleted',
                    'schedule_payload' => null,
                    'fingerprint' => null,
                    'deleted_from_revision' => $expected,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
                if ($inserted !== 1) {
                    return ['status' => 409];
                }
                $record = DB::table('schedule_records')
                    ->where('owner_user_id', $ownerId)
                    ->where('schedule_id', $scheduleId)
                    ->first();

                return ['status' => 201, 'record' => $record];
            }

            if ($record->state === 'deleted') {
                $currentRevision = $this->revision($record);
                if (
                    hash_equals($currentRevision, $expected)
                    || ($record->deleted_from_revision !== null
                        && hash_equals($record->deleted_from_revision, $expected))
                ) {
                    return ['status' => 200, 'record' => $record];
                }

                return ['status' => 409];
            }

            if (! $matchesLiveRevision) {
                return ['status' => 409];
            }

            $updated = DB::table('schedule_records')
                ->where('id', $record->id)
                ->where('owner_user_id', $ownerId)
                ->where('schedule_id', $scheduleId)
                ->where('state', 'live')
                ->where('generation', (int) $matches[1])
                ->where('fingerprint', $matches[2])
                ->update([
                    'generation' => DB::raw('generation + 1'),
                    'state' => 'deleted',
                    'schedule_payload' => null,
                    'fingerprint' => null,
                    'deleted_from_revision' => $expected,
                    'updated_at' => now(),
                ]);
            if ($updated !== 1) {
                return ['status' => 409];
            }

            return [
                'status' => 200,
                'record' => DB::table('schedule_records')->where('id', $record->id)->first(),
            ];
        });

        if ($result['status'] === 409) {
            return $this->conflict($ownerId, $scheduleId);
        }

        $record = $result['record'];

        return response()->json([
            'data' => null,
            'revision' => $this->revision($record),
            'state' => 'deleted',
        ], $result['status']);
    }

    private function saved(object $record, int $status = 200): JsonResponse
    {
        return response()->json([
            'data' => json_decode($record->schedule_payload, true, 512, JSON_THROW_ON_ERROR),
            'revision' => $this->revision($record),
            'state' => 'live',
        ], $status);
    }

    private function conflict(int $ownerId, string $scheduleId): JsonResponse
    {
        $record = DB::table('schedule_records')
            ->where('owner_user_id', $ownerId)
            ->where('schedule_id', $scheduleId)
            ->first();

        return response()->json([
            'error' => [
                'code' => 'schedule_revision_conflict',
                'message' => 'The Schedule changed after the supplied revision was read.',
            ],
            'current_revision' => $record === null
                ? $this->absentRevision($ownerId, $scheduleId)
                : $this->revision($record),
            'current_state' => $record?->state ?? 'absent',
        ], 409);
    }

    private function isUniqueConstraintViolation(QueryException $exception): bool
    {
        $sqlState = $exception->errorInfo[0] ?? (string) $exception->getCode();
        $driverCode = (int) ($exception->errorInfo[1] ?? 0);

        if ($sqlState === '23505') {
            return true;
        }

        if ($sqlState !== '23000') {
            return false;
        }

        if (in_array($driverCode, [1062, 2601, 2627], true)) {
            return true;
        }

        return $driverCode === 19
            && str_contains(strtolower($exception->getMessage()), 'unique constraint');
    }

    private function revision(object $record): string
    {
        return 'v'.$record->generation.':'.($record->fingerprint ?? str_repeat('0', 64));
    }

    private function absentRevision(int $ownerId, string $scheduleId): string
    {
        return 'absent:'.hash('sha256', $ownerId."\0".$scheduleId);
    }
}
