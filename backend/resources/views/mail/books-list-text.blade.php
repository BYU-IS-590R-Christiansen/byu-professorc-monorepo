Your requested book inventory

{{ $appName }}
Prepared {{ $generatedAt }}
{{ $titleCount }} {{ $titleCount === 1 ? 'title' : 'titles' }}

This is the catalog summary you requested. It includes the titles currently in your library and how many copies are on the shelf.

@foreach ($books as $book)
@php
    $total = (int) $book->inventory_total_qty;
    $available = max($total - (int) $book->checked_qty, 0);
    $genre = $book->genre->name ?? 'Uncategorized';
@endphp
- {{ $book->name }}
  {{ $book->description }}
  Genre: {{ $genre }}
  Available: {{ $available }} of {{ $total }}

@endforeach
@if ($appUrl)
Review your catalog: {{ $appUrl }}

@endif
You received this message because you asked {{ $appName }} to email a book inventory report. If you did not request it, no action is needed.
