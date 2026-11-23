<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreClientErrorRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;

class ClientErrorController extends Controller
{
    public function store(StoreClientErrorRequest $request): JsonResponse
    {
        $report = $request->safe()->only([
            'error_code',
            'category',
            'message',
            'platform',
            'app_version',
            'occurred_at',
        ]);
        $messageLength = mb_strlen($report['message']);
        unset($report['message']);
        $report['message_length'] = $messageLength;

        $requestId = $request->attributes->get('request_id');

        Log::warning('Shift Tools client error', [
            ...$report,
            'request_id' => $requestId,
        ]);

        return response()->json([
            'status' => 'accepted',
            'request_id' => $requestId,
        ], 202);
    }
}
