<?php

namespace Tests\Unit;

use App\Services\Notifications\WebPushPayloadEncryptor;
use Tests\TestCase;

class WebPushPayloadEncryptorTest extends TestCase
{
    public function test_payload_uses_rfc8291_aes128gcm_record_and_can_be_decrypted(): void
    {
        $clientPrivateKey = openssl_pkey_new([
            'private_key_type' => OPENSSL_KEYTYPE_EC,
            'curve_name' => 'prime256v1',
        ]);
        $this->assertNotFalse($clientPrivateKey);
        $details = openssl_pkey_get_details($clientPrivateKey);
        $ec = $details['ec'];
        $clientPublicKey = "\x04".$ec['x'].$ec['y'];
        $authSecret = random_bytes(16);
        $encode = static fn (string $value): string => rtrim(
            strtr(base64_encode($value), '+/', '-_'),
            '=',
        );
        $payload = json_encode([
            'title' => 'Shift request approved',
            'body' => 'A participant approved the request.',
        ], JSON_THROW_ON_ERROR);

        $encrypted = app(WebPushPayloadEncryptor::class)->encrypt(
            $payload,
            $encode($clientPublicKey),
            $encode($authSecret),
        );

        $body = $encrypted['body'];
        $this->assertGreaterThan(16 + 4 + 1 + 65 + 16, strlen($body));
        $salt = substr($body, 0, 16);
        $this->assertSame(4096, unpack('N', substr($body, 16, 4))[1]);
        $keyLength = ord($body[20]);
        $this->assertSame(65, $keyLength);
        $serverPublicKey = substr($body, 21, $keyLength);
        $this->assertSame("\x04", $serverPublicKey[0]);
        $ciphertextAndTag = substr($body, 21 + $keyLength);
        $tag = substr($ciphertextAndTag, -16);
        $ciphertext = substr($ciphertextAndTag, 0, -16);

        $serverPublicPem = $this->publicKeyPem($serverPublicKey);
        $serverPublic = openssl_pkey_get_public($serverPublicPem);
        $sharedSecret = openssl_pkey_derive($serverPublic, $clientPrivateKey, 32);
        $this->assertNotFalse($sharedSecret);

        $keyPrk = hash_hmac('sha256', $sharedSecret, $authSecret, true);
        $inputKeyMaterial = $this->hkdfExpand(
            $keyPrk,
            "WebPush: info\0".$clientPublicKey.$serverPublicKey,
            32,
        );
        $prk = hash_hmac('sha256', $inputKeyMaterial, $salt, true);
        $cek = $this->hkdfExpand($prk, "Content-Encoding: aes128gcm\0", 16);
        $nonce = $this->hkdfExpand($prk, "Content-Encoding: nonce\0", 12);
        $plaintext = openssl_decrypt(
            $ciphertext,
            'aes-128-gcm',
            $cek,
            OPENSSL_RAW_DATA,
            $nonce,
            $tag,
        );

        $this->assertSame($payload."\x02", $plaintext);
    }

    private function publicKeyPem(string $uncompressedPoint): string
    {
        $der = hex2bin('3059301306072a8648ce3d020106082a8648ce3d030107034200')
            .$uncompressedPoint;

        return "-----BEGIN PUBLIC KEY-----\n"
            .chunk_split(base64_encode($der), 64, "\n")
            ."-----END PUBLIC KEY-----\n";
    }

    private function hkdfExpand(string $prk, string $info, int $length): string
    {
        $output = '';
        $previous = '';
        for ($counter = 1; strlen($output) < $length; $counter++) {
            $previous = hash_hmac(
                'sha256',
                $previous.$info.chr($counter),
                $prk,
                true,
            );
            $output .= $previous;
        }

        return substr($output, 0, $length);
    }
}

