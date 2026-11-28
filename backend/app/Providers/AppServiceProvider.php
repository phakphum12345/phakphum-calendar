<?php

namespace App\Providers;

use App\Contracts\GoogleIdentityTokenVerifier;
use App\Services\Google\GoogleCertificateIdentityTokenVerifier;
use App\Services\Notifications\WebPushSender;
use App\Services\Notifications\WebPushTransport;
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
        $this->app->bind(WebPushTransport::class, WebPushSender::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
