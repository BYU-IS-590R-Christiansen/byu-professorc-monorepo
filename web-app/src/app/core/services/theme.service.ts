import { Injectable, inject, signal } from '@angular/core';
import { DOCUMENT } from '@angular/common';

export type ThemeMode = 'light' | 'dark';

export const THEME_STORAGE_KEY = 'theme';

@Injectable({
  providedIn: 'root',
})
export class ThemeService {
  private readonly document = inject(DOCUMENT);
  private readonly themeSignal = signal<ThemeMode>(this.readInitialTheme());

  readonly theme = this.themeSignal.asReadonly();

  constructor() {
    this.apply(this.themeSignal());
  }

  toggle(): void {
    this.set(this.themeSignal() === 'light' ? 'dark' : 'light');
  }

  set(theme: ThemeMode): void {
    this.themeSignal.set(theme);
    this.persist(theme);
    this.apply(theme);
  }

  private readInitialTheme(): ThemeMode {
    const saved = this.readStoredTheme();
    if (saved) {
      return saved;
    }

    return this.prefersDark() ? 'dark' : 'light';
  }

  private readStoredTheme(): ThemeMode | null {
    try {
      const saved = this.document.defaultView?.localStorage.getItem(
        THEME_STORAGE_KEY,
      );
      return saved === 'light' || saved === 'dark' ? saved : null;
    } catch {
      return null;
    }
  }

  private persist(theme: ThemeMode): void {
    try {
      this.document.defaultView?.localStorage.setItem(
        THEME_STORAGE_KEY,
        theme,
      );
    } catch {
      // Ignore quota / private-mode failures; the in-memory theme still applies.
    }
  }

  private prefersDark(): boolean {
    return (
      this.document.defaultView?.matchMedia('(prefers-color-scheme: dark)')
        .matches ?? false
    );
  }

  private apply(theme: ThemeMode): void {
    const root = this.document.documentElement;
    root.classList.remove('theme-light', 'theme-dark');
    root.classList.add(`theme-${theme}`);
  }
}
