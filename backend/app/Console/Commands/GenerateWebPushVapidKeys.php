<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

final class GenerateWebPushVapidKeys extends Command
{
    protected $signature = 'notifications:vapid-keys';

    protected $description = 'Generate a P-256 VAPID key pair for a self-hosted Web Push deployment';

    public function handle(): int
    {
        $key = openssl_pkey_new([
            'private_key_type' => OPENSSL_KEYTYPE_EC,
            'curve_name' => 'prime256v1',
        ]);
        if ($key === false) {
            $this->error('Could not generate a VAPID key pair.');

            return self::FAILURE;
        }

        $details = openssl_pkey_get_details($key);
        $ec = $details['ec'] ?? null;
        if (
            ! is_array($ec)
            || ! isset($ec['d'], $ec['x'], $ec['y'])
            || strlen($ec['d']) !== 32
            || strlen($ec['x']) !== 32
            || strlen($ec['y']) !== 32
        ) {
            $this->error('The generated VAPID key material is invalid.');

            return self::FAILURE;
        }

        $encode = static fn (string $value): string => rtrim(
            strtr(base64_encode($value), '+/', '-_'),
            '=',
        );
        $publicKey = $encode("\x04".$ec['x'].$ec['y']);
        $privateKey = $encode($ec['d']);

        $this->line('WEB_PUSH_VAPID_PUBLIC_KEY='.$publicKey);
        $this->line('WEB_PUSH_VAPID_PRIVATE_KEY='.$privateKey);
        $this->warn('Store the private key only in the backend secret environment. Do not commit it or send it to the Flutter client.');

        return self::SUCCESS;
    }
}

