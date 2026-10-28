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
       
        $userData = [
            'name' => 'Test User',
            'email' => 'testuser@test.com',
            'email_verified_at' => Carbon::now(),
            'avatar' => null,
            // User model hashes via `password` cast; do not bcrypt here.
            'password' => 'password12345',
        ];
        
        User::updateOrCreate(
            ['email' => 'testuser@test.com'],
            $userData
        );
        
    }
}

