import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  FormBuilder,
  FormGroup,
  Validators,
  ReactiveFormsModule,
  FormsModule,
} from '@angular/forms';
import { BooksService, Book } from '../core/services/books.service';
import { BooksStore } from '../core/stores/books.store';
import {
  setFormErrors,
  clearFormErrors,
  getFieldError,
} from '../core/utils/form.utils';
import { isMobile } from '../core/utils/mobile.utils';
import {
  apiErrorMessage,
  imageTooLargeMessage,
  isImageTooLarge,
} from '../core/utils/image-upload.utils';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDialogModule } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBarModule } from '@angular/material/snack-bar';
import { MatGridListModule } from '@angular/material/grid-list';
import { MatChipsModule } from '@angular/material/chips';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';

@Component({
  selector: 'app-books',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    FormsModule,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatDialogModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatProgressSpinnerModule,
    MatSnackBarModule,
    MatGridListModule,
    MatChipsModule,
    MatSlideToggleModule,
  ],
  templateUrl: './books.component.html',
  styleUrl: './books.component.scss',
})
export class BooksComponent implements OnInit {
  private booksService = inject(BooksService);
  private booksStore = inject(BooksStore);
  private fb = inject(FormBuilder);

  books = this.booksStore.books;
  genres = this.booksStore.genres;

  dueDate = signal('');
  checkedOutBook = signal<Book | null>(null);
  editBook = signal<Partial<Book>>({});
  selectedDeleteBook = signal<Book | null>(null);

  newBookForm: FormGroup;
  editBookForm: FormGroup;

  editBookErrorMessage = signal<string | null>(null);
  newBookErrorMessage = signal<string | null>(null);
  reportSentMessage = signal<string | null>(null);

  createBookDialog = signal(false);
  deleteBookDialog = signal(false);
  editBookDialog = signal(false);
  editFileChangeDialogBtn = signal(false);

  bookIsUpdating = signal(false);
  bookIsDeleting = signal(false);
  bookIsCreating = signal(false);
  aiIsGenerating = signal(false);
  coverIsGenerating = signal(false);
  generatePhotoUsingAi = signal(false);
  selectedFile = signal<File | null>(null);
  selectedEditFile = signal<File | null>(null);
  generatedBookImageUrl = signal<string | null>(null);
  generatedBookImagePath = signal<string | null>(null);
  expandedAuthors = signal<Set<number>>(new Set());

  constructor() {
    this.newBookForm = this.fb.group({
      name: ['', [Validators.required]],
      description: ['', [Validators.required]],
      inventory_total_qty: [1, [Validators.required, Validators.min(1)]],
      genre_id: [1, [Validators.required]],
      file: [null],
    });

    this.editBookForm = this.fb.group({
      name: ['', [Validators.required]],
      description: ['', [Validators.required]],
      inventory_total_qty: [1, [Validators.required, Validators.min(1)]],
      genre_id: [1, [Validators.required]],
    });
  }

  ngOnInit(): void {
    this.getBooks();
  }

  getBooks(): void {
    this.booksService.getBooks().subscribe({
      next: (response) => {
        this.booksStore.setBooks(response.results);
      },
      error: (error) => {
        console.error('Error fetching books:', error);
      },
    });
  }

  sendReport(): void {
    this.booksService.sendReport().subscribe({
      next: () => {
        this.reportSentMessage.set('Report Sent Successfully!');
      },
      error: (error) => {
        console.error('Error sending report:', error);
      },
    });
  }

  checkoutBook(): void {
    const book = this.checkedOutBook();
    if (!book || !this.dueDate()) {
      return;
    }

    this.booksService.checkoutBook(book, this.dueDate()).subscribe({
      next: (response) => {
        this.booksStore.setBookCheckedQty(response.results.book);
        this.checkedOutBook.set(null);
        this.dueDate.set('');
      },
      error: (error) => {
        console.error('Error checking out book:', error);
      },
    });
  }

  returnBook(book: Book): void {
    this.booksService.returnBook(book).subscribe({
      next: (response) => {
        this.booksStore.setBookCheckedQty(response.results.book);
      },
      error: (error) => {
        console.error('Error returning book:', error);
      },
    });
  }

  openDeleteBookDialog(book: Book): void {
    this.selectedDeleteBook.set(book);
    this.deleteBookDialog.set(true);
  }

  openEditBookDialog(book: Book): void {
    this.editBook.set({ ...book });
    this.editBookForm.patchValue({
      name: book.name,
      description: book.description,
      inventory_total_qty: book.inventory_total_qty,
      genre_id: book.genre_id,
    });
    this.editBookDialog.set(true);
  }

  openCreateDialog(): void {
    this.newBookForm.reset({
      name: '',
      description: '',
      inventory_total_qty: 1,
      genre_id: 1,
      file: null,
    });
    this.selectedFile.set(null);
    this.generatedBookImageUrl.set(null);
    this.generatedBookImagePath.set(null);
    this.coverIsGenerating.set(false);
    this.generatePhotoUsingAi.set(false);
    this.applyFileValidation();
    this.createBookDialog.set(true);
  }

  closeCreateDialog(): void {
    this.newBookForm.reset();
    this.selectedFile.set(null);
    this.generatedBookImageUrl.set(null);
    this.generatedBookImagePath.set(null);
    this.coverIsGenerating.set(false);
    this.generatePhotoUsingAi.set(false);
    this.applyFileValidation();
    this.createBookDialog.set(false);
  }

  onGeneratePhotoToggle(checked: boolean): void {
    this.generatePhotoUsingAi.set(checked);
    this.coverIsGenerating.set(false);
    this.generatedBookImageUrl.set(null);
    this.generatedBookImagePath.set(null);
    this.selectedFile.set(null);
    this.newBookForm.patchValue({ file: null });
    this.applyFileValidation();
  }

  private applyFileValidation(): void {
    const fileControl = this.newBookForm.get('file');
    if (!fileControl) return;

    if (this.generatePhotoUsingAi()) {
      fileControl.clearValidators();
    } else {
      fileControl.setValidators([Validators.required]);
    }

    fileControl.updateValueAndValidity();
  }

  generateUsingAi(): void {
    const genreId = this.newBookForm.get('genre_id')?.value;
    this.aiIsGenerating.set(true);
    this.newBookErrorMessage.set(null);

    this.booksService.suggestBookInputs(genreId ?? null).subscribe({
      next: (response) => {
        if (response?.success && response.results) {
          const name = response.results.name;
          const description = response.results.description;

          this.newBookForm.patchValue({ name, description });

          if (this.generatePhotoUsingAi()) {
            this.coverIsGenerating.set(true);
            this.booksService
              .generateBookCoverImage({
                name,
                description,
                genre_id: genreId ?? null,
              })
              .subscribe({
                next: (genResponse) => {
                  this.generatedBookImagePath.set(
                    genResponse?.results?.file_path ?? null,
                  );
                  this.generatedBookImageUrl.set(
                    genResponse?.results?.file_url ?? null,
                  );
                  this.coverIsGenerating.set(false);
                  this.aiIsGenerating.set(false);
                },
                error: (error) => {
                  this.coverIsGenerating.set(false);
                  this.aiIsGenerating.set(false);
                  this.newBookErrorMessage.set(
                    error?.error?.message ||
                      'Error generating cover image with AI',
                  );
                },
              });
            return;
          }
        }

        this.aiIsGenerating.set(false);
      },
      error: (error) => {
        this.aiIsGenerating.set(false);
        this.newBookErrorMessage.set(
          error?.error?.message || 'Error generating AI suggestions',
        );
      },
    });
  }

  createBook(): void {
    if (!this.newBookForm.valid) {
      return;
    }

    this.bookIsCreating.set(true);
    this.newBookErrorMessage.set(null);
    clearFormErrors(this.newBookForm);

    const formValue = this.newBookForm.value;

    if (this.generatePhotoUsingAi()) {
      const genreId = formValue.genre_id ?? null;
      const name = formValue.name as string;
      const description = formValue.description as string;

      const createWithGenerated = (generatedPath: string) => {
        this.booksService
          .createBookWithGeneratedCover(formValue, generatedPath)
          .subscribe({
            next: (response) => {
              this.booksStore.addBook(response.results.book);
              this.closeCreateDialog();
              this.bookIsCreating.set(false);
            },
            error: (error) => {
              const message = apiErrorMessage(error, 'Error creating book');
              if (message.includes('too large')) {
                this.newBookErrorMessage.set(message);
              } else if (
                error?.error?.data &&
                typeof error.error.data === 'object'
              ) {
                setFormErrors(this.newBookForm, error.error.data);
                this.newBookErrorMessage.set(
                  'Please fix the validation errors below.',
                );
              } else {
                this.newBookErrorMessage.set(message);
              }
              this.bookIsCreating.set(false);
            },
          });
      };

      if (this.generatedBookImagePath()) {
        createWithGenerated(this.generatedBookImagePath()!);
        return;
      }

      this.coverIsGenerating.set(true);
      this.booksService
        .generateBookCoverImage({
          name,
          description,
          genre_id: genreId,
        })
        .subscribe({
          next: (genResponse) => {
            const generatedPath = genResponse?.results?.file_path;
            this.generatedBookImagePath.set(generatedPath ?? null);
            this.generatedBookImageUrl.set(
              genResponse?.results?.file_url ?? null,
            );
            this.coverIsGenerating.set(false);

            if (!generatedPath) {
              this.bookIsCreating.set(false);
              this.newBookErrorMessage.set(
                'Error generating cover image with AI',
              );
              return;
            }

            createWithGenerated(generatedPath);
          },
          error: (error) => {
            this.coverIsGenerating.set(false);
            this.bookIsCreating.set(false);
            this.newBookErrorMessage.set(
              error?.error?.message || 'Error generating cover image with AI',
            );
          },
        });

      return;
    }

    if (!this.selectedFile()) {
      this.bookIsCreating.set(false);
      return;
    }

    this.booksService.createBook(formValue, this.selectedFile()!).subscribe({
      next: (response) => {
        this.booksStore.addBook(response.results.book);
        this.closeCreateDialog();
        this.bookIsCreating.set(false);
      },
      error: (error) => {
        const message = apiErrorMessage(error, 'Error creating book');
        if (message.includes('too large')) {
          this.newBookErrorMessage.set(message);
        } else if (
          error?.error?.data &&
          typeof error.error.data === 'object'
        ) {
          setFormErrors(this.newBookForm, error.error.data);
          this.newBookErrorMessage.set(
            'Please fix the validation errors below.',
          );
        } else {
          this.newBookErrorMessage.set(message);
        }
        this.bookIsCreating.set(false);
      },
    });
  }

  updateBook(): void {
    if (!this.editBookForm.valid) {
      return;
    }

    this.bookIsUpdating.set(true);
    this.editBookErrorMessage.set(null);
    clearFormErrors(this.editBookForm);

    const book = { ...this.editBook(), ...this.editBookForm.value } as Book;

    if (this.selectedEditFile()) {
      this.booksService
        .updateBookPicture(book, this.selectedEditFile()!)
        .subscribe({
          next: (response) => {
            this.booksStore.updateBookPicture(response.results.book);
            this.updateBookDetails(book);
          },
          error: (error) => {
            const message = apiErrorMessage(
              error,
              'Error updating book picture',
            );
            if (message.includes('too large')) {
              this.editBookErrorMessage.set(message);
            } else if (
              error?.error?.data &&
              typeof error.error.data === 'object'
            ) {
              setFormErrors(this.editBookForm, error.error.data);
              this.editBookErrorMessage.set(
                'Please fix the validation errors below.',
              );
            } else {
              this.editBookErrorMessage.set(message);
            }
            this.bookIsUpdating.set(false);
          },
        });
    } else {
      this.updateBookDetails(book);
    }
  }

  private updateBookDetails(book: Book): void {
    this.booksService.updateBook(book).subscribe({
      next: (response) => {
        this.booksStore.setBook(response.results.book);
        this.editBookDialog.set(false);
        this.editFileChangeDialogBtn.set(false);
        this.editBook.set({});
        this.bookIsUpdating.set(false);
      },
      error: (error) => {
        if (error?.error?.data && typeof error.error.data === 'object') {
          setFormErrors(this.editBookForm, error.error.data);
          this.editBookErrorMessage.set(
            'Please fix the validation errors below.',
          );
        } else {
          this.editBookErrorMessage.set(
            error?.error?.message || 'Error updating book',
          );
        }
        this.bookIsUpdating.set(false);
      },
    });
  }

  deleteBook(): void {
    const book = this.selectedDeleteBook();
    if (!book) {
      return;
    }

    this.bookIsDeleting.set(true);
    this.booksService.deleteBook(book).subscribe({
      next: () => {
        this.booksStore.removeBook(book);
        this.selectedDeleteBook.set(null);
        this.bookIsDeleting.set(false);
        this.deleteBookDialog.set(false);
      },
      error: (error) => {
        console.error('Error deleting book:', error);
        this.bookIsDeleting.set(false);
      },
    });
  }

  onNewBookFileChange(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      const file = input.files[0];
      if (isImageTooLarge(file)) {
        this.selectedFile.set(null);
        this.newBookForm.patchValue({ file: null });
        this.newBookForm.get('file')?.updateValueAndValidity();
        this.newBookErrorMessage.set(imageTooLargeMessage());
        input.value = '';
        return;
      }
      this.newBookErrorMessage.set(null);
      this.selectedFile.set(file);
      this.newBookForm.patchValue({ file: file });
      this.newBookForm.get('file')?.updateValueAndValidity();
    } else {
      this.selectedFile.set(null);
      this.newBookForm.patchValue({ file: null });
      this.newBookForm.get('file')?.updateValueAndValidity();
    }
  }

  onExistingBookPictureChange(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      const file = input.files[0];
      if (isImageTooLarge(file)) {
        this.selectedEditFile.set(null);
        this.editBookErrorMessage.set(imageTooLargeMessage());
        input.value = '';
        return;
      }
      this.editBookErrorMessage.set(null);
      this.selectedEditFile.set(file);
    }
  }

  isMobile = isMobile;

  getFieldError = getFieldError;

  toggleAuthors(bookId: number): void {
    const expanded = new Set(this.expandedAuthors());
    if (expanded.has(bookId)) {
      expanded.delete(bookId);
    } else {
      expanded.add(bookId);
    }
    this.expandedAuthors.set(expanded);
  }

  isAuthorsExpanded(bookId: number): boolean {
    return this.expandedAuthors().has(bookId);
  }
}
