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
                'revision' => $this->absentRevision($scheduleId),
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
            'schedule' => ['required', 'array'],
            'schedule.id' => ['required', 'string', 'max:128', 'in:'.$scheduleId],
        ]);

        $payload = json_encode($validated['schedule'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
        $fingerprint = hash('sha256', $payload);
        $ownerId = $request->user()->id;
        $expected = $validated['expected_revision'];

        if ($expected === $this->absentRevision($scheduleId)) {
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
            } catch (QueryException) {
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

        if (preg_match('/^v([1-9][0-9]*):([a-f0-9]{64})$/', $expected, $matches) !== 1) {
            throw ValidationException::withMessages([
                'expected_revision' => ['A live revision token is required for deletion.'],
            ]);
        }

        $updated = DB::table('schedule_records')
            ->where('owner_user_id', $request->user()->id)
            ->where('schedule_id', $scheduleId)
            ->where('state', 'live')
            ->where('generation', (int) $matches[1])
            ->where('fingerprint', $matches[2])
            ->update([
                'generation' => DB::raw('generation + 1'),
                'state' => 'deleted',
                'schedule_payload' => null,
                'fingerprint' => null,
                'updated_at' => now(),
            ]);

        if ($updated !== 1) {
            return $this->conflict($request->user()->id, $scheduleId);
        }

        $record = DB::table('schedule_records')
            ->where('owner_user_id', $request->user()->id)
            ->where('schedule_id', $scheduleId)
            ->first();

        return response()->json([
            'data' => null,
            'revision' => $this->revision($record),
            'state' => 'deleted',
        ]);
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
                ? $this->absentRevision($scheduleId)
                : $this->revision($record),
            'current_state' => $record?->state ?? 'absent',
        ], 409);
    }

    private function revision(object $record): string
    {
        return 'v'.$record->generation.':'.($record->fingerprint ?? str_repeat('0', 64));
    }

    private function absentRevision(string $scheduleId): string
    {
        return 'absent:'.hash('sha256', $scheduleId);
    }
}
