import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:byu_590r_flutter_app/core/api_client.dart';
import 'package:byu_590r_flutter_app/models/book.dart';
import 'package:byu_590r_flutter_app/models/genre_option.dart';

/// Create (`book == null`) or edit an existing book.
class BookFormScreen extends StatefulWidget {
  const BookFormScreen({
    super.key,
    required this.accessToken,
    required this.genres,
    this.book,
  });

  final String accessToken;
  final List<GenreOption> genres;
  final Book? book;

  bool get isEditing => book != null;

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _inventoryController = TextEditingController();

  int? _genreId;
  Uint8List? _imageBytes;
  String? _imageFileName;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    if (b != null) {
      _nameController.text = b.name;
      _descriptionController.text = b.description;
      _inventoryController.text = b.inventoryTotalQty?.toString() ?? '1';
      var gid = b.genreId;
      if (gid != null && !widget.genres.any((g) => g.id == gid)) {
        gid = widget.genres.isNotEmpty ? widget.genres.first.id : null;
      }
      _genreId =
          gid ?? (widget.genres.isNotEmpty ? widget.genres.first.id : null);
    } else {
      _inventoryController.text = '1';
      _genreId = widget.genres.isNotEmpty ? widget.genres.first.id : null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _inventoryController.dispose();
    super.dispose();
  }

  int? get _checkedQty => widget.book?.checkedQty;

  /// Gallery via `image_picker` only (no `file_picker` native channel).
  /// Uses [XFile.readAsBytes] so we never need `dart:io` / paths (web-safe).
  /// After adding/changing plugins, **stop the app** and run `flutter run` again (not hot reload).
  Future<void> _pickImage() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (!mounted || x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageFileName = x.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  String _formatApiError(dynamic res) {
    if (res is! Map) return 'Request failed';
    final msg = res['message']?.toString();
    final data = res['data'];
    if (data is Map<String, dynamic>) {
      final parts = <String>[];
      for (final e in data.entries) {
        final v = e.value;
        if (v is List) {
          parts.addAll(v.map((x) => x.toString()));
        } else {
          parts.add(v.toString());
        }
      }
      if (parts.isNotEmpty) {
        return [if (msg != null && msg.isNotEmpty) msg, ...parts].join('\n');
      }
    }
    return msg ?? 'Request failed';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.genres.isEmpty) {
      _toast('No genres available.');
      return;
    }

    final gid = _dropdownGenreValue;
    if (gid == null) {
      _toast('Select a genre.');
      return;
    }
    final inv = int.tryParse(_inventoryController.text.trim());
    if (inv == null) {
      _toast('Invalid inventory.');
      return;
    }

    if (widget.isEditing) {
      final minInv = _checkedQty ?? 0;
      if (inv < 1 || inv < minInv) {
        _toast('Inventory must be at least $minInv (checked out copies).');
        return;
      }
    } else {
      if (inv < 1) {
        _toast('Inventory must be at least 1.');
        return;
      }
      final hasFile = _imageBytes != null && _imageBytes!.isNotEmpty;
      if (!hasFile) {
        _toast('Choose a cover image (required for new books).');
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final dynamic res;
      if (widget.isEditing) {
        res = await _api.updateBook(
          accessToken: widget.accessToken,
          id: widget.book!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          genreId: gid,
          inventoryTotalQty: inv,
        );
      } else {
        res = await _api.createBook(
          accessToken: widget.accessToken,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          genreId: gid,
          inventoryTotalQty: inv,
          imageBytes: _imageBytes!,
          imageFilename: _imageFileName ?? 'cover.jpg',
        );
      }

      if (!mounted) return;
      setState(() => _submitting = false);

      if (res is Map<String, dynamic> && res['success'] == true) {
        Navigator.of(context).pop(true);
      } else {
        _toast(_formatApiError(res));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _toast(e.toString());
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool get _hasCoverPreview => _imageBytes != null && _imageBytes!.isNotEmpty;

  /// Must match one of [widget.genres] or DropdownButton asserts / shows wrong errors.
  int? get _dropdownGenreValue {
    if (widget.genres.isEmpty) return null;
    final id = _genreId;
    if (id != null && widget.genres.any((g) => g.id == id)) return id;
    return widget.genres.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Edit book' : 'Add book';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!widget.isEditing) ...[
              Text(
                'Choose an image file for the cover (required for new books).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _hasCoverPreview
                      ? 'Change cover image'
                      : 'Choose cover image',
                ),
              ),
              if (_hasCoverPreview) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _imageBytes!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Enter a title';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Description22222',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Enter a description';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey<int>(
                Object.hashAll(widget.genres.map((g) => g.id)),
              ),
              // ignore: deprecated_member_use
              value: _dropdownGenreValue,
              decoration: const InputDecoration(
                labelText: 'Genre',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: widget.genres
                  .map(
                    (g) => DropdownMenuItem<int>(
                      value: g.id,
                      child: Text(g.name),
                    ),
                  )
                  .toList(),
              onChanged:
                  _submitting ? null : (v) => setState(() => _genreId = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _inventoryController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Total inventory',
                prefixIcon: const Icon(Icons.numbers),
                helperText: widget.isEditing && _checkedQty != null
                    ? 'Must be ≥ $_checkedQty (checked out)'
                    : 'Minimum 1',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter inventory';
                }
                if (int.tryParse(v.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Save changes' : 'Create book'),
            ),
          ],
        ),
      ),
    );
  }
}
