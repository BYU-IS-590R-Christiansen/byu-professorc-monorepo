<?php

namespace Database\Seeders;

use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class UsersSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $email = env('SEED_USER_EMAIL') ?: 'test@usertest.com';
        $password = env('SEED_USER_PASSWORD') ?: bin2hex(random_bytes(64));

        $userData = [
            'name' => env('SEED_USER_NAME') ?: 'Test User',
            'email' => $email,
            'email_verified_at' => Carbon::now(),
            'avatar' => null,
            // User model hashes via `password` cast; do not bcrypt here.
            'password' => $password,
        ];

        User::updateOrCreate(
            ['email' => $email],
            $userData
        );
    }
}

