<?php

namespace App\Http\Controllers\Api;

use App\Models\Book;
use App\Models\Checkout;
use App\Models\Genre;
use App\Models\User;
use Illuminate\Http\Client\Response as HttpResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;

class BookController extends BaseController
{
    /**
     * Generate and upload a book cover image via Gemini/Imagen, returning both
     * the storage path and a URL suitable for the frontend preview.
     */
    public function generateCoverImage(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:60',
            'description' => 'required|string|max:250',
            'genre_id' => 'nullable|integer|exists:genres,id',
        ]);

        if ($validator->fails()) {
            return $this->sendError('Validation Error.', $validator->errors());
        }

        $apiKey = env('GEMINI_API_KEY');
        if (empty($apiKey)) {
            return $this->sendError(
                'Gemini API key is not configured on the server.',
                [],
                500
            );
        }

        $model = env('GEMINI_IMAGE_MODEL', 'imagen-4.0-generate-001');

        $name = (string) $request->input('name');
        $description = (string) $request->input('description');
        $genreName = null;
        $genreId = $request->input('genre_id');
        if (! empty($genreId)) {
            $genreName = Genre::find($genreId)?->name;
        }

        $genreClause = $genreName ? "Genre: '{$genreName}'. " : '';

        // We do NOT request readable text on the cover, since that can produce gibberish.
        // The app already displays the actual `book.name`.
        $prompt = "Create a square, high-quality book cover image for a library inventory app. " .
            "Title (do not include readable text): '{$name}'. " .
            $genreClause .
            "Book description: '{$description}'. " .
            "Style: modern, visually appealing, sharp focal subject, realistic lighting. " .
            "IMPORTANT: Do not include any readable letters, numbers, or words. No typography. " .
            "No logos or watermarks other than the provider's AI watermark.";

        $endpoint =
            "https://generativelanguage.googleapis.com/v1beta/models/{$model}:predict";

        try {
            /** @var HttpResponse $response */
            $response = Http::withHeaders([
                'x-goog-api-key' => $apiKey,
                'Content-Type' => 'application/json',
            ])->timeout(60)->post($endpoint, [
                'instances' => [
                    ['prompt' => $prompt],
                ],
                'parameters' => [
                    'sampleCount' => 1,
                    'aspectRatio' => '1:1',
                ],
            ]);

            if (! $response->successful()) {
                Log::warning('Gemini image generation failed', [
                    'status' => $response->status(),
                    'body' => $response->body(),
                ]);
                return $this->sendError('Failed to generate book cover image.', [], 500);
            }

            $payload = $response->json();

            // Gemini Imagen responses can vary a bit by SDK/version. Normalize to:
            // - base64 image bytes in `image.imageBytes`
            // - or a hosted URL in `url`
            $predictions = $payload['predictions'] ?? null;
            if (is_array($predictions) && ! empty($predictions)) {
                $firstPrediction = $predictions[0] ?? null;
                if (is_array($firstPrediction) && ! empty($firstPrediction['bytesBase64Encoded'])) {
                    $imageBytesB64 = $firstPrediction['bytesBase64Encoded'];
                    $mimeType = $firstPrediction['mimeType'] ?? null;
                    $imageUrl = null;
                } elseif (is_array($firstPrediction)) {
                    // Some responses nest the base64 bytes differently.
                    $nested = $firstPrediction['image'] ?? null;
                    if (is_array($nested) && ! empty($nested['bytesBase64Encoded'])) {
                        $imageBytesB64 = $nested['bytesBase64Encoded'];
                        $mimeType = $nested['mimeType'] ?? null;
                        $imageUrl = null;
                    }
                }
            }

            $generatedImages =
                $payload['generatedImages'] ??
                $payload['generated_images'] ??
                $payload['generated_images_list'] ??
                null;

            $firstGenerated = is_array($generatedImages)
                ? ($generatedImages[0] ?? null)
                : null;

            $firstImage = null;
            if (is_array($firstGenerated)) {
                $firstImage = $firstGenerated['image'] ?? null;
            }

            // If we already populated from `predictions`, keep those; otherwise initialize.
            $imageBytesB64 = $imageBytesB64 ?? null;
            $mimeType = $mimeType ?? null;
            $imageUrl = $imageUrl ?? null;

            if (is_array($firstImage)) {
                $imageBytesB64 =
                    $firstImage['imageBytes'] ??
                    $firstImage['image_bytes'] ??
                    null;
                $mimeType =
                    $firstImage['mimeType'] ??
                    $firstImage['mime_type'] ??
                    null;
                $imageUrl =
                    $firstImage['url'] ??
                    null;
            }

            if (empty($imageUrl) && is_array($payload['data'] ?? null)) {
                $imageUrl = $payload['data'][0]['url'] ?? null;
            }

            // Some schemas place `url` directly under the generated image object.
            if (empty($imageUrl) && is_array($firstGenerated)) {
                $imageUrl = $firstGenerated['url'] ?? null;
            }

            $imageBytes = null;
            $extension = 'png';
            if ($mimeType === 'image/jpeg' || $mimeType === 'image/jpg') {
                $extension = 'jpg';
            }

            if (! empty($imageBytesB64)) {
                if (is_string($imageBytesB64)) {
                    // Some responses may include whitespace/newlines in the base64 payload.
                    $imageBytesB64 = preg_replace('/\s+/', '', $imageBytesB64);
                }
                $imageBytes = base64_decode($imageBytesB64, true);
                if ($imageBytes === false) {
                    Log::warning('Gemini returned imageBytes but base64 decode failed', [
                        'mimeType' => $mimeType,
                        'imageBytesB64_length' => is_string($imageBytesB64) ? strlen($imageBytesB64) : null,
                    ]);
                    $imageBytes = null;
                }
            } elseif (! empty($imageUrl)) {
                // Fallback for schemas that return an already-hosted URL.
                /** @var HttpResponse $download */
                $download = Http::timeout(60)->get($imageUrl);
                if ($download->successful()) {
                    $imageBytes = $download->body();
                }
            }

            if (empty($imageBytes)) {
                Log::warning('Gemini returned no usable image bytes/url', [
                    'has_generatedImages' => is_array($generatedImages),
                    'mimeType' => $mimeType,
                    'has_imageBytesB64' => ! empty($imageBytesB64),
                    'imageBytesB64_length' => is_string($imageBytesB64)
                        ? strlen($imageBytesB64)
                        : null,
                    'imageUrl_present' => ! empty($imageUrl),
                    // Avoid dumping huge base64 content; include keys only.
                    'payload_keys' => is_array($payload) ? array_keys($payload) : [],
                ]);
                return $this->sendError('Gemini returned no usable image bytes.', [], 500);
            }

            $imageName = time() . '_book_cover.' . $extension;
            $path = 'images/' . $imageName;

            if ($this->useLocalStorageForImages()) {
                Storage::disk('public')->put($path, $imageBytes);
            } else {
                $s3 = Storage::disk('s3');
                $s3->put($path, $imageBytes);
                try {
                    $s3->setVisibility($path, 'public');
                } catch (\Throwable $e) {
                    // Bucket may block public ACLs; object is still uploaded, use presigned URLs.
                    Log::warning('S3 setVisibility failed (non-fatal): ' . $e->getMessage());
                }
            }

            return $this->sendResponse([
                'file_path' => $path,
                'file_url' => $this->getS3Url($path),
            ], 'Book cover image generated');
        } catch (\Throwable $e) {
            Log::error('Gemini image generation exception: ' . $e->getMessage(), [
                'exception' => $e,
            ]);
            return $this->sendError('Failed to generate book cover image.', [], 500);
        }
    }

    public function suggestBookInputs(Request $request, OpenAIController $openAiController)
    {
        $validator = Validator::make($request->all(), [
            'genre_id' => 'nullable|integer|exists:genres,id',
        ]);

        if ($validator->fails()) {
            return $this->sendError('Validation Error.', $validator->errors());
        }

        $genreId = $request->input('genre_id');
        $genreName = null;
        if (! empty($genreId)) {
            $genreName = Genre::find($genreId)?->name;
        }

        $suggestions = $openAiController->generateBookFormData($genreName);
        return $this->sendResponse($suggestions, 'AI suggestions generated');
    }

    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        $books = $this->ownedBooksQuery()
            ->orderBy('name', 'asc')
            ->with(['authors.phones', 'genre'])
            ->get();

        foreach ($books as $book) {
            $book->file = $this->getS3Url($book->file);
        }

        return $this->sendResponse($books, 'Books');
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        if ($oversized = $this->rejectOversizedUpload($request, 'file')) {
            return $oversized;
        }

        $maxKb = $this->uploadMaxKilobytes();
        $tooLarge = $this->imageTooLargeMessage();
        $validator = Validator::make($request->all(), [
            'name' => 'required',
            'genre_id' => 'required',
            'description' => 'required',
            'file' => "nullable|image|mimes:jpeg,png,jpg,gif,svg|max:{$maxKb}",
            'generated_file_path' => 'nullable|string',
            'inventory_total_qty' => 'required|integer|min:1'
        ], [
            'file.max' => $tooLarge,
            'file.uploaded' => $tooLarge,
        ]);

        if ($validator->fails()) {
            $first = (string) $validator->errors()->first();
            $message = str_contains($first, 'too large') ? $first : 'Validation Error.';
            return $this->sendError($message, $validator->errors(), str_contains($first, 'too large') ? 422 : 404);
        }

        if (! $request->hasFile('file') && empty($request->input('generated_file_path'))) {
            return $this->sendError('Validation Error.', [
                'file' => ['Either `file` (upload) or `generated_file_path` (AI-generated cover) is required.'],
            ], 422);
        }

        $book = new Book;
        $book->user_id = Auth::id();

        if ($request->hasFile('file')) {
            try {
                $extension = request()->file('file')->getClientOriginalExtension();
                $image_name = time() . '_book_cover.' . $extension;
                $path = $request->file('file')->storeAs(
                    'images',
                    $image_name,
                    's3'
                );
                if (! $path) {
                    Log::error('Book cover upload failed: storeAs returned empty path');
                    return $this->sendError('Book cover failed to upload!', [], 500);
                }
                try {
                    Storage::disk('s3')->setVisibility($path, 'public');
                } catch (\Throwable $e) {
                    // Bucket may block public ACLs; object is still uploaded, use presigned URLs
                    Log::warning('S3 setVisibility failed (non-fatal): ' . $e->getMessage());
                }
                $book->file = $path;
            } catch (\Throwable $e) {
                Log::error('Book cover upload failed: ' . $e->getMessage(), ['exception' => $e]);
                return $this->sendError('Book cover failed to upload!', [], 500);
            }
        } elseif (! empty($request->input('generated_file_path'))) {
            // When the cover was generated/uploaded separately, we only persist the storage path.
            $book->file = (string) $request->input('generated_file_path');
        }

        $book->name = $request['name'];
        $book->description = $request['description'];
        $book->checked_qty = 0;
        $book->genre_id = $request['genre_id'];
        $book->inventory_total_qty = $request['inventory_total_qty'];

        $book->save();

        if (isset($book->file)) {
            $book->file = $this->getS3Url($book->file);
        }
        $success['book'] = $book;
        return $this->sendResponse($success, 'Book succesfully updated!');
    }

    public function updateBookPicture(Request $request, $id)
    {
        if ($oversized = $this->rejectOversizedUpload($request, 'file')) {
            return $oversized;
        }

        $maxKb = $this->uploadMaxKilobytes();
        $tooLarge = $this->imageTooLargeMessage();
        $validator = Validator::make($request->all(), [
            'file' => "required|image|mimes:jpeg,png,jpg,gif,svg|max:{$maxKb}",
        ], [
            'file.max' => $tooLarge,
            'file.uploaded' => $tooLarge,
        ]);

        if ($validator->fails()) {
            $first = (string) $validator->errors()->first();
            $message = str_contains($first, 'too large') ? $first : 'Validation Error.';
            return $this->sendError($message, $validator->errors(), str_contains($first, 'too large') ? 422 : 404);
        }

        $book = $this->ownedBookOrFail($id);

        if ($request->hasFile('file')) {
            try {
                $extension = request()->file('file')->getClientOriginalExtension();
                $image_name = time() . '_book_cover.' . $extension;
                $path = $request->file('file')->storeAs(
                    'images',
                    $image_name,
                    's3'
                );
                if (! $path) {
                    Log::error('Book picture update failed: storeAs returned empty path');
                    return $this->sendError('Book cover failed to upload!', [], 500);
                }
                try {
                    Storage::disk('s3')->setVisibility($path, 'public');
                } catch (\Throwable $e) {
                    Log::warning('S3 setVisibility failed (non-fatal): ' . $e->getMessage());
                }
                $book->file = $path;
            } catch (\Throwable $e) {
                Log::error('Book picture update failed: ' . $e->getMessage(), ['exception' => $e]);
                return $this->sendError('Book cover failed to upload!', [], 500);
            }
        }
        $book->save();

        if (isset($book->file)) {
            $book->file = $this->getS3Url($book->file);
        }
        $success['book'] = $book;
        return $this->sendResponse($success, 'Book picture successfully updated!');
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, $id)
    {
        $book = $this->ownedBookOrFail($id);

        // `gte:checked_qty` compares to another attribute; the app does not send `checked_qty`.
        // Use the persisted value so inventory_total_qty >= copies currently checked out.
        $validator = Validator::make(
            array_merge($request->all(), ['checked_qty' => $book->checked_qty]),
            [
                'name' => 'required',
                'description' => 'required',
                'genre_id' => 'required',
                'inventory_total_qty' => 'required|integer|min:1|gte:checked_qty',
            ]
        );

        if ($validator->fails()) {
            return $this->sendError('Validation Error.', $validator->errors());
        }
        $book->name = $request['name'];
        $book->description = $request['description'];
        $book->genre_id = $request['genre_id'];
        $book->inventory_total_qty = $request['inventory_total_qty'];
        $book->save();

        if (isset($book->file)) {
            $book->file = $this->getS3Url($book->file);
        }
        $success['book'] = $book;
        return $this->sendResponse($success, 'Book succesfully updated!');
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy($id)
    {
        $book = $this->ownedBookOrFail($id);
        Storage::disk('s3')->delete($book->file);
        $book->delete();

        $success['book']['id'] = $id;
        return $this->sendResponse($success, 'Book Deleted');
    }

    public function checkoutBook(Request $request, $id)
    {
        $request['checkout_date'] = date('Y-m-d');
        $validator = Validator::make($request->all(), [
            'checkout_date' => 'required',
            'due_date' => 'required|date_format:Y-m-d|after_or_equal:checkout_date'
        ]);

        if ($validator->fails()) {
            return $this->sendError('Validation Error.', $validator->errors());
        }

        $book = $this->ownedBookOrFail($id);
        $book->checked_qty = $book->checked_qty + 1;

        if ($book->checked_qty > $book->inventory_total_qty) {
            return $this->sendError('Checkout Out Book Can Not Exceed Inventory!');
        }

        $checkoutId = Checkout::insertGetId([
            'checkout_date' => $request['checkout_date'],
            'due_date' => $request['due_date']
        ]);

        $authUser = Auth::user();
        $user = User::findOrFail($authUser->id);
        DB::table('user_book_checkouts')->insert([
            'user_id' => $user->id,
            'book_id' => $book->id,
            'checkout_id' => $checkoutId
        ]);

        $book->save();

        $book = $this->ownedBookOrFail($id)->load(['checkouts' => function ($query) {
            $query->whereNull('checkin_date');
        }]);
        $success['book'] = $book;
        return $this->sendResponse($success, 'Book Checkedout');
    }

    public function sendBookReport()
    {
        try {
            $authUser = Auth::user();
            $email = $authUser->email;
            
            Log::info('Sending book report', ['email' => $email]);
            
            // Call the books report command (sends list of Harry Potter books)
            $exitCode = \Illuminate\Support\Facades\Artisan::call('report:books', ['--email' => $email]);
            $output = \Illuminate\Support\Facades\Artisan::output();
            
            Log::info('Book report command executed', ['exit_code' => $exitCode, 'output' => $output]);
            
            if ($exitCode !== 0) {
                Log::error('Book report command failed with exit code: ' . $exitCode);
                return $this->sendError('Failed to send book report', [], 500);
            }
            
            $success['success'] = true;
            return $this->sendResponse($success, 'Book Report Sent!');
        } catch (\Exception $e) {
            Log::error('Book report failed: ' . $e->getMessage(), ['trace' => $e->getTraceAsString()]);
            return $this->sendError('Failed to send book report: ' . $e->getMessage(), [], 500);
        }
    }

    public function returnBook($id)
    {
        $book = $this->ownedBookOrFail($id);
        
        $authUser = Auth::user();
        $user = User::findOrFail($authUser->id);
        
        // Find an active checkout (where checkin_date is null) for this user and book
        $userBookCheckout = DB::table('user_book_checkouts')
            ->join('checkouts', 'user_book_checkouts.checkout_id', '=', 'checkouts.id')
            ->where('user_book_checkouts.user_id', $user->id)
            ->where('user_book_checkouts.book_id', $book->id)
            ->whereNull('checkouts.checkin_date')
            ->select('user_book_checkouts.checkout_id')
            ->first();

        if (!$userBookCheckout) {
            return $this->sendError('No active checkout found for this book', [], 404);
        }

        $checkoutID = $userBookCheckout->checkout_id;

        DB::table('checkouts')->where('id', $checkoutID)->update([
            'checkin_date' => date('Y-m-d')
        ]);

        $book->checked_qty = $book->checked_qty - 1;

        if ($book->checked_qty < 0) {
            $book->checked_qty = 0;
        }

        $book->save();

        $book = $this->ownedBookOrFail($id)->load(['checkouts' => function ($query) {
            $query->whereNull('checkin_date');
        }]);
        $success['book'] = $book;
        return $this->sendResponse($success, 'Book Returned');
    }

    private function ownedBooksQuery()
    {
        return Book::ownedBy((int) Auth::id());
    }

    private function ownedBookOrFail($id): Book
    {
        return $this->ownedBooksQuery()->findOrFail($id);
    }
}

