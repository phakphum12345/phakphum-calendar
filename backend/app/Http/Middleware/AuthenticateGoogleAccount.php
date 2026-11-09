<?php

namespace App\Http\Middleware;

use App\Contracts\GoogleIdentityTokenVerifier;
use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use InvalidArgumentException;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

class AuthenticateGoogleAccount
{
    public function __construct(
        private readonly GoogleIdentityTokenVerifier $verifier,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();
        if (! is_string($token) || $token === '') {
            return $this->unauthenticated();
        }

        try {
            $claims = $this->verifier->verify($token);
        } catch (InvalidArgumentException) {
            return $this->unauthenticated();
        } catch (Throwable) {
            return response()->json([
                'error' => [
                    'code' => 'authentication_provider_unavailable',
                    'message' => 'Google identity verification is temporarily unavailable.',
                ],
            ], 503);
        }

        $subject = trim((string) $claims['sub']);
        $email = strtolower(trim((string) $claims['email']));
        $name = is_string($claims['name'] ?? null) && trim($claims['name']) !== ''
            ? trim($claims['name'])
            : $email;

        $user = User::query()->where('google_subject', $subject)->first();

        if ($user === null) {
            if (User::query()->where('email', $email)->exists()) {
                return response()->json([
                    'error' => [
                        'code' => 'account_link_required',
                        'message' => 'This email is already registered to another sign-in method.',
                    ],
                ], 409);
            }

            $user = User::query()->create([
                'google_subject' => $subject,
                'name' => $name,
                'email' => $email,
                'password' => Hash::make(Str::random(64)),
            ]);
            $user->forceFill(['email_verified_at' => now()])->save();
        } else {
            $emailInUse = User::query()
                ->where('email', $email)
                ->where('id', '!=', $user->id)
                ->exists();

            if ($emailInUse) {
                return response()->json([
                    'error' => [
                        'code' => 'account_email_conflict',
                        'message' => 'The verified Google email is already linked to another account.',
                    ],
                ], 409);
            }

            $user->forceFill([
                'email' => $email,
                'name' => $name,
                'email_verified_at' => now(),
            ])->save();
        }

        $request->setUserResolver(fn (): User => $user);
        $request->attributes->set('google_identity', [
            'subject' => $subject,
            'email' => $email,
        ]);

        return $next($request);
    }

    private function unauthenticated(): Response
    {
        return response()->json([
            'error' => [
                'code' => 'unauthenticated',
                'message' => 'A valid Google ID token is required.',
            ],
        ], 401);
    }
}
