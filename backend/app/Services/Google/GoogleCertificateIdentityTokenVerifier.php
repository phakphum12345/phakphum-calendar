<?php

namespace App\Services\Google;

use App\Contracts\GoogleIdentityTokenVerifier;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use InvalidArgumentException;
use JsonException;
use OpenSSLAsymmetricKey;
use RuntimeException;

class GoogleCertificateIdentityTokenVerifier implements GoogleIdentityTokenVerifier
{
    /**
     * @return array<string, mixed>
     */
    public function verify(string $token): array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            throw new InvalidArgumentException('Malformed Google identity token.');
        }

        $header = $this->decodeJson($parts[0]);
        $claims = $this->decodeJson($parts[1]);
        if (($header['alg'] ?? null) !== 'RS256' ||
            ! is_string($header['kid'] ?? null)) {
            throw new InvalidArgumentException('Unsupported Google identity token signature.');
        }

        $certificates = $this->certificates();
        $certificate = $certificates[$header['kid']] ?? null;
        if (! is_string($certificate)) {
            Cache::forget('google-identity-token-certificates');
            $certificates = $this->certificates();
            $certificate = $certificates[$header['kid']] ?? null;
        }
        if (! is_string($certificate)) {
            throw new InvalidArgumentException('Unknown Google signing key.');
        }

        $publicKey = openssl_pkey_get_public($certificate);
        if (! $publicKey instanceof OpenSSLAsymmetricKey) {
            throw new RuntimeException('Google signing certificate is invalid.');
        }

        $signature = $this->decodeBase64Url($parts[2]);
        $verified = openssl_verify(
            $parts[0].'.'.$parts[1],
            $signature,
            $publicKey,
            OPENSSL_ALGO_SHA256,
        );
        if ($verified !== 1) {
            throw new InvalidArgumentException('Google identity token signature is invalid.');
        }

        $this->assertClaims($claims);

        return $claims;
    }

    /**
     * @return array<string, string>
     */
    private function certificates(): array
    {
        return Cache::remember(
            'google-identity-token-certificates',
            now()->addMinutes(50),
            function (): array {
                $url = (string) config(
                    'services.google.certs_url',
                    'https://www.googleapis.com/oauth2/v1/certs',
                );
                $response = Http::timeout(5)->acceptJson()->get($url);
                $response->throw();
                $certificates = $response->json();

                if (! is_array($certificates)) {
                    throw new RuntimeException('Google certificate response is invalid.');
                }

                return $certificates;
            },
        );
    }

    /**
     * @return array<string, mixed>
     */
    private function decodeJson(string $value): array
    {
        try {
            $decoded = json_decode(
                $this->decodeBase64Url($value),
                true,
                512,
                JSON_THROW_ON_ERROR,
            );
        } catch (JsonException $exception) {
            throw new InvalidArgumentException('Google identity token JSON is invalid.', previous: $exception);
        }

        if (! is_array($decoded)) {
            throw new InvalidArgumentException('Google identity token payload is invalid.');
        }

        return $decoded;
    }

    private function decodeBase64Url(string $value): string
    {
        $normalized = strtr($value, '-_', '+/');
        $normalized .= str_repeat('=', (4 - strlen($normalized) % 4) % 4);
        $decoded = base64_decode($normalized, true);

        if (! is_string($decoded)) {
            throw new InvalidArgumentException('Google identity token encoding is invalid.');
        }

        return $decoded;
    }

    /**
     * @param  array<string, mixed>  $claims
     */
    private function assertClaims(array $claims): void
    {
        $issuer = $claims['iss'] ?? null;
        if (! in_array($issuer, [
            'accounts.google.com',
            'https://accounts.google.com',
        ], true)) {
            throw new InvalidArgumentException('Google identity token issuer is invalid.');
        }

        $allowedAudiences = config('services.google.allowed_client_ids', []);
        if (! is_array($allowedAudiences) || $allowedAudiences === []) {
            throw new RuntimeException('No Google server client ID is configured.');
        }

        $audiences = $claims['aud'] ?? [];
        $audiences = is_array($audiences) ? $audiences : [$audiences];
        if (array_intersect($allowedAudiences, $audiences) === []) {
            throw new InvalidArgumentException('Google identity token audience is invalid.');
        }

        if (isset($claims['azp']) &&
            ! in_array($claims['azp'], $allowedAudiences, true)) {
            throw new InvalidArgumentException('Google identity token authorized party is invalid.');
        }

        $now = now()->timestamp;
        if (! is_numeric($claims['exp'] ?? null) || (int) $claims['exp'] <= $now ||
            ! is_numeric($claims['iat'] ?? null) || (int) $claims['iat'] > $now + 60 ||
            (isset($claims['nbf']) && (! is_numeric($claims['nbf']) || (int) $claims['nbf'] > $now + 60))) {
            throw new InvalidArgumentException('Google identity token has expired or is not yet valid.');
        }

        if (! is_string($claims['sub'] ?? null) || trim($claims['sub']) === '' ||
            ! is_string($claims['email'] ?? null) ||
            filter_var($claims['email'], FILTER_VALIDATE_EMAIL) === false ||
            ! filter_var($claims['email_verified'] ?? false, FILTER_VALIDATE_BOOLEAN)) {
            throw new InvalidArgumentException('Google identity token account claims are invalid.');
        }
    }
}
