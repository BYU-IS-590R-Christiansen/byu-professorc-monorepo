<?php

namespace Tests\Feature;

use App\Models\Book;
use App\Models\Genre;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BookOwnershipTest extends TestCase
{
    use RefreshDatabase;

    public function test_index_only_returns_books_owned_by_the_authenticated_user(): void
    {
        $genre = $this->createGenre();
        $owner = User::factory()->create();
        $other = User::factory()->create();

        Book::create([
            'user_id' => $owner->id,
            'genre_id' => $genre->id,
            'name' => 'Owner Book',
            'description' => 'Mine',
            'inventory_total_qty' => 2,
        ]);
        Book::create([
            'user_id' => $other->id,
            'genre_id' => $genre->id,
            'name' => 'Harry Potter',
            'description' => 'Seeded title that must stay private',
            'inventory_total_qty' => 4,
        ]);

        $response = $this->withToken($this->tokenFor($owner))->getJson('/api/books');

        $response->assertOk()->assertJsonPath('success', true);
        $names = collect($response->json('results'))->pluck('name');
        $this->assertTrue($names->contains('Owner Book'));
        $this->assertFalse($names->contains('Harry Potter'));
    }

    public function test_user_cannot_update_or_delete_another_users_book(): void
    {
        $genre = $this->createGenre();
        $owner = User::factory()->create();
        $intruder = User::factory()->create();

        $book = Book::create([
            'user_id' => $owner->id,
            'genre_id' => $genre->id,
            'name' => 'Private Book',
            'description' => 'Do not touch',
            'inventory_total_qty' => 1,
        ]);

        $this->withToken($this->tokenFor($intruder))
            ->putJson("/api/books/{$book->id}", [
                'name' => 'Hacked',
                'description' => 'Stolen',
                'genre_id' => $genre->id,
                'inventory_total_qty' => 9,
            ])
            ->assertNotFound();

        $this->withToken($this->tokenFor($intruder))
            ->deleteJson("/api/books/{$book->id}")
            ->assertNotFound();

        $this->assertDatabaseHas('books', [
            'id' => $book->id,
            'name' => 'Private Book',
            'user_id' => $owner->id,
        ]);
    }

    public function test_created_books_are_owned_by_the_authenticated_user(): void
    {
        $genre = $this->createGenre();
        $user = User::factory()->create();

        $this->withToken($this->tokenFor($user))
            ->post('/api/books', [
                'name' => 'New Account Book',
                'description' => 'Only mine',
                'genre_id' => $genre->id,
                'inventory_total_qty' => 1,
                'generated_file_path' => 'images/demo.jpg',
            ])
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertDatabaseHas('books', [
            'name' => 'New Account Book',
            'user_id' => $user->id,
        ]);
    }

    private function createGenre(): Genre
    {
        return Genre::create([
            'name' => 'Fantasy',
            'description' => 'Fantasy',
            'world_introduction_date' => now(),
        ]);
    }

    private function tokenFor(User $user): string
    {
        return $user->createToken('test')->plainTextToken;
    }
}
