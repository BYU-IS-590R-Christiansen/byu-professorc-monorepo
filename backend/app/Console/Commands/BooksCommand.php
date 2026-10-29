<?php

namespace App\Console\Commands;

use App\Mail\BooksMail;
use App\Models\Book;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class BooksCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'report:books {--email=}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'This sends a email of all books to stakeholders';

    /**
     * Execute the console command.
     *
     * @return int
     */
    public function handle()
    {
        $sendToEmail = $this->option('email');
        if (!$sendToEmail) {
            $this->error('Email option is required');
            return Command::FAILURE;
        }

        $booksQuery = Book::where('name', 'like', 'Harry %');
        $owner = User::where('email', $sendToEmail)->first();
        if ($owner) {
            $booksQuery->where('user_id', $owner->id);
        }
        $books = $booksQuery->get();

        if ($books->count() > 0) {
            //Send one main list of all books email to management
            try {
                Mail::to($sendToEmail)->send(new BooksMail($books));
                $this->info('Books report sent successfully to ' . $sendToEmail);
            } catch (\Exception $e) {
                $this->error('Failed to send email: ' . $e->getMessage());
                Log::error('Email send failed: ' . $e->getMessage(), ['trace' => $e->getTraceAsString()]);
                return Command::FAILURE;
            }
        } else {
            $this->warn('No books found matching criteria');
        }

        return Command::SUCCESS;
    }
}

