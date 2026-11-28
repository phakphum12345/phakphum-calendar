<?php

namespace App\Services\Notifications;

use RuntimeException;

final class WebPushPayloadEncryptor
{
    /**
     * @return array{body: string, server_public_key: string}
     */
    public function encrypt(
        string $payload,
        string $clientPublicKey,
        string $authSecret,
    ): array {
        $userPublicKey = $this->decodeBase64Url($clientPublicKey);
        $userAuthSecret = $this->decodeBase64Url($authSecret);
        if (
            $userPublicKey === false
            || strlen($userPublicKey) !== 65
            || $userPublicKey[0] !== "\x04"
            || $userAuthSecret === false
            || strlen($userAuthSecret) !== 16
        ) {
            throw new RuntimeException('Invalid Web Push subscription key material.');
        }

        $serverPrivateKey = openssl_pkey_new([
            'private_key_type' => OPENSSL_KEYTYPE_EC,
            'curve_name' => 'prime256v1',
        ]);
        if ($serverPrivateKey === false) {
            throw new RuntimeException('Could not create an ephemeral Web Push key.');
        }

        $details = openssl_pkey_get_details($serverPrivateKey);
        $ec = $details['ec'] ?? null;
        if (
            is_array($ec) === false
            || isset($ec['x'], $ec['y']) === false
            || strlen($ec['x']) !== 32
            || strlen($ec['y']) !== 32
        ) {
            throw new RuntimeException('The ephemeral Web Push key is invalid.');
        }

        $serverPublicKey = "\x04".$ec['x'].$ec['y'];
        $userKey = openssl_pkey_get_public($this->publicKeyPem($userPublicKey));
        if ($userKey === false) {
            throw new RuntimeException('Could not read the browser Web Push public key.');
        }

        $sharedSecret = openssl_pkey_derive($userKey, $serverPrivateKey, 32);
        if ($sharedSecret === false || strlen($sharedSecret) !== 32) {
            throw new RuntimeException('Could not derive the Web Push shared secret.');
        }

        $keyPrk = $this->hkdfExtract($userAuthSecret, $sharedSecret);
        $keyInfo = "WebPush: info\0".$userPublicKey.$serverPublicKey;
        $inputKeyMaterial = $this->hkdfExpand($keyPrk, $keyInfo, 32);

        $salt = random_bytes(16);
        $prk = $this->hkdfExtract($salt, $inputKeyMaterial);
        $contentEncryptionKey = $this->hkdfExpand(
            $prk,
            "Content-Encoding: aes128gcm\0",
            16,
        );
        $nonce = $this->hkdfExpand(
            $prk,
            "Content-Encoding: nonce\0",
            12,
        );

        // RFC 8291 uses the 0x02 final-record delimiter for aes128gcm.
        $ciphertext = openssl_encrypt(
            $payload."\x02",
            'aes-128-gcm',
            $contentEncryptionKey,
            OPENSSL_RAW_DATA,
            $nonce,
            $tag,
            '',
            16,
        );
        if ($ciphertext === false || strlen($tag) !== 16) {
            throw new RuntimeException('Could not encrypt the Web Push payload.');
        }

        $recordSize = 4096;
        $body = $salt
            .pack('N', $recordSize)
            .chr(strlen($serverPublicKey))
            .$serverPublicKey
            .$ciphertext
            .$tag;

        return [
            'body' => $body,
            'server_public_key' => $serverPublicKey,
        ];
    }

    private function publicKeyPem(string $uncompressedPoint): string
    {
        $der = hex2bin('3059301306072a8648ce3d020106082a8648ce3d030107034200')
            .$uncompressedPoint;

        return "-----BEGIN PUBLIC KEY-----\n"
            .chunk_split(base64_encode($der), 64, "\n")
            ."-----END PUBLIC KEY-----\n";
    }

    private function decodeBase64Url(string $value): string|false
    {
        $base64 = strtr($value, '-_', '+/');
        $base64 .= str_repeat('=', (4 - strlen($base64) % 4) % 4);

        return base64_decode($base64, true);
    }

    private function hkdfExtract(string $salt, string $inputKeyMaterial): string
    {
        return hash_hmac('sha256', $inputKeyMaterial, $salt, true);
    }

    private function hkdfExpand(string $prk, string $info, int $length): string
    {
        $output = '';
        $previous = '';
        $counter = 1;

        while (strlen($output) < $length) {
            $previous = hash_hmac(
                'sha256',
                $previous.$info.chr($counter),
                $prk,
                true,
            );
            $output .= $previous;
            $counter++;
        }

        return substr($output, 0, $length);
    }
}
