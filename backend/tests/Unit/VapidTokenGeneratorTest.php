<?php

namespace Tests\Unit;

use App\Services\Notifications\VapidTokenGenerator;
use Tests\TestCase;

class VapidTokenGeneratorTest extends TestCase
{
    public function test_vapid_token_uses_endpoint_origin_and_valid_es256_signature(): void
    {
        $privateKey = openssl_pkey_new([
            'private_key_type' => OPENSSL_KEYTYPE_EC,
            'curve_name' => 'prime256v1',
        ]);
        $this->assertNotFalse($privateKey);
        $details = openssl_pkey_get_details($privateKey);
        $ec = $details['ec'];
        $publicKey = "\x04".$ec['x'].$ec['y'];
        $encode = static fn (string $value): string => rtrim(
            strtr(base64_encode($value), '+/', '-_'),
            '=',
        );
        config([
            'services.web_push.vapid_public_key' => $encode($publicKey),
            'services.web_push.vapid_private_key' => $encode($ec['d']),
            'services.web_push.vapid_subject' => 'mailto:push@example.test',
        ]);

        $token = app(VapidTokenGenerator::class)->generate(
            'https://fcm.googleapis.com/fcm/send/example',
        );
        $parts = explode('.', $token);
        $this->assertCount(3, $parts);
        $header = json_decode($this->decodeBase64Url($parts[0]), true, 512, JSON_THROW_ON_ERROR);
        $claims = json_decode($this->decodeBase64Url($parts[1]), true, 512, JSON_THROW_ON_ERROR);
        $signature = $this->decodeBase64Url($parts[2]);

        $this->assertSame('ES256', $header['alg']);
        $this->assertSame('https://fcm.googleapis.com', $claims['aud']);
        $this->assertSame('mailto:push@example.test', $claims['sub']);
        $this->assertGreaterThan(time(), $claims['exp']);
        $this->assertLessThanOrEqual(time() + 43200, $claims['exp']);
        $this->assertSame(64, strlen($signature));

        $derSignature = $this->rawSignatureToDer($signature);
        $publicPem = $this->publicKeyPem($publicKey);
        $this->assertSame(
            1,
            openssl_verify($parts[0].'.'.$parts[1], $derSignature, $publicPem, OPENSSL_ALGO_SHA256),
        );
    }

    private function decodeBase64Url(string $value): string
    {
        $base64 = strtr($value, '-_', '+/');
        $base64 .= str_repeat('=', (4 - strlen($base64) % 4) % 4);

        return base64_decode($base64, true);
    }

    private function publicKeyPem(string $uncompressedPoint): string
    {
        $der = hex2bin('3059301306072a8648ce3d020106082a8648ce3d030107034200')
            .$uncompressedPoint;

        return "-----BEGIN PUBLIC KEY-----\n"
            .chunk_split(base64_encode($der), 64, "\n")
            ."-----END PUBLIC KEY-----\n";
    }

    private function rawSignatureToDer(string $signature): string
    {
        $r = ltrim(substr($signature, 0, 32), "\x00");
        $s = ltrim(substr($signature, 32, 32), "\x00");
        if ((ord($r[0]) & 0x80) !== 0) {\n            $r = "\x00".$r;\n        }
        if ((ord($s[0]) & 0x80) !== 0) {\n            $s = "\x00".$s;\n        }
        $body = "\x02".chr(strlen($r)).$r."\x02".chr(strlen($s)).$s;

        return "\x30".chr(strlen($body)).$body;
    }
}
