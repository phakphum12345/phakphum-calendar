<?php

namespace App\Providers;

use App\Contracts\GoogleIdentityTokenVerifier;
use App\Services\Google\GoogleCertificateIdentityTokenVerifier;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(
            GoogleIdentityTokenVerifier::class,
            GoogleCertificateIdentityTokenVerifier::class,
        );
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
