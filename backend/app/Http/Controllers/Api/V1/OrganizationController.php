<?php

namespace App\Http\Controllers\Api\V1;

use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class OrganizationController
{
    private const WORKFLOW_TYPES = [
        'give_up',
        'exchange',
        'exchange_and_return',
    ];

    public function index(Request $request): JsonResponse
    {
        $memberships = DB::table('organization_memberships as memberships')
            ->join('organizations', 'organizations.id', '=', 'memberships.organization_id')
            ->where('memberships.user_id', $request->user()->id)
            ->where('memberships.status', 'active')
            ->orderBy('organizations.name')
            ->get([
                'organizations.id',
                'organizations.name',
                'organizations.slug',
                'memberships.employee_id',
                'memberships.role',
            ]);

        return response()->json(['data' => $memberships]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'slug' => ['nullable', 'string', 'max:80', 'alpha_dash'],
            'employee_id' => ['required', 'string', 'max:128'],
        ]);

        $slug = Str::slug($validated['slug'] ?? $validated['name']);
        if ($slug === '') {
            return response()->json([
                'error' => ['code' => 'invalid_slug', 'message' => 'A valid organization slug is required.'],
            ], 422);
        }

        $organizationId = (string) Str::uuid();
        try {
            DB::transaction(function () use ($request, $validated, $slug, $organizationId): void {
                DB::table('organizations')->insert([
                    'id' => $organizationId,
                    'name' => $validated['name'],
                    'slug' => $slug,
                    'created_by_user_id' => $request->user()->id,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);

                DB::table('organization_memberships')->insert([
                    'organization_id' => $organizationId,
                    'user_id' => $request->user()->id,
                    'employee_id' => $validated['employee_id'],
                    'role' => 'owner',
                    'status' => 'active',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
                $this->recordMembershipAudit(
                    $organizationId,
                    $request->user()->id,
                    $request->user()->id,
                    'created',
                    null,
                    [
                        'employee_id' => $validated['employee_id'],
                        'role' => 'owner',
                        'status' => 'active',
                    ],
                );

                foreach (self::WORKFLOW_TYPES as $workflowType) {
                    DB::table('organization_shift_policies')->insert([
                        'organization_id' => $organizationId,
                        'workflow_type' => $workflowType,
                        'requires_approval' => true,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            });
        } catch (QueryException $exception) {
            if (! $this->isUniqueConstraintViolation($exception)) {
                throw $exception;
            }

            return response()->json([
                'error' => ['code' => 'organization_conflict', 'message' => 'The organization slug or membership already exists.'],
            ], 409);
        }

        return response()->json([
            'data' => [
                'id' => $organizationId,
                'name' => $validated['name'],
                'slug' => $slug,
                'role' => 'owner',
                'employee_id' => $validated['employee_id'],
            ],
        ], 201);
    }

    public function members(Request $request, string $organizationId): JsonResponse
    {
        $this->requireMembership($request, $organizationId);

        $members = DB::table('organization_memberships as memberships')
            ->join('users', 'users.id', '=', 'memberships.user_id')
            ->where('memberships.organization_id', $organizationId)
            ->where('memberships.status', 'active')
            ->orderBy('users.name')
            ->get([
                'users.id as user_id',
                'users.name',
                'users.email',
                'memberships.employee_id',
                'memberships.role',
                'memberships.status',
            ]);

        return response()->json(['data' => $members]);
    }

    public function membershipAudit(Request $request, string $organizationId): JsonResponse
    {
        $this->requireManager($request, $organizationId);
        $validated = $request->validate([
            'limit' => ['sometimes', 'integer', 'min:1', 'max:100'],
            'before_id' => ['sometimes', 'integer', 'min:1'],
        ]);
        $limit = (int) ($validated['limit'] ?? 50);

        $query = DB::table('organization_membership_audit_events as events')
            ->join('users as actors', 'actors.id', '=', 'events.actor_user_id')
            ->join('users as subjects', 'subjects.id', '=', 'events.subject_user_id')
            ->where('events.organization_id', $organizationId);
        if (isset($validated['before_id'])) {
            $query->where('events.id', '<', $validated['before_id']);
        }

        $events = $query
            ->orderByDesc('events.id')
            ->limit($limit)
            ->get([
                'events.id',
                'events.action',
                'events.actor_user_id',
                'actors.name as actor_name',
                'events.subject_user_id',
                'subjects.name as subject_name',
                'events.before_state',
                'events.after_state',
                'events.created_at',
            ]);

        $data = $events->map(static fn (object $event): array => [
            'id' => (int) $event->id,
            'action' => $event->action,
            'actor' => [
                'user_id' => (string) $event->actor_user_id,
                'name' => $event->actor_name,
            ],
            'subject' => [
                'user_id' => (string) $event->subject_user_id,
                'name' => $event->subject_name,
            ],
            'before' => $event->before_state === null
                ? null
                : json_decode($event->before_state, true, 512, JSON_THROW_ON_ERROR),
            'after' => $event->after_state === null
                ? null
                : json_decode($event->after_state, true, 512, JSON_THROW_ON_ERROR),
            'created_at' => $event->created_at,
        ])->values();

        return response()->json([
            'data' => $data,
            'meta' => [
                'limit' => $limit,
                'next_before_id' => $data->count() === $limit
                    ? $data->last()['id']
                    : null,
            ],
        ]);
    }

    public function addMember(Request $request, string $organizationId): JsonResponse
    {
        $this->requireManager($request, $organizationId);
        $validated = $request->validate([
            'email' => ['required', 'bail', 'max:254', 'email'],
            'employee_id' => ['required', 'string', 'max:128'],
            'role' => ['required', 'in:staff,incharge,manager,admin'],
        ]);

        $email = strtolower(trim($validated['email']));
        $actorUserId = $request->user()->id;
        $user = DB::table('users')
            ->where('email', $email)
            ->whereNotNull('google_subject')
            ->whereNotNull('email_verified_at')
            ->first();
        if ($user === null) {
            return response()->json([
                'error' => [
                    'code' => 'account_not_registered',
                    'message' => 'The member must sign in with Google before being added.',
                ],
            ], 404);
        }

        try {
            $result = DB::transaction(function () use (
                $organizationId,
                $user,
                $validated,
                $actorUserId,
            ): array {
                $existing = DB::table('organization_memberships')
                    ->where('organization_id', $organizationId)
                    ->where('user_id', $user->id)
                    ->lockForUpdate()
                    ->first();

                if ($existing !== null) {
                    if ($existing->status === 'active') {
                        return ['conflict' => true, 'reactivated' => false];
                    }

                    DB::table('organization_memberships')
                        ->where('id', $existing->id)
                        ->update([
                            'employee_id' => $validated['employee_id'],
                            'role' => $validated['role'],
                            'status' => 'active',
                            'updated_at' => now(),
                        ]);
                    $this->recordMembershipAudit(
                        $organizationId,
                        $actorUserId,
                        $user->id,
                        'reactivated',
                        [
                            'employee_id' => $existing->employee_id,
                            'role' => $existing->role,
                            'status' => $existing->status,
                        ],
                        [
                            'employee_id' => $validated['employee_id'],
                            'role' => $validated['role'],
                            'status' => 'active',
                        ],
                    );

                    return ['conflict' => false, 'reactivated' => true];
                }

                DB::table('organization_memberships')->insert([
                    'organization_id' => $organizationId,
                    'user_id' => $user->id,
                    'employee_id' => $validated['employee_id'],
                    'role' => $validated['role'],
                    'status' => 'active',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
                $this->recordMembershipAudit(
                    $organizationId,
                    $actorUserId,
                    $user->id,
                    'added',
                    null,
                    [
                        'employee_id' => $validated['employee_id'],
                        'role' => $validated['role'],
                        'status' => 'active',
                    ],
                );

                return ['conflict' => false, 'reactivated' => false];
            });
            if ($result['conflict']) {
                return response()->json([
                    'error' => [
                        'code' => 'membership_conflict',
                        'message' => 'This account or employee identity is already assigned in the organization.',
                    ],
                ], 409);
            }
            $reactivated = $result['reactivated'];
        } catch (QueryException $exception) {
            if (! $this->isUniqueConstraintViolation($exception)) {
                throw $exception;
            }

            return response()->json([
                'error' => [
                    'code' => 'membership_conflict',
                    'message' => 'This account or employee identity is already assigned in the organization.',
                ],
            ], 409);
        }

        return response()->json([
            'data' => [
                'user_id' => (string) $user->id,
                'email' => $email,
                'employee_id' => $validated['employee_id'],
                'role' => $validated['role'],
                'status' => 'active',
            ],
        ], $reactivated ? 200 : 201);
    }

    public function updateMemberRole(
        Request $request,
        string $organizationId,
        string $userId,
    ): JsonResponse {
        $this->requireManager($request, $organizationId);
        $validated = $request->validate([
            'role' => ['required', 'in:staff,incharge,manager,admin'],
        ]);
        $actorUserId = $request->user()->id;

        $result = DB::transaction(function () use (
            $organizationId,
            $userId,
            $validated,
            $actorUserId,
        ): array {
            $member = DB::table('organization_memberships')
                ->where('organization_id', $organizationId)
                ->where('user_id', $userId)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();

            if ($member === null) {
                return ['error' => 'member_not_found'];
            }
            if ($member->role === 'owner') {
                return ['error' => 'owner_membership_protected'];
            }
            if ($member->role === $validated['role']) {
                return [
                    'user_id' => (string) $member->user_id,
                    'role' => $member->role,
                    'status' => 'active',
                ];
            }

            DB::table('organization_memberships')
                ->where('id', $member->id)
                ->update([
                    'role' => $validated['role'],
                    'updated_at' => now(),
                ]);
            $this->recordMembershipAudit(
                $organizationId,
                $actorUserId,
                $member->user_id,
                'role_changed',
                [
                    'employee_id' => $member->employee_id,
                    'role' => $member->role,
                    'status' => $member->status,
                ],
                [
                    'employee_id' => $member->employee_id,
                    'role' => $validated['role'],
                    'status' => $member->status,
                ],
            );

            return [
                'user_id' => (string) $member->user_id,
                'role' => $validated['role'],
                'status' => 'active',
            ];
        });

        if (isset($result['error'])) {
            $notFound = $result['error'] === 'member_not_found';

            return response()->json([
                'error' => [
                    'code' => $result['error'],
                    'message' => $notFound
                        ? 'The active organization member was not found.'
                        : 'The organization owner role cannot be changed.',
                ],
            ], $notFound ? 404 : 409);
        }

        return response()->json(['data' => $result]);
    }

    public function removeMember(
        Request $request,
        string $organizationId,
        string $userId,
    ): JsonResponse {
        $this->requireManager($request, $organizationId);
        $actorUserId = $request->user()->id;

        $result = DB::transaction(function () use (
            $organizationId,
            $userId,
            $actorUserId,
        ): array {
            $member = DB::table('organization_memberships')
                ->where('organization_id', $organizationId)
                ->where('user_id', $userId)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();

            if ($member === null) {
                return ['error' => 'member_not_found'];
            }
            if ($member->role === 'owner') {
                return ['error' => 'owner_membership_protected'];
            }

            DB::table('organization_memberships')
                ->where('id', $member->id)
                ->update([
                    'status' => 'inactive',
                    'updated_at' => now(),
                ]);
            $this->recordMembershipAudit(
                $organizationId,
                $actorUserId,
                $member->user_id,
                'removed',
                [
                    'employee_id' => $member->employee_id,
                    'role' => $member->role,
                    'status' => $member->status,
                ],
                [
                    'employee_id' => $member->employee_id,
                    'role' => $member->role,
                    'status' => 'inactive',
                ],
            );

            return [
                'user_id' => (string) $member->user_id,
                'status' => 'inactive',
            ];
        });

        if (isset($result['error'])) {
            $notFound = $result['error'] === 'member_not_found';

            return response()->json([
                'error' => [
                    'code' => $result['error'],
                    'message' => $notFound
                        ? 'The active organization member was not found.'
                        : 'The organization owner membership cannot be removed.',
                ],
            ], $notFound ? 404 : 409);
        }

        return response()->json(['data' => $result]);
    }

    public function myJoinRequests(Request $request): JsonResponse
    {
        $requests = DB::table('organization_join_requests as requests')
            ->join('organizations', 'organizations.id', '=', 'requests.organization_id')
            ->where('requests.user_id', $request->user()->id)
            ->orderByDesc('requests.updated_at')
            ->get([
                'requests.id',
                'organizations.id as organization_id',
                'organizations.name as organization_name',
                'organizations.slug as organization_slug',
                'requests.employee_id',
                'requests.status',
                'requests.approved_role',
                'requests.created_at',
                'requests.reviewed_at',
            ]);

        return response()->json(['data' => $requests]);
    }

    public function requestMembership(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'organization_slug' => ['required', 'string', 'max:80', 'alpha_dash'],
            'employee_id' => ['required', 'string', 'max:128'],
        ]);
        $organization = DB::table('organizations')
            ->where('slug', strtolower(trim($validated['organization_slug'])))
            ->first(['id', 'name', 'slug']);

        if ($organization === null) {
            return response()->json([
                'error' => [
                    'code' => 'organization_not_found',
                    'message' => 'The organization code was not found.',
                ],
            ], 404);
        }

        $userId = $request->user()->id;
        try {
            return DB::transaction(function () use (
                $organization,
                $userId,
                $validated,
            ): JsonResponse {
                if (DB::table('organization_memberships')
                    ->where('organization_id', $organization->id)
                    ->where('user_id', $userId)
                    ->where('status', 'active')
                    ->exists()) {
                    return response()->json([
                        'error' => [
                            'code' => 'already_a_member',
                            'message' => 'This account already has an active organization membership.',
                        ],
                    ], 409);
                }

                $existing = DB::table('organization_join_requests')
                    ->where('organization_id', $organization->id)
                    ->where('user_id', $userId)
                    ->lockForUpdate()
                    ->first();

                if ($existing !== null && $existing->status === 'pending') {
                    return response()->json([
                        'error' => [
                            'code' => 'join_request_pending',
                            'message' => 'A request for this organization is already pending.',
                        ],
                    ], 409);
                }

                if ($existing !== null && $existing->status === 'approved') {
                    $membership = DB::table('organization_memberships')
                        ->where('organization_id', $organization->id)
                        ->where('user_id', $userId)
                        ->first(['status']);
                    $inactive = $membership !== null &&
                        $membership->status !== 'active';

                    return response()->json([
                        'error' => [
                            'code' => $inactive
                                ? 'membership_inactive'
                                : 'already_a_member',
                            'message' => $inactive
                                ? 'An administrator must reactivate this existing membership.'
                                : 'This account already has an approved organization membership.',
                        ],
                    ], 409);
                }

                $timestamp = now();
                $employeeId = trim($validated['employee_id']);
                if ($existing === null) {
                    $requestId = DB::table('organization_join_requests')->insertGetId([
                        'organization_id' => $organization->id,
                        'user_id' => $userId,
                        'employee_id' => $employeeId,
                        'status' => 'pending',
                        'created_at' => $timestamp,
                        'updated_at' => $timestamp,
                    ]);
                } else {
                    DB::table('organization_join_requests')
                        ->where('id', $existing->id)
                        ->update([
                            'employee_id' => $employeeId,
                            'status' => 'pending',
                            'approved_role' => null,
                            'reviewed_by_user_id' => null,
                            'reviewed_at' => null,
                            'updated_at' => $timestamp,
                        ]);
                    $requestId = $existing->id;
                }

                return response()->json([
                    'data' => [
                        'id' => $requestId,
                        'organization_id' => (string) $organization->id,
                        'organization_name' => $organization->name,
                        'organization_slug' => $organization->slug,
                        'employee_id' => $employeeId,
                        'status' => 'pending',
                    ],
                ], $existing === null ? 201 : 200);
            });
        } catch (QueryException $exception) {
            if (! $this->isUniqueConstraintViolation($exception)) {
                throw $exception;
            }

            return response()->json([
                'error' => [
                    'code' => 'join_request_conflict',
                    'message' => 'A request for this organization already exists.',
                ],
            ], 409);
        }
    }

    public function joinRequests(Request $request, string $organizationId): JsonResponse
    {
        $this->requireManager($request, $organizationId);

        $requests = DB::table('organization_join_requests as requests')
            ->join('users', 'users.id', '=', 'requests.user_id')
            ->where('requests.organization_id', $organizationId)
            ->where('requests.status', 'pending')
            ->orderBy('requests.created_at')
            ->get([
                'requests.id',
                'users.name',
                'users.email',
                'requests.employee_id',
                'requests.created_at',
            ]);

        return response()->json(['data' => $requests]);
    }

    public function approveJoinRequest(
        Request $request,
        string $organizationId,
        int $requestId,
    ): JsonResponse {
        $reviewer = $this->requireManager($request, $organizationId);
        $validated = $request->validate([
            'role' => ['required', 'in:staff,incharge,manager,admin'],
        ]);

        try {
            $member = DB::transaction(function () use (
                $organizationId,
                $requestId,
                $reviewer,
                $validated,
            ): array {
                $application = DB::table('organization_join_requests')
                    ->where('id', $requestId)
                    ->where('organization_id', $organizationId)
                    ->lockForUpdate()
                    ->first();

                if ($application === null) {
                    abort(404);
                }
                if ($application->status !== 'pending') {
                    abort(409, 'This join request has already been reviewed.');
                }

                $timestamp = now();
                $membership = DB::table('organization_memberships')
                    ->where('organization_id', $organizationId)
                    ->where('user_id', $application->user_id)
                    ->lockForUpdate()
                    ->first();

                if ($membership !== null && $membership->status === 'active') {
                    abort(409, 'This account already has an active organization membership.');
                }

                if ($membership === null) {
                    DB::table('organization_memberships')->insert([
                        'organization_id' => $organizationId,
                        'user_id' => $application->user_id,
                        'employee_id' => $application->employee_id,
                        'role' => $validated['role'],
                        'status' => 'active',
                        'created_at' => $timestamp,
                        'updated_at' => $timestamp,
                    ]);
                } else {
                    DB::table('organization_memberships')
                        ->where('id', $membership->id)
                        ->update([
                            'employee_id' => $application->employee_id,
                            'role' => $validated['role'],
                            'status' => 'active',
                            'updated_at' => $timestamp,
                        ]);
                }

                $this->recordMembershipAudit(
                    $organizationId,
                    $reviewer->user_id,
                    $application->user_id,
                    'join_request_approved',
                    $membership === null
                        ? null
                        : [
                            'employee_id' => $membership->employee_id,
                            'role' => $membership->role,
                            'status' => $membership->status,
                        ],
                    [
                        'employee_id' => $application->employee_id,
                        'role' => $validated['role'],
                        'status' => 'active',
                    ],
                );

                DB::table('organization_join_requests')
                    ->where('id', $requestId)
                    ->update([
                        'status' => 'approved',
                        'approved_role' => $validated['role'],
                        'reviewed_by_user_id' => $reviewer->user_id,
                        'reviewed_at' => $timestamp,
                        'updated_at' => $timestamp,
                    ]);

                return [
                    'request_id' => $requestId,
                    'user_id' => (string) $application->user_id,
                    'employee_id' => $application->employee_id,
                    'role' => $validated['role'],
                    'status' => 'active',
                ];
            });
        } catch (QueryException $exception) {
            if (! $this->isUniqueConstraintViolation($exception)) {
                throw $exception;
            }

            return response()->json([
                'error' => [
                    'code' => 'membership_conflict',
                    'message' => 'This account or employee identity is already assigned in the organization.',
                ],
            ], 409);
        }

        return response()->json(['data' => $member]);
    }

    public function rejectJoinRequest(
        Request $request,
        string $organizationId,
        int $requestId,
    ): JsonResponse {
        $reviewer = $this->requireManager($request, $organizationId);
        $rejectedAt = DB::transaction(function () use (
            $organizationId,
            $requestId,
            $reviewer,
        ): ?\Illuminate\Support\Carbon {
            $application = DB::table('organization_join_requests')
                ->where('id', $requestId)
                ->where('organization_id', $organizationId)
                ->lockForUpdate()
                ->first();

            if ($application === null) {
                abort(404);
            }
            if ($application->status !== 'pending') {
                return null;
            }

            $timestamp = now();
            DB::table('organization_join_requests')
                ->where('id', $requestId)
                ->update([
                    'status' => 'rejected',
                    'reviewed_by_user_id' => $reviewer->user_id,
                    'reviewed_at' => $timestamp,
                    'updated_at' => $timestamp,
                ]);

            return $timestamp;
        });

        if ($rejectedAt === null) {
            return response()->json([
                'error' => [
                    'code' => 'join_request_already_reviewed',
                    'message' => 'This join request has already been reviewed.',
                ],
            ], 409);
        }

        return response()->json([
            'data' => [
                'id' => $requestId,
                'status' => 'rejected',
                'reviewed_at' => $rejectedAt,
            ],
        ]);
    }

    public function policies(Request $request, string $organizationId): JsonResponse
    {
        $this->requireMembership($request, $organizationId);
        $stored = DB::table('organization_shift_policies')
            ->where('organization_id', $organizationId)
            ->get()
            ->keyBy('workflow_type');

        $data = collect(self::WORKFLOW_TYPES)->map(fn (string $workflowType): array => [
            'workflow_type' => $workflowType,
            'requires_approval' => (bool) ($stored[$workflowType]->requires_approval ?? true),
        ]);

        return response()->json(['data' => $data]);
    }

    public function updatePolicy(
        Request $request,
        string $organizationId,
        string $workflowType,
    ): JsonResponse {
        $this->requireManager($request, $organizationId);
        abort_unless(in_array($workflowType, self::WORKFLOW_TYPES, true), 404);

        $validated = $request->validate([
            'requires_approval' => ['required', 'boolean'],
        ]);

        $policyQuery = DB::table('organization_shift_policies')
            ->where('organization_id', $organizationId)
            ->where('workflow_type', $workflowType);
        $timestamp = now();

        if ($policyQuery->exists()) {
            $policyQuery->update([
                'requires_approval' => $validated['requires_approval'],
                'updated_at' => $timestamp,
            ]);
        } else {
            DB::table('organization_shift_policies')->insert([
                'organization_id' => $organizationId,
                'workflow_type' => $workflowType,
                'requires_approval' => $validated['requires_approval'],
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ]);
        }

        return response()->json([
            'data' => [
                'workflow_type' => $workflowType,
                'requires_approval' => (bool) $validated['requires_approval'],
            ],
        ]);
    }

    private function isUniqueConstraintViolation(QueryException $exception): bool
    {
        $message = strtolower($exception->getMessage());

        return str_contains($message, 'unique constraint') ||
            str_contains($message, 'duplicate entry') ||
            str_contains($message, 'unique violation');
    }

    private function recordMembershipAudit(
        string $organizationId,
        int|string $actorUserId,
        int|string $subjectUserId,
        string $action,
        ?array $beforeState,
        ?array $afterState,
    ): void {
        DB::table('organization_membership_audit_events')->insert([
            'organization_id' => $organizationId,
            'actor_user_id' => $actorUserId,
            'subject_user_id' => $subjectUserId,
            'action' => $action,
            'before_state' => $beforeState === null
                ? null
                : json_encode($beforeState, JSON_THROW_ON_ERROR),
            'after_state' => $afterState === null
                ? null
                : json_encode($afterState, JSON_THROW_ON_ERROR),
            'created_at' => now(),
        ]);
    }

    private function requireMembership(Request $request, string $organizationId): object
    {
        $membership = DB::table('organization_memberships')
            ->where('organization_id', $organizationId)
            ->where('user_id', $request->user()->id)
            ->where('status', 'active')
            ->first();

        abort_unless($membership !== null, 403, 'Active organization membership is required.');

        return $membership;
    }

    private function requireManager(Request $request, string $organizationId): object
    {
        $membership = $this->requireMembership($request, $organizationId);
        abort_unless(in_array($membership->role, ['owner', 'admin'], true), 403, 'Organization owner or admin role is required.');

        return $membership;
    }
}
