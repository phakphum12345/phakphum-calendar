<?php

namespace App\Services\Notifications;

use RuntimeException;

final class VapidTokenGenerator
{
    public function generate(string $endpoint): string
    {
        $publicKey = trim((string) config('services.web_push.vapid_public_key'));
        $privateKey = trim((string) config('services.web_push.vapid_private_key'));
        $subject = trim((string) config('services.web_push.vapid_subject'));
        $decodedPublicKey = $this->decodeBase64Url($publicKey);
        $decodedPrivateKey = $this->decodeBase64Url($privateKey);

        if (
            $decodedPublicKey === false
            || strlen($decodedPublicKey) !== 65
            || $decodedPublicKey[0] !== "\x04"
            || $decodedPrivateKey === false
            || strlen($decodedPrivateKey) !== 32
            || $subject === ''
        ) {
            throw new WebPushConfigurationException('Web Push VAPID configuration is incomplete or invalid.');
        }

        $parts = parse_url($endpoint);
        $scheme = $parts['scheme'] ?? null;
        $host = $parts['host'] ?? null;
        if (! in_array($scheme, ['https'], true) || ! is_string($host) || $host === '') {
            throw new RuntimeException('The Web Push endpoint origin is invalid.');
        }
        $audience = 'https://'.$host;
        if (isset($parts['port']) && (int) $parts['port'] !== 443) {
            $audience .= ':'.(int) $parts['port'];
        }

        $now = time();
        $header = $this->base64UrlEncode(json_encode([
            'typ' => 'JWT',
            'alg' => 'ES256',
        ], JSON_THROW_ON_ERROR));
        $claims = $this->base64UrlEncode(json_encode([
            'aud' => $audience,
            'exp' => $now + 43200,
            'sub' => $subject,
        ], JSON_THROW_ON_ERROR));
        $signingInput = $header.'.'.$claims;

        $privatePem = $this->privateKeyPem($decodedPrivateKey, $decodedPublicKey);
        $key = openssl_pkey_get_private($privatePem);
        if ($key === false) {
            throw new WebPushConfigurationException('Could not load the Web Push VAPID private key.');
        }

        $derSignature = '';
        if (! openssl_sign($signingInput, $derSignature, $key, OPENSSL_ALGO_SHA256)) {
            throw new WebPushConfigurationException('Could not sign the Web Push VAPID token.');
        }

        return $signingInput.'.'.$this->base64UrlEncode(
            $this->derEcdsaSignatureToRaw($derSignature),
        );
    }

    private function privateKeyPem(string $privateKey, string $publicKey): string
    {
        $der = hex2bin('30770201010420')
            .$privateKey
            .hex2bin('a00a06082a8648ce3d030107a144034200')
            .$publicKey;

        return "-----BEGIN EC PRIVATE KEY-----\n"
            .chunk_split(base64_encode($der), 64, "\n")
            ."-----END EC PRIVATE KEY-----\n";
    }

    private function derEcdsaSignatureToRaw(string $der): string
    {
        $offset = 0;
        if (ord($der[$offset++]) !== 0x30) {
            throw new RuntimeException('The VAPID signature has an invalid DER sequence.');
        }
        $sequenceLength = ord($der[$offset++]);
        if (($sequenceLength & 0x80) !== 0) {
            $lengthBytes = $sequenceLength & 0x7f;
            $sequenceLength = 0;
            for ($index = 0; $index < $lengthBytes; $index++) {
                $sequenceLength = ($sequenceLength << 8) | ord($der[$offset++]);
            }
        }
        if ($sequenceLength !== strlen($der) - $offset) {
            throw new RuntimeException('The VAPID signature DER length is invalid.');
        }

        $r = $this->readDerInteger($der, $offset);
        $s = $this->readDerInteger($der, $offset);
        if ($offset !== strlen($der)) {
            throw new RuntimeException('The VAPID signature contains trailing data.');
        }

        return str_pad($r, 32, "\x00", STR_PAD_LEFT)
            .str_pad($s, 32, "\x00", STR_PAD_LEFT);
    }

    private function readDerInteger(string $der, int &$offset): string
    {
        if (ord($der[$offset++]) !== 0x02) {
            throw new RuntimeException('The VAPID signature integer is invalid.');
        }
        $length = ord($der[$offset++]);
        $value = substr($der, $offset, $length);
        $offset += $length;

        return ltrim($value, "\x00");
    }

    private function decodeBase64Url(string $value): string|false
    {
        $base64 = strtr($value, '-_', '+/');
        $base64 .= str_repeat('=', (4 - strlen($base64) % 4) % 4);

        return base64_decode($base64, true);
    }

    private function base64UrlEncode(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
