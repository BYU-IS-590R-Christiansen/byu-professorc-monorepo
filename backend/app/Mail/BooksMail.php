<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Collection;
use Illuminate\Support\Carbon;

class BooksMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(protected Collection $books)
    {
    }

    public function envelope(): Envelope
    {
        $count = $this->books->count();
        $label = $count === 1 ? '1 title' : "{$count} titles";

        return new Envelope(
            subject: "Your requested book inventory ({$label})",
        );
    }

    public function content(): Content
    {
        $generatedAt = Carbon::now()->timezone(config('app.timezone'))->format('F j, Y \a\t g:i A T');

        return new Content(
            view: 'mail.books-list',
            text: 'mail.books-list-text',
            with: [
                'books' => $this->books,
                'appName' => config('mail.from.name', 'BYU'),
                'appUrl' => rtrim((string) config('app.frontend_url', 'https://professorccs260.click'), '/') . '/books',
                'generatedAt' => $generatedAt,
                'titleCount' => $this->books->count(),
            ]
        );
    }

    public function attachments(): array
    {
        return [];
    }
}
