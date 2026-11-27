<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;

class ScheduleImportJournalController extends Controller
{
    /**
     * Lists Schedule IDs with import journals owned by the authenticated user.
     * This index intentionally returns identifiers only; callers fetch and
     * validate each journal through the Schedule-scoped endpoint before review.
     */
    public function discover(Request $request): JsonResponse
    {
        $scheduleIds = DB::table('schedule_import_journals')
            ->where('owner_user_id', $request->user()->id)
            ->select('schedule_id')
            ->distinct()
            ->orderBy('schedule_id')
            ->pluck('schedule_id')
            ->values();

        return response()->json(['data' => $scheduleIds]);
    }

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
            'import_run_id' => ['required', 'string', 'max:128', 'regex:/^[A-Za-z0-9._:-]+$/'],
            'lifecycle' => ['required', 'in:prepared,committed'],
            'base_revision' => ['required', 'string', 'max:160'],
            'source_fingerprint' => ['required', 'regex:/^[a-f0-9]{64}$/'],
            'accepted_schedule_fingerprint' => ['nullable', 'regex:/^[a-f0-9]{64}$/'],
            'provenance' => ['required', 'array'],
            'schedule' => ['nullable', 'array:format,version,schedule'],
            'schedule.format' => ['required_with:schedule', 'in:shift-tools.canonical-schedule'],
            'schedule.version' => ['required_with:schedule', 'integer', 'in:1'],
            'schedule.schedule' => ['required_with:schedule', 'array:id,name,departments,employees,shiftTypes,months'],
            'schedule.schedule.id' => ['required_with:schedule', 'string', 'max:128', 'in:'.$scheduleId],
            'schedule.schedule.name' => ['required_with:schedule', 'string', 'max:200'],
        ]);

        if ($validated['lifecycle'] === 'committed' &&
            (isset($validated['schedule']) === false || isset($validated['accepted_schedule_fingerprint']) === false)) {
            return response()->json([
                'error' => [
                    'code' => 'committed_journal_requires_schedule',
                    'message' => 'A committed journal record requires its accepted Schedule and fingerprint.',
                ],
            ], 422);
        }

        if ($validated['lifecycle'] === 'committed') {
            $prepared = DB::table('schedule_import_journals')
                ->where('owner_user_id', $request->user()->id)
                ->where('schedule_id', $scheduleId)
                ->where('import_run_id', $validated['import_run_id'])
                ->where('lifecycle', 'prepared')
                ->first();

            if ($prepared === null ||
                $prepared->base_revision !== $validated['base_revision'] ||
                $prepared->source_fingerprint !== $validated['source_fingerprint']) {
                return response()->json([
                    'error' => [
                        'code' => 'prepared_journal_not_found',
                        'message' => 'A matching PREPARED journal record is required before COMMITTED.',
                    ],
                ], 409);
            }
        }

        $payload = isset($validated['schedule'])
            ? json_encode($validated['schedule'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR)
            : null;
        $storedPayload = $payload === null ? null : $this->encodeSchedulePayload($payload);
        $provenance = json_encode($validated['provenance'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
        $storedProvenance = $this->encodeProvenance($provenance);

        if ($validated['lifecycle'] === 'committed' &&
            hash_equals($validated['accepted_schedule_fingerprint'], hash('sha256', $payload)) === false) {
            return response()->json([
                'error' => [
                    'code' => 'accepted_schedule_fingerprint_mismatch',
                    'message' => 'The accepted Schedule fingerprint does not match the committed payload.',
                ],
            ], 422);
        }

        $attributes = [
            'owner_user_id' => $request->user()->id,
            'schedule_id' => $scheduleId,
            'import_run_id' => $validated['import_run_id'],
            'lifecycle' => $validated['lifecycle'],
            'base_revision' => $validated['base_revision'],
            'source_fingerprint' => $validated['source_fingerprint'],
            'accepted_schedule_fingerprint' => $validated['accepted_schedule_fingerprint'] ?? null,
            'provenance' => $storedProvenance,
            'schedule_payload' => $storedPayload,
            'created_at' => now(),
            'updated_at' => now(),
        ];

        try {
            $id = DB::table('schedule_import_journals')->insertGetId($attributes);
        } catch (QueryException $exception) {
            if (! $this->isUniqueConstraintViolation($exception)) {
                throw $exception;
            }

            $existing = DB::table('schedule_import_journals')
                ->where('owner_user_id', $request->user()->id)
                ->where('import_run_id', $validated['import_run_id'])
                ->where('lifecycle', $validated['lifecycle'])
                ->first();

            if ($existing !== null &&
                $existing->schedule_id === $scheduleId &&
                $existing->lifecycle === $validated['lifecycle'] &&
                $existing->base_revision === $validated['base_revision'] &&
                $existing->source_fingerprint === $validated['source_fingerprint'] &&
                $existing->accepted_schedule_fingerprint === ($validated['accepted_schedule_fingerprint'] ?? null) &&
                $this->decodeProvenance($existing->provenance) === json_decode($provenance, true, 512, JSON_THROW_ON_ERROR) &&
                ($existing->schedule_payload === null
                    ? $payload === null
                    : $this->decodeSchedulePayload($existing->schedule_payload) === $payload)) {
                return response()->json(['data' => $this->resource($existing)], 200);
            }

            if ($existing === null) {
                throw $exception;
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

    private function encodeSchedulePayload(string $payload): string
    {
        return 'enc:v1:'.Crypt::encryptString($payload);
    }

    private function decodeSchedulePayload(string $payload): string
    {
        if (! str_starts_with($payload, 'enc:v1:')) {
            // Legacy journal records remain readable after encryption rollout.
            return $payload;
        }

        return Crypt::decryptString(substr($payload, strlen('enc:v1:')));
    }

    private function encodeProvenance(string $provenance): string
    {
        return json_encode([
            'encryption_version' => 1,
            'ciphertext' => Crypt::encryptString($provenance),
        ], JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
    }

    private function decodeProvenance(string $stored): array
    {
        $decoded = json_decode($stored, true, 512, JSON_THROW_ON_ERROR);
        if (is_array($decoded) && array_key_exists('encryption_version', $decoded)) {
            if (($decoded['encryption_version'] ?? null) !== 1 ||
                ! is_string($decoded['ciphertext'] ?? null)) {
                throw new UnexpectedValueException('Unsupported encrypted provenance envelope.');
            }

            $decoded = json_decode(
                Crypt::decryptString($decoded['ciphertext']),
                true,
                512,
                JSON_THROW_ON_ERROR,
            );
        }

        if (! is_array($decoded)) {
            throw new UnexpectedValueException('Import journal provenance must decode to an object.');
        }

        return $decoded;
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

    private function resource(object $record): array
    {
        return [
            'import_run_id' => $record->import_run_id,
            'schedule_id' => $record->schedule_id,
            'lifecycle' => $record->lifecycle,
            'base_revision' => $record->base_revision,
            'source_fingerprint' => $record->source_fingerprint,
            'accepted_schedule_fingerprint' => $record->accepted_schedule_fingerprint,
            'provenance' => $this->decodeProvenance($record->provenance),
            'schedule' => $record->schedule_payload === null
                ? null
                : json_decode($this->decodeSchedulePayload($record->schedule_payload), true, 512, JSON_THROW_ON_ERROR),
            'created_at' => $record->created_at,
        ];
    }
}
