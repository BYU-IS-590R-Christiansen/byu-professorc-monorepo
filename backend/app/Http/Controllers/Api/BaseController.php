<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Log;

class BaseController extends Controller
{
    public function sendResponse($result, $message)
    {
        $response = [
            'success' => true,
            'results' => $result,
            'message' => $message,
        ];



        return response()->json($response, 200);
    }

    public function sendError($error, $errorMessages = [], $code = 404)
    {
        $response = [
            'success' => false,
            'message' => $error,
        ];

        if (!empty($errorMessages)) {
            $response['data'] = $errorMessages;
        }

        return response()->json($response, $code);
    }

    /**
     * Resolve a stored file path to a URL. Uses local storage (demo images) when
     * FILESYSTEM_DISK=local or S3 is not configured; otherwise uses S3.
     *
     * @param string|null $path Storage path (e.g. "images/hp1.jpeg")
     * @param int|null $minutes Minutes for S3 temporary URL (null = public URL)
     * @return string|null
     */
    public function getS3Url($path, $minutes = 10)
    {
        if (!$path) {
            return null;
        }

        // Local: serve from storage/app/public (e.g. demo images from backend/public/assets/books)
        if ($this->useLocalStorageForImages()) {
            if (Storage::disk('public')->exists($path)) {
                return asset('storage/' . $path);
            }
            return null;
        }

        /** @var \Illuminate\Filesystem\FilesystemAdapter $s3 */
        $s3 = Storage::disk('s3');
        try {
            if ($s3->exists($path)) {
                if ($minutes === null) {
                    $s3->setVisibility($path, "public");
                    // @phpstan-ignore-next-line - url() method exists on S3 adapter at runtime
                    return $s3->url($path);
                }
                // @phpstan-ignore-next-line - temporaryUrl() method exists on S3 adapter at runtime
                return $s3->temporaryUrl($path, now()->addMinutes($minutes));
            }
        } catch (\Exception $e) {
            Log::error('S3 URL generation failed: ' . $e->getMessage());
            return null;
        }

        return null;
    }

    /**
     * Whether to resolve image URLs from local storage (public disk) instead of S3.
     */
    protected function useLocalStorageForImages(): bool
    {
        if (in_array(config('filesystems.default'), ['local', 'development', 'dev'], true)) {
            return true;
        }
        $key = config('filesystems.disks.s3.key');
        $bucket = config('filesystems.disks.s3.bucket');
        return empty($key) || empty($bucket);
    }

    protected function uploadMaxBytes(): int
    {
        $uploadMax = $this->iniSizeToBytes((string) ini_get('upload_max_filesize'));
        $postMax = $this->iniSizeToBytes((string) ini_get('post_max_size'));
        $limit = min($uploadMax, $postMax);
        return $limit > 0 ? $limit : 2 * 1024 * 1024;
    }

    protected function uploadMaxKilobytes(): int
    {
        return max(1, (int) floor($this->uploadMaxBytes() / 1024));
    }

    protected function uploadMaxLabel(): string
    {
        $mb = $this->uploadMaxBytes() / 1048576;
        if (abs($mb - round($mb)) < 0.05) {
            return ((int) round($mb)).' MB';
        }

        return rtrim(rtrim(number_format($mb, 1, '.', ''), '0'), '.').' MB';
    }

    protected function imageTooLargeMessage(): string
    {
        return 'The image is too large. Maximum size is '.$this->uploadMaxLabel().'.';
    }

    protected function rejectOversizedUpload(Request $request, string $field): ?JsonResponse
    {
        $message = $this->imageTooLargeMessage();
        $contentLength = (int) $request->server('CONTENT_LENGTH', 0);
        $limit = $this->uploadMaxBytes();

        if ($contentLength > $limit && count($request->allFiles()) === 0) {
            return $this->sendError($message, [$field => [$message]], 422);
        }

        $file = $request->file($field);
        if ($file && ! $file->isValid()) {
            $error = $file->getError();
            if (in_array($error, [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true) || $contentLength > $limit) {
                return $this->sendError($message, [$field => [$message]], 422);
            }
        }

        return null;
    }

    protected function iniSizeToBytes(string $value): int
    {
        $value = trim($value);
        if ($value === '' || $value === '0' || $value === '-1') {
            return 2 * 1024 * 1024;
        }

        $unit = strtolower(substr($value, -1));
        $number = (float) $value;

        return (int) match ($unit) {
            'g' => $number * 1024 * 1024 * 1024,
            'm' => $number * 1024 * 1024,
            'k' => $number * 1024,
            default => $number,
        };
    }
}

