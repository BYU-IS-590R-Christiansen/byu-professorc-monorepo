<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="color-scheme" content="light">
    <meta name="supported-color-schemes" content="light">
    <title>Your requested book inventory</title>
</head>
<body style="margin: 0; padding: 0; font-family: Georgia, 'Times New Roman', Times, serif; background-color: #f3f4f6;">
    <div style="display: none; max-height: 0; overflow: hidden; opacity: 0; color: transparent;">
        Summary of {{ $titleCount }} {{ $titleCount === 1 ? 'title' : 'titles' }} in your {{ $appName }} catalog, prepared {{ $generatedAt }}.
    </div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f3f4f6; padding: 32px 16px;">
        <tr>
            <td align="center">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width: 640px; background-color: #ffffff; border: 1px solid #e5e7eb; border-radius: 8px; overflow: hidden;">
                    <tr>
                        <td style="padding: 28px 32px 20px; background-color: #1e3a5f;">
                            <p style="margin: 0 0 6px; font-family: Arial, Helvetica, sans-serif; font-size: 12px; letter-spacing: 0.08em; text-transform: uppercase; color: #93c5fd;">
                                {{ $appName }}
                            </p>
                            <h1 style="margin: 0; font-size: 24px; line-height: 1.3; font-weight: 600; color: #ffffff;">
                                Book inventory summary
                            </h1>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 28px 32px 8px; font-family: Arial, Helvetica, sans-serif; font-size: 16px; line-height: 1.6; color: #374151;">
                            <p style="margin: 0 0 16px;">
                                Hello,
                            </p>
                            <p style="margin: 0 0 16px;">
                                This is the catalog summary you requested. It includes the titles currently in your library and how many copies are on the shelf.
                            </p>
                            <p style="margin: 0 0 24px; font-size: 14px; color: #6b7280;">
                                Prepared {{ $generatedAt }} · {{ $titleCount }} {{ $titleCount === 1 ? 'title' : 'titles' }}
                            </p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 0 32px 8px;">
                            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse: collapse; font-family: Arial, Helvetica, sans-serif; font-size: 14px;">
                                <thead>
                                    <tr>
                                        <th align="left" style="padding: 10px 12px; border-bottom: 2px solid #1e3a5f; color: #1e3a5f; font-size: 12px; letter-spacing: 0.04em; text-transform: uppercase;">Title</th>
                                        <th align="left" style="padding: 10px 12px; border-bottom: 2px solid #1e3a5f; color: #1e3a5f; font-size: 12px; letter-spacing: 0.04em; text-transform: uppercase;">Details</th>
                                        <th align="left" style="padding: 10px 12px; border-bottom: 2px solid #1e3a5f; color: #1e3a5f; font-size: 12px; letter-spacing: 0.04em; text-transform: uppercase;">Genre</th>
                                        <th align="right" style="padding: 10px 12px; border-bottom: 2px solid #1e3a5f; color: #1e3a5f; font-size: 12px; letter-spacing: 0.04em; text-transform: uppercase;">Available</th>
                                        <th align="right" style="padding: 10px 12px; border-bottom: 2px solid #1e3a5f; color: #1e3a5f; font-size: 12px; letter-spacing: 0.04em; text-transform: uppercase;">Total</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @foreach ($books as $index => $book)
                                        @php
                                            $total = (int) $book->inventory_total_qty;
                                            $checkedOut = (int) $book->checked_qty;
                                            $available = max($total - $checkedOut, 0);
                                            $rowBg = $index % 2 === 0 ? '#ffffff' : '#f8fafc';
                                        @endphp
                                        <tr style="background-color: {{ $rowBg }};">
                                            <td style="padding: 12px; border-bottom: 1px solid #e5e7eb; color: #111827; font-weight: 600; vertical-align: top;">
                                                {{ $book->name }}
                                            </td>
                                            <td style="padding: 12px; border-bottom: 1px solid #e5e7eb; color: #4b5563; vertical-align: top;">
                                                {{ $book->description }}
                                            </td>
                                            <td style="padding: 12px; border-bottom: 1px solid #e5e7eb; color: #4b5563; vertical-align: top;">
                                                {{ $book->genre->name ?? '—' }}
                                            </td>
                                            <td align="right" style="padding: 12px; border-bottom: 1px solid #e5e7eb; color: #111827; vertical-align: top; white-space: nowrap;">
                                                {{ $available }}
                                            </td>
                                            <td align="right" style="padding: 12px; border-bottom: 1px solid #e5e7eb; color: #111827; vertical-align: top; white-space: nowrap;">
                                                {{ $total }}
                                            </td>
                                        </tr>
                                    @endforeach
                                </tbody>
                            </table>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 24px 32px 8px; font-family: Arial, Helvetica, sans-serif; font-size: 15px; line-height: 1.6; color: #374151;">
                            <p style="margin: 0 0 16px;">
                                To review or update these titles, open your library in the application.
                            </p>
                            @if ($appUrl)
                                <table role="presentation" cellspacing="0" cellpadding="0">
                                    <tr>
                                        <td style="border-radius: 6px; background-color: #1e3a5f;">
                                            <a href="{{ $appUrl }}" target="_blank" style="display: inline-block; padding: 12px 20px; font-size: 14px; font-weight: 600; color: #ffffff; text-decoration: none;">
                                                Open library catalog
                                            </a>
                                        </td>
                                    </tr>
                                </table>
                            @endif
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 28px 32px; font-family: Arial, Helvetica, sans-serif; font-size: 12px; line-height: 1.5; color: #6b7280; border-top: 1px solid #e5e7eb;">
                            <p style="margin: 0 0 8px;">
                                You received this message because you asked {{ $appName }} to email a book inventory report.
                                If you did not request it, no action is needed.
                            </p>
                            <p style="margin: 0;">
                                {{ $appName }} · Transactional library notice
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
