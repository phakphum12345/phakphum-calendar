<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ScheduleImportJournalController extends Controller
{
    public function index(Request $request, string $scheduleId): JsonResponse
    {
        $records = DB::table('schedule_import_journals')
            ->where('owner_user_id', $request->user()->id)
            ->where('schedule_id', $scheduleId)
            ->orderBy('created_at')
            ->get()
            ->map(fn (object $record): array => $this->resource($record));

        return response()->json(['data' => $records]);
    }

    public function store(Request $request, string $scheduleId): JsonResponse
    {
        $validated = $request->validate([
            'import_run_id' => ['required', 'uuid'],
            'lifecycle' => ['required', 'in:prepared,committed'],
            'base_revision' => ['required', 'string', 'max:160'],
            'source_fingerprint' => ['required', 'regex:/^[a-f0-9]{64}$/'],
            'accepted_schedule_fingerprint' => ['nullable', 'regex:/^[a-f0-9]{64}$/'],
            'provenance' => ['required', 'array'],
            'schedule' => ['nullable', 'array'],
            'schedule.id' => ['required_with:schedule', 'string', 'max:128', 'in:'.$scheduleId],
        ]);

        if ($validated['lifecycle'] === 'committed' &&
            (! isset($validated['schedule']) || ! isset($validated['accepted_schedule_fingerprint']))) {
            return response()->json([
                'error' => [
                    'code' => 'committed_journal_requires_schedule',
                    'message' => 'A committed journal record requires its accepted Schedule and fingerprint.',
                ],
            ], 422);
        }

        $payload = isset($validated['schedule'])
            ? json_encode($validated['schedule'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR)
            : null;
        $attributes = [
            'owner_user_id' => $request->user()->id,
            'schedule_id' => $scheduleId,
            'import_run_id' => $validated['import_run_id'],
            'lifecycle' => $validated['lifecycle'],
            'base_revision' => $validated['base_revision'],
            'source_fingerprint' => $validated['source_fingerprint'],
            'accepted_schedule_fingerprint' => $validated['accepted_schedule_fingerprint'] ?? null,
            'provenance' => json_encode($validated['provenance'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR),
            'schedule_payload' => $payload,
            'created_at' => now(),
            'updated_at' => now(),
        ];

        try {
            $id = DB::table('schedule_import_journals')->insertGetId($attributes);
        } catch (QueryException) {
            $existing = DB::table('schedule_import_journals')
                ->where('owner_user_id', $request->user()->id)
                ->where('import_run_id', $validated['import_run_id'])
                ->first();

            if ($existing !== null &&
                $existing->schedule_id === $scheduleId &&
                $existing->lifecycle === $validated['lifecycle'] &&
                $existing->base_revision === $validated['base_revision'] &&
                $existing->source_fingerprint === $validated['source_fingerprint'] &&
                $existing->accepted_schedule_fingerprint === ($validated['accepted_schedule_fingerprint'] ?? null) &&
                $existing->provenance === $attributes['provenance'] &&
                $existing->schedule_payload === $payload) {
                return response()->json(['data' => $this->resource($existing)], 200);
            }

            return response()->json([
                'error' => [
                    'code' => 'import_run_conflict',
                    'message' => 'The import run ID already exists with different content.',
                ],
            ], 409);
        }

        $record = DB::table('schedule_import_journals')->where('id', $id)->first();
        return response()->json(['data' => $this->resource($record)], 201);
    }

    private function resource(object $record): array
    {
        return [
            'import_run_id' => $record->import_run_id,
            'schedule_id' => $record->schedule_id,
            'lifecycle' => $record->lifecycle,
            'base_revision' => $record->base_revision,
            'source_fingerprint' => $record->source_fingerprint,
            'accepted_schedule_fingerprint' => $record->accepted_schedule_fingerprint,
            'provenance' => json_decode($record->provenance, true, 512, JSON_THROW_ON_ERROR),
            'schedule' => $record->schedule_payload === null
                ? null
                : json_decode($record->schedule_payload, true, 512, JSON_THROW_ON_ERROR),
            'created_at' => $record->created_at,
        ];
    }
}
