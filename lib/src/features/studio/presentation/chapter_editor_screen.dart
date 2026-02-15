import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../studio/data/chapter_repository.dart';

class ChapterEditorScreen extends ConsumerStatefulWidget {
  const ChapterEditorScreen({
    super.key,
    required this.bookId,
    this.chapterId,
  });

  final String bookId;
  final String? chapterId;

  @override
  ConsumerState<ChapterEditorScreen> createState() =>
      _ChapterEditorScreenState();
}

class _ChapterEditorScreenState extends ConsumerState<ChapterEditorScreen> {
  late QuillController _quillController;
  final _titleController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFree = false;
  int _price = 10;

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
    _loadChapter();
  }

  Future<void> _loadChapter() async {
    if (widget.chapterId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final chapter = await ref
          .read(chapterRepositoryProvider)
          .getChapterById(widget.chapterId!);

      if (chapter != null && mounted) {
        _titleController.text = chapter.title;
        _isFree = chapter.isFree;
        _price = chapter.price;

        // JSONB content → Document
        final content = chapter.content;
        if (content.isNotEmpty && content.containsKey('ops')) {
          final ops = content['ops'] as List<dynamic>;
          _quillController = QuillController(
            document: Document.fromJson(ops),
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bölüm yüklenirken hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bölüm başlığı gerekli')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final content = <String, dynamic>{
        'ops': _quillController.document.toDelta().toJson(),
      };

      final chapterRepo = ref.read(chapterRepositoryProvider);

      if (widget.chapterId != null) {
        await chapterRepo.updateChapter(
          chapterId: widget.chapterId!,
          title: _titleController.text.trim(),
          content: content,
          isFree: _isFree,
          price: _price,
        );
      } else {
        final newChapter = await chapterRepo.createChapter(
          bookId: widget.bookId,
          title: _titleController.text.trim(),
          isFree: _isFree,
          price: _price,
        );
        await chapterRepo.updateChapter(
          chapterId: newChapter.id,
          content: content,
        );
      }

      ref.invalidate(chaptersByBookProvider(widget.bookId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bölüm kaydedildi ✓')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydetme hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _quillController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.chapterId != null ? 'Bölüm Düzenle' : 'Yeni Bölüm'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Kaydet'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Başlık + Ayarlar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Bölüm Başlığı',
                    hintText: 'Bölümünüzün başlığını yazın',
                  ),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilterChip(
                      selected: _isFree,
                      label: const Text('Ücretsiz'),
                      onSelected: (val) => setState(() => _isFree = val),
                    ),
                    const SizedBox(width: 8),
                    if (!_isFree)
                      Expanded(
                        child: Row(
                          children: [
                            const Text('Fiyat: '),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  suffixText: 'Token',
                                  isDense: true,
                                ),
                                controller:
                                    TextEditingController(text: '$_price'),
                                onChanged: (val) {
                                  _price = int.tryParse(val) ?? 10;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Quill Toolbar
          QuillSimpleToolbar(controller: _quillController),

          const Divider(height: 1),

          // Quill Editor
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: QuillEditor.basic(
                controller: _quillController,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
