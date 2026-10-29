<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Str;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'avatar',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function ownedBooks(): HasMany
    {
        return $this->hasMany(Book::class);
    }

    public function books(): BelongsToMany
    {
        return $this->belongsToMany(Book::class, 'user_book_checkouts', 'user_id', 'book_id');
    }

    public function checkouts(): BelongsToMany
    {
        return $this->belongsToMany(Checkout::class, 'user_book_checkouts', 'user_id', 'checkout_id')->withPivot('book_id');
    }

    public function tokens(): MorphMany
    {
        return $this->morphMany(PersonalAccessToken::class, 'tokenable');
    }

    public function createToken(string $name, array $abilities = ['*']): PersonalAccessToken
    {
        $token = Str::random(40);
        $tokenHash = hash('sha256', $token);

        $accessToken = $this->tokens()->create([
            'name' => $name,
            'token' => $tokenHash,
            'abilities' => $abilities,
        ]);

        $accessToken->plainTextToken = $accessToken->id . '|' . $token;

        return $accessToken;
    }
}
