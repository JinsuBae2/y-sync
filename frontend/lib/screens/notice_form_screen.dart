import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';

class NoticeFormScreen extends ConsumerStatefulWidget {
  final Notice? notice;

  const NoticeFormScreen({super.key, this.notice});

  @override
  ConsumerState<NoticeFormScreen> createState() => _NoticeFormScreenState();
}

class _NoticeFormScreenState extends ConsumerState<NoticeFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String _noticeType = 'INTERNAL';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final isEdit = widget.notice != null;
    _titleController = TextEditingController(text: isEdit ? widget.notice!.title : '');
    _contentController = TextEditingController(text: isEdit ? widget.notice!.content : '');
    if (isEdit) {
      _noticeType = widget.notice!.noticeType;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 모두 입력해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(noticeNotifierProvider);
      if (widget.notice == null) {
        await notifier.createNotice(title, content, _noticeType);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공지사항이 등록되었습니다.')),
          );
        }
      } else {
        await notifier.updateNotice(widget.notice!.id, title, content, _noticeType);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공지사항이 수정되었습니다.')),
          );
        }
      }
      if (mounted) {
        // Return to first screen (list screen)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('저장 실패: $e')),
         );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.notice != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '공지사항 수정' : '새 공지사항 쓰기'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _noticeType,
              decoration: const InputDecoration(labelText: '공지 타입', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'INTERNAL', child: Text('일반 공지 (INTERNAL)')),
                DropdownMenuItem(value: 'OFFICIAL', child: Text('학교 공지 (OFFICIAL)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _noticeType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: '내용',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading 
                    ? const CircularProgressIndicator()
                    : Text(isEdit ? '수정하기' : '등록하기', style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
