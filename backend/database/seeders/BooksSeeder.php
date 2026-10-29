<?php

namespace Database\Seeders;

use App\Models\Book;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class BooksSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
       
        $owner = User::where('email', env('SEED_USER_EMAIL') ?: 'test@usertest.com')->firstOrFail();

        $books = [
            [
                'genre_id' => 4,
                'name' => 'The Book of Mormon',
                'description' => 'Another Testament of Jesus Christ',
                'file' => 'images/bom.jpg',
                'checked_qty' => 0,
                'inventory_total_qty' => 10,
                'created_at' => Carbon::now(),
                'updated_at' => Carbon::now()
            ],
            [
                'genre_id' => 1,
                'name' => 'Harry Potter',
                'description' => 'The Sorcerers Stone',
                'file' => 'images/hp1.jpeg',
                'checked_qty' => 0,
                'inventory_total_qty' => 4,
                'created_at' => Carbon::now(),
                'updated_at' => Carbon::now()
            ],
            [
                'genre_id' => 1,
                'name' => 'Harry Potter',
                'description' => 'The Chamber of Secrets',
                'file' => 'images/hp2.jpeg',
                'checked_qty' => 0,
                'inventory_total_qty' => 3,
                'created_at' => Carbon::now(),
                'updated_at' => Carbon::now()
            ],
            [
                'genre_id' => 1,
                'name' => 'Harry Potter',
                'description' => 'The Prisoner of Azkaban',
                'file' => 'images/hp3.jpeg',
                'checked_qty' => 0,
                'inventory_total_qty' => 2,
                'created_at' => Carbon::now(),
                'updated_at' => Carbon::now()
            ],
            [
                'genre_id' => 3,
                'name' => 'Harry Potter',
                'description' => 'The Goblet of Fire',
                'file' => 'images/hp4.jpeg',
                'checked_qty' => 0,
                'inventory_total_qty' => 6,
                'created_at' => Carbon::now(),
                'updated_at' => Carbon::now()
            ],
            [
                'genre_id' => 1,
                'name' => 'Harry Potter',
                'description' => 'The Order of The Phoenix',
                'file' => 'images/hp5.jpeg',
                'checked_qty' => 0,
                'inventory_total_qty' => 3,
                'created_at' => Carbon::now(),
                'updated_at' => Carbon::now()
            ],
            [
                'genre_id' => 1,
                'name' => 'Harry Potter',
                'description' => 'The Half Book Prince',
                'file' => 'images/hp6.jpeg',
                'checked_qty' => 0,
                'inventory_total_qty' => 2,
                'created_at' => Carbon::now(),
                'updated_at' => Carbon::now()
            ],
            [
                'genre_id' => 2,
                'name' => 'Harry Potter',
                'description' => 'The Deathly Hallows',
                'file' => 'images/hp7.jpeg',
                'checked_qty' => 0,
                'inventory_total_qty' => 1,
                'created_at' => Carbon::now(),
                'updated_at' => Carbon::now()
            ],
            [
                'genre_id' => 1,
                'name' => 'Mistborn Book 1',
                'description' => 'The Final Empire',
                'file' => 'images/mb1.jpg',
                'checked_qty' => 0,
                'inventory_total_qty' => 2,
                'created_at' => Carbon::now(),
                'updated_at' => Carbon::now()
            ],
            [
                'genre_id' => 1,
                'name' => 'Mistborn Book 2',
                'description' => 'The Well of Ascension',
                'file' => 'images/mb2.jpg',
                'checked_qty' => 0,
                'inventory_total_qty' => 5,
                'created_at' => Carbon::now(),
                'updated_at' => Carbon::now()
            ],
            [
                'genre_id' => 2,
                'name' => 'Mistborn Book 3',
                'description' => 'The Hero of Ages',
                'file' => 'images/mb3.jpg',
                'checked_qty' => 0,
                'inventory_total_qty' => 3,
                'created_at' => Carbon::now(),
                'updated_at' => Carbon::now()
            ]
            
            

        ];
        foreach ($books as $book) {
            $book['user_id'] = $owner->id;
            Book::updateOrCreate(
                [
                    'user_id' => $owner->id,
                    'name' => $book['name'],
                    'description' => $book['description']
                ],
                $book
            );
        }
        
    }
}
