<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('books', function (Blueprint $table) {
            $table->foreignId('user_id')
                ->nullable()
                ->after('id')
                ->constrained('users')
                ->cascadeOnDelete();
        });

        $ownerId = DB::table('users')->where('email', env('SEED_USER_EMAIL') ?: 'test@usertest.com')->value('id')
            ?? DB::table('users')->orderBy('id')->value('id');

        if ($ownerId) {
            DB::table('books')->whereNull('user_id')->update(['user_id' => $ownerId]);
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('books', function (Blueprint $table) {
            $table->dropConstrainedForeignId('user_id');
        });
    }
};
