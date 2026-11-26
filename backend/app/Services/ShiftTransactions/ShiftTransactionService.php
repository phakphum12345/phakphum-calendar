<?php

namespace App\Services\ShiftTransactions;

use App\Services\Notifications\NotificationOutboxService;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ShiftTransactionService
{
    private const TYPES = ['give_up', 'exchange', 'exchange_and_return'];

    public function __construct(
        private readonly NotificationOutboxService $notificationOutbox,
    ) {}

    public function create(object $actor, array $input, string $idempotencyKey): array
    {
        if ($idempotencyKey === '' || strlen($idempotencyKey) > 128) {
            throw ValidationException::withMessages(['Idempotency-Key' => 'A key of 1–128 characters is required.']);
        }
        if (! in_array($input['type'], self::TYPES, true)) {
            throw ValidationException::withMessages(['type' => 'Unsupported shift transaction type.']);
        }

        $mode = $input['mode'];
        $organizationId = $mode === 'organization' ? ($input['organization_id'] ?? null) : null;
        if (! in_array($mode, ['personal', 'organization'], true) ||
            ($mode === 'organization' && ! is_string($organizationId)) ||
            ($mode === 'personal' && isset($input['organization_id']))) {
            throw ValidationException::withMessages(['mode' => 'Invalid transaction mode or organization scope.']);
        }

        $participants = $input['participants'];
        $transfers = $input['transfers'];
        if (count($participants) !== 2 || count($transfers) < 1 || count($transfers) > 2) {
            throw ValidationException::withMessages(['participants' => 'Exactly two participants and one or two transfers are required.']);
        }

        $participantUsers = [];
        $roles = [];
        $employeeIds = [];
        foreach ($participants as $participant) {
            // The authenticated actor is authoritative for the requester.
            // Recipients can be resolved by a registered subject (legacy),
            // organization member ID, or verified email (personal flow).
            if ($participant['role'] === 'requester') {
                $user = $actor;
            } elseif (! empty($participant['account_subject'])) {
                $user = DB::table('users')
                    ->where('google_subject', $participant['account_subject'])->first();
            } elseif ($mode === 'organization' && ! empty($participant['user_id'])) {
                $user = DB::table('users')->where('id', $participant['user_id'])->first();
            } elseif (! empty($participant['email'])) {
                $user = DB::table('users')
                    ->where('email', strtolower(trim($participant['email'])))
                    ->whereNotNull('email_verified_at')
                    ->first();
            } else {
                $user = null;
            }
            if ($user === null) {
                throw ValidationException::withMessages(['participants' => 'Every recipient must resolve to a registered account with a verified identity.']);
            }
            if (isset($participantUsers[$user->id]) || in_array($participant['employee_id'], $employeeIds, true)) {
                throw ValidationException::withMessages(['participants' => 'Participants must have distinct account and employee identities.']);
            }
            $participantUsers[$user->id] = [
                'user' => $user,
                'employee_id' => $participant['employee_id'],
                'role' => $participant['role'],
            ];
            $employeeIds[] = $participant['employee_id'];
            $roles[] = $participant['role'];
        }
        if (count(array_unique($roles)) !== 2 ||
            ! in_array('requester', $roles, true) ||
            ! in_array('recipient', $roles, true)) {
            throw ValidationException::withMessages(['participants' => 'One requester and one recipient are required.']);
        }

        $requester = collect($participantUsers)->firstWhere('role', 'requester');
        if ((int) $requester['user']->id !== (int) $actor->id) {
            throw new AccessDeniedHttpException('Only the requester may create the transaction.');
        }

        $requiresApproval = false;
        if ($mode === 'organization') {
            $members = DB::table('organization_memberships')
                ->where('organization_id', $organizationId)
                ->where('status', 'active')
                ->whereIn('user_id', array_keys($participantUsers))
                ->get()->keyBy('user_id');
            if ($members->count() !== 2) {
                throw new AccessDeniedHttpException('Both participants must be active members of this organization.');
            }
            foreach ($participantUsers as $userId => $participant) {
                if ($members[$userId]->employee_id !== $participant['employee_id']) {
                    throw new AccessDeniedHttpException('Participant employee identity does not match organization membership.');
                }
            }
            $policy = DB::table('organization_shift_policies')
                ->where('organization_id', $organizationId)
                ->where('workflow_type', $input['type'])->first();
            $requiresApproval = (bool) ($policy->requires_approval ?? true);
        }

        $this->validateTransferShape($input['type'], $transfers, $participantUsers);
        $requestMetadata = $input['metadata'] ?? [];
        $metadata = $requestMetadata;
        $metadata['requires_organization_approval'] = $requiresApproval;
        $canonical = [
            'mode' => $mode, 'type' => $input['type'], 'organization_id' => $organizationId,
            'participants' => $participants, 'transfers' => $transfers, 'metadata' => $requestMetadata,
        ];
        $requestHash = hash('sha256', json_encode($canonical, JSON_THROW_ON_ERROR));
        $existing = DB::table('shift_transactions')
            ->where('created_by_user_id', $actor->id)->where('idempotency_key', $idempotencyKey)->first();
        if ($existing !== null) {
            if (! hash_equals($existing->request_hash, $requestHash)) {
                throw new ConflictHttpException('Idempotency key was already used for a different request.');
            }

            return $this->read($existing->id, $actor);
        }

        $id = (string) Str::uuid();
        try {
            DB::transaction(function () use (
                $id, $actor, $mode, $input, $organizationId, $participantUsers,
                $transfers, $idempotencyKey, $requestHash, $metadata,
            ): void {
                $now = now();
                DB::table('shift_transactions')->insert([
                    'id' => $id, 'mode' => $mode, 'type' => $input['type'],
                    'organization_id' => $organizationId, 'created_by_user_id' => $actor->id,
                    'status' => 'pending_response', 'sync_status' => 'not_started', 'version' => 1,
                    'idempotency_key' => $idempotencyKey, 'request_hash' => $requestHash,
                    'metadata' => json_encode($metadata, JSON_THROW_ON_ERROR),
                    'created_at' => $now, 'updated_at' => $now,
                ]);
                foreach ($participantUsers as $participant) {
                    DB::table('shift_transaction_participants')->insert([
                        'transaction_id' => $id, 'user_id' => $participant['user']->id,
                        'employee_id' => $participant['employee_id'], 'role' => $participant['role'],
                        'created_at' => $now, 'updated_at' => $now,
                    ]);
                }
                foreach ($transfers as $transfer) {
                    DB::table('shift_transaction_transfers')->insert([
                        'transaction_id' => $id, 'transfer_key' => $transfer['id'],
                        'shift_id' => $transfer['shift_id'], 'from_employee_id' => $transfer['from_employee_id'],
                        'to_employee_id' => $transfer['to_employee_id'], 'shift_code' => $transfer['shift_code'],
                        'starts_at' => $transfer['starts_at'], 'ends_at' => $transfer['ends_at'],
                        'purpose' => $transfer['purpose'], 'created_at' => $now, 'updated_at' => $now,
                    ]);
                }
                $this->appendEvent($id, $organizationId, $actor->id, 'created', 1, [
                    'mode' => $mode, 'type' => $input['type'],
                    'requires_organization_approval' => $metadata['requires_organization_approval'],
                ], $now);
                $recipient = collect($participantUsers)->firstWhere('role', 'recipient');
                $recipientUserId = (int) $recipient['user']->id;
                $this->notificationOutbox->enqueue(
                    $recipientUserId,
                    'shift_transaction.created',
                    "shift-transaction:$id:created:$recipientUserId",
                    [
                        'transaction_id' => $id,
                        'transaction_type' => $input['type'],
                        'mode' => $mode,
                        'status' => 'pending_response',
                        'version' => 1,
                        'transfer_count' => count($transfers),
                    ],
                    $now,
                );
            });
        } catch (QueryException $exception) {
            $existing = DB::table('shift_transactions')
                ->where('created_by_user_id', $actor->id)->where('idempotency_key', $idempotencyKey)->first();
            if ($existing !== null && hash_equals($existing->request_hash, $requestHash)) {
                return $this->read($existing->id, $actor);
            }
            throw $exception;
        }

        return $this->read($id, $actor);
    }

    public function list(object $actor, array $filters): array
    {
        $query = DB::table('shift_transactions as transactions');
        if (isset($filters['mode'])) {
            $query->where('transactions.mode', $filters['mode']);
        }
        if (isset($filters['type'])) {
            $query->where('transactions.type', $filters['type']);
        }
        if (isset($filters['month'])) {
            // Historical timelines are filtered by the effective shift date,
            // not by when the request happened to be created.
            $monthStart = Carbon::parse($filters['month'].'-01')->startOfDay();
            $nextMonthStart = $monthStart->copy()->addMonth();
            $query->whereExists(function ($transfer) use ($monthStart, $nextMonthStart): void {
                $transfer->selectRaw('1')->from('shift_transaction_transfers')
                    ->whereColumn('shift_transaction_transfers.transaction_id', 'transactions.id')
                    ->where('shift_transaction_transfers.starts_at', '>=', $monthStart)
                    ->where('shift_transaction_transfers.starts_at', '<', $nextMonthStart);
            });
        }
        if (isset($filters['organization_id'])) {
            $this->requireOrganizationMember($actor, $filters['organization_id']);
            $query->where('transactions.organization_id', $filters['organization_id']);
        } else {
            $query->where(function ($scope) use ($actor): void {
                $scope->where(function ($personal) use ($actor): void {
                    $personal->whereNull('transactions.organization_id')
                        ->whereExists(function ($participant) use ($actor): void {
                            $participant->selectRaw('1')->from('shift_transaction_participants')
                                ->whereColumn('shift_transaction_participants.transaction_id', 'transactions.id')
                                ->where('shift_transaction_participants.user_id', $actor->id);
                        });
                })->orWhereIn('transactions.organization_id', function ($memberships) use ($actor): void {
                    $memberships->select('organization_id')->from('organization_memberships')
                        ->where('user_id', $actor->id)->where('status', 'active');
                });
            });
        }
        if (isset($filters['staff_id'])) {
            $query->whereExists(function ($participant) use ($filters): void {
                $participant->selectRaw('1')->from('shift_transaction_participants')
                    ->whereColumn('shift_transaction_participants.transaction_id', 'transactions.id')
                    ->where('shift_transaction_participants.employee_id', $filters['staff_id']);
            });
            if (! isset($filters['organization_id'])) {
                // Personal history is visible only to its two participants; organization scope is checked above.
                $query->where(function ($scope) use ($actor): void {
                    $scope->whereNull('transactions.organization_id')
                        ->orWhereIn('transactions.organization_id', function ($memberships) use ($actor): void {
                            $memberships->select('organization_id')->from('organization_memberships')
                                ->where('user_id', $actor->id)->where('status', 'active');
                        });
                });
            }
        }
        if (isset($filters['shift_type'])) {
            $query->whereExists(function ($transfer) use ($filters): void {
                $transfer->selectRaw('1')->from('shift_transaction_transfers')
                    ->whereColumn('shift_transaction_transfers.transaction_id', 'transactions.id')
                    ->where('shift_transaction_transfers.shift_code', $filters['shift_type']);
            });
        }
        $ids = $query->orderByDesc('transactions.created_at')->limit(100)->pluck('transactions.id');

        return $ids->map(fn (string $id): array => $this->read($id, $actor))->all();
    }

    public function read(string $id, object $actor): array
    {
        $transaction = DB::table('shift_transactions')->where('id', $id)->first();
        if ($transaction === null) {
            throw new NotFoundHttpException('Shift transaction not found.');
        }
        $this->authorizeRead($transaction, $actor);
        $participants = DB::table('shift_transaction_participants as participants')
            ->join('users', 'users.id', '=', 'participants.user_id')
            ->where('participants.transaction_id', $id)->orderBy('participants.id')
            ->get([
                'participants.user_id',
                'participants.employee_id',
                'participants.role',
                'participants.confirmed_at',
                'users.name',
            ])
            ->map(fn ($participant): array => [
                'employee_id' => $participant->employee_id,
                'role' => $participant->role,
                'confirmed_at' => $participant->confirmed_at,
                'name' => $participant->name,
                'is_current_user' => (int) $participant->user_id === (int) $actor->id,
            ]);
        $transfers = DB::table('shift_transaction_transfers')->where('transaction_id', $id)->orderBy('id')->get();
        $calendarEvents = DB::table('shift_transaction_calendar_events')->where('transaction_id', $id)->orderBy('transfer_key')->get();
        $syncAttempts = DB::table('shift_transaction_sync_attempts')->where('transaction_id', $id)->orderBy('attempt_number')->get();
        $events = DB::table('shift_transaction_events as events')
            ->leftJoin('users', 'users.id', '=', 'events.actor_user_id')
            ->where('events.transaction_id', $id)->orderBy('events.id')
            ->get(['events.id', 'events.event_type', 'events.transaction_version', 'events.event_data', 'events.occurred_at', 'users.name as actor_name']);

        return [
            'id' => $transaction->id, 'mode' => $transaction->mode, 'type' => $transaction->type,
            'organization_id' => $transaction->organization_id, 'status' => $transaction->status,
            'sync_status' => $transaction->sync_status, 'version' => $transaction->version,
            'metadata' => $transaction->metadata ? json_decode($transaction->metadata, true) : null,
            'created_at' => $transaction->created_at, 'updated_at' => $transaction->updated_at,
            'participants' => $participants, 'transfers' => $transfers,
            'calendar_events' => $calendarEvents, 'sync_attempts' => $syncAttempts,
            'timeline' => $events->map(fn ($event): array => [
                'id' => $event->id, 'event_type' => $event->event_type,
                'transaction_version' => $event->transaction_version, 'actor_name' => $event->actor_name,
                'data' => $event->event_data ? json_decode($event->event_data, true) : null,
                'occurred_at' => $event->occurred_at,
            ]),
        ];
    }

    public function transition(string $id, object $actor, string $action, array $input = []): array
    {
        return DB::transaction(function () use ($id, $actor, $action, $input): array {
            $transaction = DB::table('shift_transactions')->where('id', $id)->lockForUpdate()->first();
            if ($transaction === null) {
                throw new NotFoundHttpException('Shift transaction not found.');
            }
            $this->authorizeRead($transaction, $actor);
            $participant = DB::table('shift_transaction_participants')
                ->where('transaction_id', $id)->where('user_id', $actor->id)->first();
            $isParticipant = $participant !== null;
            $status = $transaction->status;
            $sync = $transaction->sync_status;
            $version = (int) $transaction->version;
            $now = now();
            $eventData = [];

            switch ($action) {
                case 'confirm':
                    if (! $isParticipant || ! in_array($status, ['pending_response', 'partially_accepted'], true)) {
                        throw new ConflictHttpException('This transaction is not awaiting your confirmation.');
                    }
                    if ($participant->confirmed_at !== null) {
                        return $this->read($id, $actor);
                    }
                    DB::table('shift_transaction_participants')->where('id', $participant->id)
                        ->update(['confirmed_at' => $now, 'updated_at' => $now]);
                    $confirmed = DB::table('shift_transaction_participants')->where('transaction_id', $id)->whereNotNull('confirmed_at')->count();
                    $total = DB::table('shift_transaction_participants')->where('transaction_id', $id)->count();
                    $status = $confirmed < $total ? 'partially_accepted' : 'approved';
                    $metadata = $transaction->metadata ? json_decode($transaction->metadata, true) : [];
                    if ($confirmed === $total && $transaction->organization_id !== null &&
                        (bool) ($metadata['requires_organization_approval'] ?? true)) {
                        $status = 'pending_approval';
                    }
                    $eventData = ['account_confirmed' => true];
                    break;

                case 'reject':
                    if (! $isParticipant || ! in_array($status, ['pending_response', 'partially_accepted'], true)) {
                        throw new ConflictHttpException('This transaction cannot be rejected by a participant.');
                    }
                    $status = 'rejected';
                    $eventData = ['reason' => $input['reason'] ?? null];
                    break;

                case 'approve':
                case 'reject_by_approver':
                    $this->requireOrganizationManager($actor, $transaction->organization_id);
                    if ($status !== 'pending_approval') {
                        throw new ConflictHttpException('This transaction is not awaiting organization approval.');
                    }
                    $status = $action === 'approve' ? 'approved' : 'rejected';
                    $eventData = ['note' => $input['note'] ?? $input['reason'] ?? null];
                    break;

                case 'cancel':
                    if ((int) $transaction->created_by_user_id !== (int) $actor->id ||
                        in_array($status, ['completed', 'cancelled', 'rejected'], true) ||
                        in_array($sync, ['pending', 'synced'], true)) {
                        throw new ConflictHttpException('This transaction cannot be cancelled by this account.');
                    }
                    $status = 'cancelled';
                    break;

                case 'sync_start':
                case 'sync_complete':
                case 'sync_fail':
                case 'fulfill':
                    if (! $isParticipant) {
                        throw new AccessDeniedHttpException('Only transaction participants may update Calendar or fulfillment state.');
                    }
                    if ($action === 'sync_start') {
                        if (($input['preview_confirmed'] ?? false) !== true) {
                            throw ValidationException::withMessages(['preview_confirmed' => 'Explicit preview confirmation is required.']);
                        }
                        if ($status !== 'approved' || in_array($sync, ['pending', 'synced'], true)) {
                            throw new ConflictHttpException('Only approved transactions may start Calendar sync.');
                        }
                        $attemptNumber = ((int) DB::table('shift_transaction_sync_attempts')
                            ->where('transaction_id', $id)->max('attempt_number')) + 1;
                        $attemptId = (string) Str::uuid();
                        DB::table('shift_transaction_sync_attempts')->insert([
                            'id' => $attemptId,
                            'transaction_id' => $id,
                            'attempt_number' => $attemptNumber,
                            'status' => 'started',
                            'initiated_by_user_id' => $actor->id,
                            'failure_reason' => null,
                            'started_at' => $now,
                            'finished_at' => null,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ]);
                        $sync = 'pending';
                        $eventData = ['attempt_id' => $attemptId, 'attempt_number' => $attemptNumber];
                    } elseif ($action === 'sync_complete') {
                        $mappings = $this->normalizeCalendarEvents($id, $input);
                        if ($sync === 'synced') {
                            $storedMappings = DB::table('shift_transaction_calendar_events')
                                ->where('transaction_id', $id)->orderBy('transfer_key')
                                ->get(['transfer_key', 'provider', 'calendar_id', 'event_id', 'etag'])
                                ->map(fn ($event): array => [
                                    'transfer_id' => $event->transfer_key,
                                    'provider' => $event->provider,
                                    'calendar_id' => $event->calendar_id,
                                    'event_id' => $event->event_id,
                                    'etag' => $event->etag,
                                ])->all();
                            if (hash_equals(
                                hash('sha256', json_encode($storedMappings, JSON_THROW_ON_ERROR)),
                                hash('sha256', json_encode($mappings, JSON_THROW_ON_ERROR)),
                            )) {
                                return $this->read($id, $actor);
                            }
                            throw new ConflictHttpException('Calendar sync was already completed with different provider event mappings.');
                        }
                        if ($sync !== 'pending') {
                            throw new ConflictHttpException('Calendar sync is not pending.');
                        }
                        $attempt = DB::table('shift_transaction_sync_attempts')
                            ->where('transaction_id', $id)->where('status', 'started')
                            ->orderByDesc('attempt_number')->lockForUpdate()->first();
                        if ($attempt === null) {
                            throw new ConflictHttpException('No active Calendar sync attempt exists.');
                        }
                        foreach ($mappings as $mapping) {
                            DB::table('shift_transaction_calendar_events')->insert([
                                'transaction_id' => $id,
                                'transfer_key' => $mapping['transfer_id'],
                                'provider' => $mapping['provider'],
                                'calendar_id' => $mapping['calendar_id'],
                                'event_id' => $mapping['event_id'],
                                'etag' => $mapping['etag'],
                                'synced_at' => $now,
                                'created_at' => $now,
                                'updated_at' => $now,
                            ]);
                        }
                        DB::table('shift_transaction_sync_attempts')->where('id', $attempt->id)->update([
                            'status' => 'completed',
                            'finished_at' => $now,
                            'updated_at' => $now,
                        ]);
                        $sync = 'synced';
                        $eventData = ['attempt_id' => $attempt->id, 'calendar_events' => $mappings];
                    } elseif ($action === 'sync_fail') {
                        if ($sync !== 'pending') {
                            throw new ConflictHttpException('Calendar sync is not pending.');
                        }
                        $attempt = DB::table('shift_transaction_sync_attempts')
                            ->where('transaction_id', $id)->where('status', 'started')
                            ->orderByDesc('attempt_number')->lockForUpdate()->first();
                        if ($attempt === null) {
                            throw new ConflictHttpException('No active Calendar sync attempt exists.');
                        }
                        $reason = $input['reason'] ?? null;
                        DB::table('shift_transaction_sync_attempts')->where('id', $attempt->id)->update([
                            'status' => 'failed',
                            'failure_reason' => $reason,
                            'finished_at' => $now,
                            'updated_at' => $now,
                        ]);
                        $sync = 'failed';
                        $eventData = ['attempt_id' => $attempt->id, 'reason' => $reason];
                    } else {
                        if ($status !== 'approved' || $sync !== 'synced') {
                            throw new ConflictHttpException('Verified Calendar sync and approval are required before fulfillment.');
                        }
                        $transfer = DB::table('shift_transaction_transfers')
                            ->where('transaction_id', $id)->where('transfer_key', $input['transfer_id'])->lockForUpdate()->first();
                        if ($transfer === null) {
                            throw new NotFoundHttpException('Shift transfer not found.');
                        }
                        if ($transfer->fulfilled_at !== null) {
                            return $this->read($id, $actor);
                        }
                        if ($transfer->to_employee_id !== $participant->employee_id) {
                            throw new AccessDeniedHttpException('Only the employee receiving this shift may confirm its fulfillment.');
                        }
                        if ($now->lt(Carbon::parse($transfer->ends_at))) {
                            throw new ConflictHttpException('A shift cannot be fulfilled before its scheduled end.');
                        }
                        DB::table('shift_transaction_transfers')->where('id', $transfer->id)
                            ->update(['fulfilled_at' => $now, 'updated_at' => $now]);
                        $remaining = DB::table('shift_transaction_transfers')
                            ->where('transaction_id', $id)->whereNull('fulfilled_at')->count();
                        if ($remaining === 0) {
                            $status = 'completed';
                        }
                        $eventData = ['transfer_id' => $transfer->transfer_key, 'shift_id' => $transfer->shift_id];
                    }
                    break;

                default:
                    throw new NotFoundHttpException('Unknown transaction action.');
            }

            $nextVersion = $version + 1;
            $updated = DB::table('shift_transactions')->where('id', $id)->where('version', $version)->update([
                'status' => $status, 'sync_status' => $sync, 'version' => $nextVersion, 'updated_at' => $now,
            ]);
            if ($updated !== 1) {
                throw new ConflictHttpException('Transaction version changed; reload and retry.');
            }
            $this->appendEvent($id, $transaction->organization_id, $actor->id, $action, $nextVersion, $eventData, $now);
            $this->enqueueParticipantNotifications(
                $transaction,
                $actor,
                $action,
                $nextVersion,
                $status,
                $sync,
                $now,
            );

            return $this->read($id, $actor);
        });
    }

    private function enqueueParticipantNotifications(
        object $transaction,
        object $actor,
        string $action,
        int $version,
        string $status,
        string $syncStatus,
        \DateTimeInterface $availableAt,
    ): void {
        // Starting a provider operation is an internal step; notify only
        // durable decisions and outcomes that another participant needs.
        if ($action === 'sync_start') {
            return;
        }

        $recipients = DB::table('shift_transaction_participants')
            ->where('transaction_id', $transaction->id)
            ->where('user_id', '<>', $actor->id)
            ->pluck('user_id');

        foreach ($recipients as $recipientUserId) {
            $recipientUserId = (int) $recipientUserId;
            $this->notificationOutbox->enqueue(
                $recipientUserId,
                'shift_transaction.'.$action,
                "shift-transaction:$transaction->id:v$version:$action:$recipientUserId",
                [
                    'transaction_id' => $transaction->id,
                    'transaction_type' => $transaction->type,
                    'action' => $action,
                    'status' => $status,
                    'sync_status' => $syncStatus,
                    'version' => $version,
                ],
                $availableAt,
            );
        }
    }

    private function normalizeCalendarEvents(string $transactionId, array $input): array
    {
        $transfers = DB::table('shift_transaction_transfers')
            ->where('transaction_id', $transactionId)->orderBy('id')->get(['transfer_key']);
        if (isset($input['calendar_events'])) {
            $mappings = array_values($input['calendar_events']);
        } else {
            $ids = array_values($input['calendar_event_ids'] ?? []);
            $mappings = [];
            foreach ($transfers as $index => $transfer) {
                if (! array_key_exists($index, $ids)) {
                    break;
                }
                $mappings[] = [
                    'transfer_id' => $transfer->transfer_key,
                    'provider' => 'legacy',
                    'calendar_id' => null,
                    'event_id' => $ids[$index],
                    'etag' => null,
                ];
            }
        }

        $expectedTransferIds = $transfers->pluck('transfer_key')->sort()->values()->all();
        $actualTransferIds = array_map(static fn (array $mapping): string => $mapping['transfer_id'], $mappings);
        sort($actualTransferIds);
        if (count($mappings) !== $transfers->count() ||
            count(array_unique($actualTransferIds)) !== count($actualTransferIds) ||
            $actualTransferIds !== $expectedTransferIds) {
            throw ValidationException::withMessages([
                'calendar_events' => 'Provide exactly one event mapping for every transfer leg.',
            ]);
        }

        $eventIdentities = array_map(
            static fn (array $mapping): string => implode('|', [
                $mapping['provider'],
                $mapping['calendar_id'] ?? '',
                $mapping['event_id'],
            ]),
            $mappings,
        );
        if (count(array_unique($eventIdentities)) !== count($eventIdentities)) {
            throw ValidationException::withMessages([
                'calendar_events' => 'Provider event references must be distinct.',
            ]);
        }

        $normalized = array_map(static fn (array $mapping): array => [
            'transfer_id' => $mapping['transfer_id'],
            'provider' => $mapping['provider'],
            'calendar_id' => $mapping['calendar_id'] ?? null,
            'event_id' => $mapping['event_id'],
            'etag' => $mapping['etag'] ?? null,
        ], $mappings);
        usort($normalized, static fn (array $a, array $b): int => $a['transfer_id'] <=> $b['transfer_id']);

        return $normalized;
    }

    private function validateTransferShape(string $type, array $transfers, array $participants): void
    {
        $byRole = collect($participants)->keyBy('role');
        $requester = $byRole['requester']['employee_id'];
        $recipient = $byRole['recipient']['employee_id'];
        $valid = match ($type) {
            'give_up' => count($transfers) === 1 && $transfers[0]['purpose'] === 'give_up' &&
                $transfers[0]['from_employee_id'] === $requester && $transfers[0]['to_employee_id'] === $recipient,
            'exchange' => count($transfers) === 2 &&
                collect($transfers)->every(fn ($t) => $t['purpose'] === 'exchange') &&
                $transfers[0]['from_employee_id'] === $transfers[1]['to_employee_id'] &&
                $transfers[0]['to_employee_id'] === $transfers[1]['from_employee_id'],
            'exchange_and_return' => count($transfers) === 2 &&
                count(array_filter($transfers, fn ($t) => $t['purpose'] === 'primary')) === 1 &&
                count(array_filter($transfers, fn ($t) => $t['purpose'] === 'return_shift')) === 1 &&
                collect($transfers)->contains(fn ($t) => $t['purpose'] === 'primary' &&
                    $t['from_employee_id'] === $requester && $t['to_employee_id'] === $recipient) &&
                collect($transfers)->contains(fn ($t) => $t['purpose'] === 'return_shift' &&
                    $t['from_employee_id'] === $recipient && $t['to_employee_id'] === $requester),
            default => false,
        };
        if (! $valid) {
            throw ValidationException::withMessages(['transfers' => 'Transfer legs do not match the selected transaction type.']);
        }
        foreach ($transfers as $transfer) {
            if ($transfer['from_employee_id'] === $transfer['to_employee_id'] ||
                ! in_array($transfer['from_employee_id'], [$requester, $recipient], true) ||
                ! in_array($transfer['to_employee_id'], [$requester, $recipient], true) ||
                strtotime($transfer['ends_at']) <= strtotime($transfer['starts_at'])) {
                throw ValidationException::withMessages(['transfers' => 'Transfer participants or scheduled times are invalid.']);
            }
        }
    }

    private function authorizeRead(object $transaction, object $actor): void
    {
        if ($transaction->organization_id !== null) {
            $this->requireOrganizationMember($actor, $transaction->organization_id);

            return;
        }
        $participant = DB::table('shift_transaction_participants')
            ->where('transaction_id', $transaction->id)->where('user_id', $actor->id)->exists();
        abort_unless($participant, 403, 'Only transaction participants may read this personal transaction.');
    }

    private function requireOrganizationMember(object $actor, string $organizationId): object
    {
        $membership = DB::table('organization_memberships')
            ->where('organization_id', $organizationId)->where('user_id', $actor->id)
            ->where('status', 'active')->first();
        if ($membership === null) {
            throw new AccessDeniedHttpException('Active organization membership is required.');
        }

        return $membership;
    }

    private function requireOrganizationManager(object $actor, ?string $organizationId): object
    {
        if ($organizationId === null) {
            throw new AccessDeniedHttpException('Personal transactions do not have organization approvers.');
        }
        $membership = $this->requireOrganizationMember($actor, $organizationId);
        if (! in_array($membership->role, ['owner', 'admin'], true)) {
            throw new AccessDeniedHttpException('Organization owner or admin role is required.');
        }

        return $membership;
    }

    private function appendEvent(
        string $id, ?string $organizationId, ?int $actorId, string $eventType,
        int $version, array $data, mixed $occurredAt,
    ): void {
        DB::table('shift_transaction_events')->insert([
            'transaction_id' => $id, 'organization_id' => $organizationId,
            'actor_user_id' => $actorId, 'event_type' => $eventType,
            'transaction_version' => $version, 'event_data' => json_encode($data, JSON_THROW_ON_ERROR),
            'occurred_at' => $occurredAt,
        ]);
    }
}
