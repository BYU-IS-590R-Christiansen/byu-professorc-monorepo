export const MAX_IMAGE_UPLOAD_BYTES = 2 * 1024 * 1024;
export const MAX_IMAGE_UPLOAD_LABEL = '2 MB';

export function imageTooLargeMessage(
  maxLabel = MAX_IMAGE_UPLOAD_LABEL,
): string {
  return `The image is too large. Maximum size is ${maxLabel}.`;
}

export function isImageTooLarge(file: File): boolean {
  return file.size > MAX_IMAGE_UPLOAD_BYTES;
}

export function apiErrorMessage(error: unknown, fallback: string): string {
  const body = (error as { error?: Record<string, unknown> } | undefined)
    ?.error;
  const message = typeof body?.['message'] === 'string' ? body['message'] : '';
  if (message) {
    if (/failed to upload/i.test(message)) {
      return imageTooLargeMessage();
    }
    return message;
  }

  const data = body?.['data'];
  if (data && typeof data === 'object') {
    const first = Object.values(data as Record<string, unknown>)
      .flat()
      .find((value) => typeof value === 'string');
    if (typeof first === 'string') {
      return /failed to upload/i.test(first)
        ? imageTooLargeMessage()
        : first;
    }
  }

  return fallback;
}
