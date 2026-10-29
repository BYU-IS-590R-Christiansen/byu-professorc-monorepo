import { Component, inject, signal, OnInit, computed } from '@angular/core';
import { Router, RouterModule, RouterOutlet } from '@angular/router';
import { CommonModule } from '@angular/common';
import { AuthStore } from './core/stores/auth.store';
import { UserStore } from './core/stores/user.store';
import { UserService } from './core/services/user.service';
import {
  FormBuilder,
  FormGroup,
  Validators,
  ReactiveFormsModule,
} from '@angular/forms';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatMenuModule } from '@angular/material/menu';
import { MatDialogModule } from '@angular/material/dialog';
import { MatDividerModule } from '@angular/material/divider';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { LoginComponent } from './auth/login/login.component';
import {
  apiErrorMessage,
  imageTooLargeMessage,
  isImageTooLarge,
} from './core/utils/image-upload.utils';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [
    RouterModule,
    RouterOutlet,
    CommonModule,
    ReactiveFormsModule,
    MatToolbarModule,
    MatButtonModule,
    MatIconModule,
    MatMenuModule,
    MatDialogModule,
    MatDividerModule,
    MatFormFieldModule,
    MatInputModule,
    MatProgressSpinnerModule,
    MatSnackBarModule,
    LoginComponent,
  ],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss',
})
export class AppComponent implements OnInit {
  private authStore = inject(AuthStore);
  protected userStore = inject(UserStore);
  private userService = inject(UserService);
  private router = inject(Router);
  private fb = inject(FormBuilder);
  private snackBar = inject(MatSnackBar);

  theme = signal<'light' | 'dark'>('dark');
  profileDialog = signal(false);
  profileIsUploading = signal(false);
  verificationEmailLoading = signal(false);
  showEmailNotVerifiedDialog = signal(false);
  showChangeEmailTextField = signal(false);
  successVerificationMessage = signal('');

  changeEmailForm: FormGroup;
  changeEmail = signal('');

  profile = signal({
    name: '',
    avatar: '',
    icon: 'mdi-account-circle',
    color: 'info',
  });

  private hasLoadedUser = signal(false);

  shouldLoadUser = computed(() => {
    const isAuthenticated = this.authStore.isAuthenticated();
    const user = this.authStore.user();
    const hasLoaded = this.hasLoadedUser();
    return isAuthenticated && user && !hasLoaded;
  });

  constructor() {
    this.changeEmailForm = this.fb.group({
      email: [
        '',
        [Validators.required, Validators.minLength(3), Validators.email],
      ],
    });
  }

  ngOnInit(): void {
    if (this.shouldLoadUser()) {
      this.hasLoadedUser.set(true);
      this.getCurrentUser();
    }
  }

  get isAuthenticated() {
    return this.authStore.isAuthenticated();
  }

  get user() {
    return this.authStore.user();
  }

  get avatarURL() {
    return this.authStore.avatar();
  }

  get title() {
    const userName = this.authStore.userName();
    return userName ? `Welcome ${userName}!` : 'Welcome!';
  }

  changeTheme(): void {
    this.theme.set(this.theme() === 'light' ? 'dark' : 'light');
  }

  logout(): void {
    this.hasLoadedUser.set(false);
    this.authStore.logout();
    this.router.navigate(['/login']);
  }

  getCurrentUser(): void {
    const user = this.user;
    if (!user) return;

    this.profile.set({
      ...this.profile(),
      name: user.name || '',
    });

    this.userService.getUser().subscribe({
      next: (response) => {
        if (response.results.avatar) {
          this.authStore.updateAvatar(response.results.avatar);
        }
        if (!response.results.email_verified_at) {
          this.showEmailNotVerifiedDialog.set(true);
        }
        this.userStore.setUser(response.results);
      },
      error: () => {
        this.logout();
      },
    });
  }

  onAvatarChange(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (!input.files || input.files.length === 0) return;

    const file = input.files[0];
    if (isImageTooLarge(file)) {
      this.snackBar.open(imageTooLargeMessage(), 'Close', {
        duration: 5000,
        horizontalPosition: 'center',
        verticalPosition: 'top',
        panelClass: ['error-snackbar'],
      });
      input.value = '';
      return;
    }

    this.profileIsUploading.set(true);
    this.userService.uploadAvatar(file).subscribe({
      next: (response) => {
        this.authStore.updateAvatar(response.results.avatar);
        this.profileIsUploading.set(false);
      },
      error: (error) => {
        this.snackBar.open(
          apiErrorMessage(error, 'Error. Try again'),
          'Close',
          {
            duration: 5000,
            horizontalPosition: 'center',
            verticalPosition: 'top',
            panelClass: ['error-snackbar'],
          },
        );
        this.profileIsUploading.set(false);
      },
    });
  }

  removeAvatar(): void {
    this.profileIsUploading.set(true);
    this.userService.removeAvatar().subscribe({
      next: (response) => {
        this.authStore.updateAvatar(null);
        this.profileIsUploading.set(false);
      },
      error: () => {
        this.snackBar.open('Error. Try again', 'Close', {
          duration: 5000,
          horizontalPosition: 'center',
          verticalPosition: 'top',
          panelClass: ['error-snackbar'],
        });
        this.profileIsUploading.set(false);
      },
    });
  }

  sendVerificationEmail(): void {
    const user = this.userStore.user();
    if (!user) return;

    this.verificationEmailLoading.set(true);
    this.successVerificationMessage.set('');

    this.userService.sendVerificationEmail({ email: user.email }).subscribe({
      next: (response: any) => {
        this.successVerificationMessage.set(
          response.message || 'Verification email sent!'
        );
        this.verificationEmailLoading.set(false);
      },
      error: () => {
        this.snackBar.open('Error. Try again', 'Close', {
          duration: 5000,
          horizontalPosition: 'center',
          verticalPosition: 'top',
          panelClass: ['error-snackbar'],
        });
        this.verificationEmailLoading.set(false);
      },
    });
  }

  changeProfileEmail(): void {
    if (!this.changeEmailForm.valid) return;

    this.verificationEmailLoading.set(true);
    const changeEmailData = {
      change_email: this.changeEmailForm.value.email,
    };

    this.userService.changeEmail(changeEmailData).subscribe({
      next: () => {
        this.snackBar.open('Email changed. Check email to verify.', 'Close', {
          duration: 5000,
          horizontalPosition: 'center',
          verticalPosition: 'top',
        });
        this.verificationEmailLoading.set(false);
        this.showChangeEmailTextField.set(false);
      },
      error: () => {
        this.snackBar.open('Error. Try again', 'Close', {
          duration: 5000,
          horizontalPosition: 'center',
          verticalPosition: 'top',
          panelClass: ['error-snackbar'],
        });
        this.verificationEmailLoading.set(false);
      },
    });
  }

  openProfileDialog(): void {
    // Will be handled by template
    this.profileDialog.set(true);
  }
}
