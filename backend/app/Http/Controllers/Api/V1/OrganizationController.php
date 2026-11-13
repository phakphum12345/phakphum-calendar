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

    public function addMember(Request $request, string $organizationId): JsonResponse
    {
        $this->requireManager($request, $organizationId);
        $validated = $request->validate([
            'email' => ['required', 'email', 'max:255'],
            'employee_id' => ['required', 'string', 'max:128'],
            'role' => ['required', 'in:staff,incharge,manager,admin'],
        ]);

        $email = strtolower(trim($validated['email']));
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
            DB::table('organization_memberships')->insert([
                'organization_id' => $organizationId,
                'user_id' => $user->id,
                'employee_id' => $validated['employee_id'],
                'role' => $validated['role'],
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
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
        ], 201);
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
                    return response()->json([
                        'error' => [
                            'code' => 'already_a_member',
                            'message' => 'This account already has an approved organization membership.',
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
                DB::table('organization_memberships')->insert([
                    'organization_id' => $organizationId,
                    'user_id' => $application->user_id,
                    'employee_id' => $application->employee_id,
                    'role' => $validated['role'],
                    'status' => 'active',
                    'created_at' => $timestamp,
                    'updated_at' => $timestamp,
                ]);

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
