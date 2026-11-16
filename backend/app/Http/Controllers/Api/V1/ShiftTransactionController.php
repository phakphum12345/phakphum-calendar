<?php

namespace App\Http\Controllers\Api\V1;

use App\Services\ShiftTransactions\ShiftTransactionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ShiftTransactionController
{
    public function __construct(private readonly ShiftTransactionService $transactions) {}

    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'mode' => ['sometimes', Rule::in(['personal', 'organization'])],
            'type' => ['sometimes', Rule::in(['give_up', 'exchange', 'exchange_and_return'])],
            'month' => ['sometimes', 'date_format:Y-m'],
            'organization_id' => ['sometimes', 'uuid'],
        ]);
        return response()->json(['data' => $this->transactions->list($request->user(), $filters)]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'mode' => ['required', Rule::in(['personal', 'organization'])],
            'type' => ['required', Rule::in(['give_up', 'exchange', 'exchange_and_return'])],
            'organization_id' => ['required_if:mode,organization', 'prohibited_if:mode,personal', 'nullable', 'uuid'],
            'participants' => ['required', 'array', 'size:2'],
            'participants.*.account_subject' => ['required', 'string', 'max:255'],
            'participants.*.employee_id' => ['required', 'string', 'max:128'],
            'participants.*.role' => ['required', Rule::in(['requester', 'recipient'])],
            'transfers' => ['required', 'array', 'min:1', 'max:2'],
            'transfers.*.id' => ['required', 'string', 'max:64'],
            'transfers.*.shift_id' => ['required', 'string', 'max:128'],
            'transfers.*.from_employee_id' => ['required', 'string', 'max:128'],
            'transfers.*.to_employee_id' => ['required', 'string', 'max:128'],
            'transfers.*.shift_code' => ['required', 'string', 'max:64'],
            'transfers.*.starts_at' => ['required', 'date'],
            'transfers.*.ends_at' => ['required', 'date', 'after:transfers.*.starts_at'],
            'transfers.*.purpose' => ['required', Rule::in(['give_up', 'exchange', 'primary', 'return_shift'])],
            'metadata' => ['sometimes', 'array'],
        ]);
        $key = (string) $request->header('Idempotency-Key', '');
        $result = $this->transactions->create($request->user(), $validated, $key);
        return response()->json(['data' => $result], 201);
    }

    public function show(Request $request, string $transactionId): JsonResponse
    {
        return response()->json(['data' => $this->transactions->read($transactionId, $request->user())]);
    }

    public function confirm(Request $request, string $transactionId): JsonResponse
    {
        return $this->act($request, $transactionId, 'confirm');
    }

    public function reject(Request $request, string $transactionId): JsonResponse
    {
        return $this->act($request, $transactionId, 'reject');
    }

    public function approve(Request $request, string $transactionId): JsonResponse
    {
        return $this->act($request, $transactionId, 'approve');
    }

    public function rejectByApprover(Request $request, string $transactionId): JsonResponse
    {
        return $this->act($request, $transactionId, 'reject_by_approver');
    }

    public function cancel(Request $request, string $transactionId): JsonResponse
    {
        return $this->act($request, $transactionId, 'cancel');
    }

    public function startSync(Request $request, string $transactionId): JsonResponse
    {
        return $this->act($request, $transactionId, 'sync_start');
    }

    public function completeSync(Request $request, string $transactionId): JsonResponse
    {
        return $this->act($request, $transactionId, 'sync_complete');
    }

    public function failSync(Request $request, string $transactionId): JsonResponse
    {
        $validated = $request->validate(['reason' => ['nullable', 'string', 'max:1000']]);
        return response()->json(['data' => $this->transactions->transition(
            $transactionId, $request->user(), 'sync_fail', $validated,
        )]);
    }

    public function fulfill(Request $request, string $transactionId): JsonResponse
    {
        $validated = $request->validate(['transfer_id' => ['required', 'string', 'max:64']]);
        return response()->json(['data' => $this->transactions->transition(
            $transactionId, $request->user(), 'fulfill', $validated,
        )]);
    }

    private function act(Request $request, string $id, string $action): JsonResponse
    {
        $validated = $request->validate([
            'reason' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'note' => ['sometimes', 'nullable', 'string', 'max:1000'],
        ]);
        return response()->json(['data' => $this->transactions->transition(
            $id, $request->user(), $action, $validated,
        )]);
    }
}
