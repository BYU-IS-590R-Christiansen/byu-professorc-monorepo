<?php

namespace App\Http\Controllers\Api;

use App\Mail\VerifyEmail;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;

class UserController extends BaseController
{
    public function getUser()
    {
        $authUser = Auth::user();
        $user = User::findOrFail($authUser->id);
        $user->avatar = $this->getS3Url($user->avatar);
        return $this->sendResponse($user, 'User');
    }

    public function uploadAvatar(Request $request)
    {
        if ($oversized = $this->rejectOversizedUpload($request, 'image')) {
            return $oversized;
        }

        $maxKb = $this->uploadMaxKilobytes();
        $tooLarge = $this->imageTooLargeMessage();
        $validator = Validator::make($request->all(), [
            'image' => "required|image|mimes:jpeg,png,jpg,gif,svg|max:{$maxKb}",
        ], [
            'image.max' => $tooLarge,
            'image.uploaded' => $tooLarge,
        ]);
        if ($validator->fails()) {
            $first = (string) $validator->errors()->first();
            return $this->sendError($first !== '' ? $first : 'Validation Error.', $validator->errors(), 422);
        }

        if ($request->hasFile('image')) {
            $authUser = Auth::user();
            $user = User::findOrFail($authUser->id);
            $extension = request()->file('image')->getClientOriginalExtension();
            $image_name = time() . '_' . $authUser->id . '.' . $extension;
            $path = $request->file('image')->storeAs(
                'images',
                $image_name,
                's3'
            );
            Storage::disk('s3')->setVisibility($path, "public");
            if (!$path) {
                return $this->sendError($path, 'User profile avatar failed to upload!');
            }

            $user->avatar = $path;
            $user->save();
            $success['avatar'] = null;
            if (isset($user->avatar)) {
                $success['avatar'] = $this->getS3Url($path);
            }
            return $this->sendResponse($success, 'User profile avatar uploaded successfully!');
        }
    }

    public function removeAvatar()
    {
        $authUser = Auth::user();
        $user = User::findOrFail(id: $authUser->id);
        Storage::disk('s3')->delete($user->avatar);
        $user->avatar = null;
        $user->save();
        $success['avatar'] = null;

        // UPDATE user SET avatar = null WHERE id = $authUser->id;
        return $this->sendResponse($success, 'User profile avatar removed successfully!');
    }

    public function sendVerificationEmail(Request $request)
    {
        $authUser = Auth::user();
        $user = User::findOrFail($authUser->id);
        Mail::to($user->email)->send(new VerifyEmail($user->email));
        $success['status'] = true;
        return $this->sendResponse($success, 'Email sent to ' . $user->email);
    }

    public function changeEmail(Request $request)
    {
        $request->validate([
            'change_email' => 'required|email|unique:users,email|min:3',
        ]);
        $authUser = Auth::user();
        $user = User::findOrFail($authUser->id);
        $user->email = $request->change_email;
        $user->save();
        Mail::to($user->email)->send(new VerifyEmail($user->email));
        $success['email'] = $user->email;
        return $this->sendResponse($success, 'Email sent to ' . $user->email);
    }
}

