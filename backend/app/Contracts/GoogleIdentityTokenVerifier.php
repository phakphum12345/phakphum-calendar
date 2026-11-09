<?php

namespace App\Contracts;

interface GoogleIdentityTokenVerifier
{
    /**
     * @return array<string, mixed>
     */
    public function verify(string $token): array;
}
