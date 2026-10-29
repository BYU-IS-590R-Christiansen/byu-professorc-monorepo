import { Component, HostListener, inject, OnInit, signal } from '@angular/core';
import { Router, RouterModule } from '@angular/router';
import { CommonModule } from '@angular/common';
import { AuthStore } from '../core/stores/auth.store';
import { Book, BooksService } from '../core/services/books.service';
import { BooksStore } from '../core/stores/books.store';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [
    CommonModule,
    RouterModule,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule,
  ],
  templateUrl: './home.component.html',
  styleUrl: './home.component.scss',
})
export class HomeComponent implements OnInit {
  authStore = inject(AuthStore);
  router = inject(Router);
  private booksService = inject(BooksService);
  private booksStore = inject(BooksStore);

  books = this.booksStore.books;
  selectedBook = signal<Book | null>(null);
  isLoading = signal(true);
  loadError = signal<string | null>(null);

  ngOnInit(): void {
    this.loadBooks();
  }

  loadBooks(): void {
    this.isLoading.set(true);
    this.loadError.set(null);

    this.booksService.getBooks().subscribe({
      next: (response) => {
        this.booksStore.setBooks(response.results ?? []);
        this.isLoading.set(false);
      },
      error: (error) => {
        console.error('Error fetching books:', error);
        this.loadError.set('Unable to load your books right now.');
        this.isLoading.set(false);
      },
    });
  }

  openBook(book: Book): void {
    this.selectedBook.set(book);
  }

  closeBook(): void {
    this.selectedBook.set(null);
  }

  authorNames(book: Book): string {
    if (!book.authors?.length) {
      return '';
    }

    return book.authors
      .map((author) => `${author.first_name} ${author.last_name}`.trim())
      .filter((name) => name.length > 0)
      .join(', ');
  }

  @HostListener('document:keydown.escape')
  onEscape(): void {
    this.closeBook();
  }

  logout(): void {
    this.authStore.logout();
    this.router.navigate(['/login']);
  }
}
