<?php

namespace Tests\Unit;

use App\Services\Google\GoogleCertificateIdentityTokenVerifier;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use InvalidArgumentException;
use OpenSSLAsymmetricKey;
use OpenSSLCertificate;
use Tests\TestCase;

class GoogleCertificateIdentityTokenVerifierTest extends TestCase
{
    private OpenSSLAsymmetricKey $privateKey;

    private string $certificate;

    protected function setUp(): void
    {
        parent::setUp();

        $privateKey = openssl_pkey_new([
            'private_key_type' => OPENSSL_KEYTYPE_RSA,
            'private_key_bits' => 2048,
        ]);
        $this->assertInstanceOf(OpenSSLAsymmetricKey::class, $privateKey);
        $this->privateKey = $privateKey;

        $request = openssl_csr_new(
            ['commonName' => 'Google test certificate'],
            $this->privateKey,
            ['digest_alg' => 'sha256'],
        );
        $this->assertNotFalse($request);

        $certificate = openssl_csr_sign(
            $request,
            null,
            $this->privateKey,
            365,
            ['digest_alg' => 'sha256'],
        );
        $this->assertInstanceOf(OpenSSLCertificate::class, $certificate);
        $this->assertTrue(openssl_x509_export($certificate, $certificatePem));
        $this->certificate = $certificatePem;

        config([
            'services.google.allowed_client_ids' => ['server-client-id'],
            'services.google.certs_url' => 'https://www.googleapis.com/oauth2/v1/certs',
        ]);
        Cache::flush();
        Http::fake([
            'https://www.googleapis.com/oauth2/v1/certs' => Http::response([
                'test-key' => $this->certificate,
            ], 200),
        ]);
    }

    public function test_it_verifies_signature_and_google_identity_claims(): void
    {
        $claims = app(GoogleCertificateIdentityTokenVerifier::class)->verify($this->token());

        $this->assertSame('google-subject', $claims['sub']);
        $this->assertSame('person@example.com', $claims['email']);
    }

    public function test_it_rejects_an_unapproved_audience(): void
    {
        $this->expectException(InvalidArgumentException::class);

        app(GoogleCertificateIdentityTokenVerifier::class)->verify(
            $this->token(['aud' => 'unapproved-client']),
        );
    }

    public function test_it_rejects_an_expired_token(): void
    {
        $this->expectException(InvalidArgumentException::class);

        app(GoogleCertificateIdentityTokenVerifier::class)->verify(
            $this->token(['exp' => now()->subMinute()->timestamp]),
        );
    }

    public function test_it_rejects_an_invalid_signature(): void
    {
        $parts = explode('.', $this->token());
        $parts[2] = $this->base64Url('invalid-signature');

        $this->expectException(InvalidArgumentException::class);
        app(GoogleCertificateIdentityTokenVerifier::class)->verify(implode('.', $parts));
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function token(array $overrides = []): string
    {
        $claims = array_merge([
            'iss' => 'https://accounts.google.com',
            'aud' => 'server-client-id',
            'exp' => now()->addHour()->timestamp,
            'iat' => now()->timestamp,
            'sub' => 'google-subject',
            'email' => 'person@example.com',
            'email_verified' => true,
            'name' => 'Person',
        ], $overrides);

        $header = $this->base64Url(json_encode([
            'alg' => 'RS256',
            'kid' => 'test-key',
        ], JSON_THROW_ON_ERROR));
        $payload = $this->base64Url(json_encode($claims, JSON_THROW_ON_ERROR));
        $signingInput = $header.'.'.$payload;
        $this->assertTrue(openssl_sign(
            $signingInput,
            $signature,
            $this->privateKey,
            OPENSSL_ALGO_SHA256,
        ));

        return $signingInput.'.'.$this->base64Url($signature);
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
