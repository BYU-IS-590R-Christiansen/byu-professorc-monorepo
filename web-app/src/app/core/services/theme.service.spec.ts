import { TestBed } from '@angular/core/testing';
import { THEME_STORAGE_KEY, ThemeService } from './theme.service';

describe('ThemeService', () => {
  let matchMediaSpy: jasmine.Spy;

  beforeEach(() => {
    localStorage.removeItem(THEME_STORAGE_KEY);
    document.documentElement.classList.remove('theme-light', 'theme-dark');
    matchMediaSpy = spyOn(window, 'matchMedia').and.returnValue({
      matches: false,
      media: '(prefers-color-scheme: dark)',
      onchange: null,
      addListener: () => undefined,
      removeListener: () => undefined,
      addEventListener: () => undefined,
      removeEventListener: () => undefined,
      dispatchEvent: () => false,
    } as MediaQueryList);
  });

  afterEach(() => {
    localStorage.removeItem(THEME_STORAGE_KEY);
    document.documentElement.classList.remove('theme-light', 'theme-dark');
  });

  function createService(): ThemeService {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({});
    return TestBed.inject(ThemeService);
  }

  it('defaults to light mode and applies the html class when nothing is stored', () => {
    const service = createService();

    expect(service.theme()).toBe('light');
    expect(document.documentElement.classList.contains('theme-light')).toBeTrue();
    expect(document.documentElement.classList.contains('theme-dark')).toBeFalse();
  });

  it('restores a saved dark theme from localStorage', () => {
    localStorage.setItem(THEME_STORAGE_KEY, 'dark');

    const service = createService();

    expect(service.theme()).toBe('dark');
    expect(document.documentElement.classList.contains('theme-dark')).toBeTrue();
    expect(matchMediaSpy).not.toHaveBeenCalled();
  });

  it('toggles between light and dark and persists the choice', () => {
    const service = createService();

    service.toggle();

    expect(service.theme()).toBe('dark');
    expect(localStorage.getItem(THEME_STORAGE_KEY)).toBe('dark');
    expect(document.documentElement.classList.contains('theme-dark')).toBeTrue();
    expect(document.documentElement.classList.contains('theme-light')).toBeFalse();

    service.toggle();

    expect(service.theme()).toBe('light');
    expect(localStorage.getItem(THEME_STORAGE_KEY)).toBe('light');
    expect(document.documentElement.classList.contains('theme-light')).toBeTrue();
    expect(document.documentElement.classList.contains('theme-dark')).toBeFalse();
  });
});
