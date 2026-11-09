<?php

namespace Tests\Fakes;

use App\Contracts\GoogleIdentityTokenVerifier;
use InvalidArgumentException;

class FakeGoogleIdentityTokenVerifier implements GoogleIdentityTokenVerifier
{
    /**
     * @param  array<string, array<string, mixed>>  $identitiesByToken
     */
    public function __construct(
        private readonly array $identitiesByToken,
    ) {}

    public function verify(string $token): array
    {
        $identity = $this->identitiesByToken[$token] ?? null;
        if (! is_array($identity)) {
            throw new InvalidArgumentException('Invalid test token.');
        }

        return $identity;
    }
}
