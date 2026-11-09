<?php

namespace App\Http\Controllers\Api\V1;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GoogleAccountController
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'data' => [
                'id' => (string) $user->id,
                'email' => $user->email,
                'name' => $user->name,
            ],
        ]);
    }
}
