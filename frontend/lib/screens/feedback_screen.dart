import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feedback_provider.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/selected_attachment_list.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});
  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _screen = TextEditingController();
  final _images = <PlatformFile>[];
  String _category = 'BUG';
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _screen.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        allowMultiple: true,
        withData: true,
      );
      if (!mounted || result == null) return;
      if (_images.length + result.files.length > 3 ||
          result.files.any(
            (file) => file.size == 0 || file.size > 2 * 1024 * 1024,
          )) {
        _message('PNG/JPG 이미지 최대 3개, 한 장당 2MB 이하로 선택해주세요.');
        return;
      }
      setState(() => _images.addAll(result.files));
    } catch (_) {
      if (mounted) _message('이미지를 불러오지 못했습니다. 다시 선택해주세요.');
    }
  }

  Future<void> _submit() async {
    if (_sending || !_form.currentState!.validate()) return;
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      _message('제목과 내용을 입력해주세요.');
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(feedbackServiceProvider)
          .submit(
            category: _category,
            title: _title.text,
            content: _content.text,
            screen: _screen.text,
            images: _images,
          );
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (!mounted) return;
      final data = error is DioException ? error.response?.data : null;
      _message(
        data is Map && data['message'] is String
            ? data['message'] as String
            : '전송하지 못했습니다. 입력한 내용은 유지되니 다시 시도해주세요.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppDesignTokens.background,
    appBar: AppBar(title: const Text('의견 보내기')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _sent
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: AppDesignTokens.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '의견을 보내주셔서 감사합니다.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '보내주신 내용은 관리자가 검토해 서비스 개선에 활용합니다.\n개별 답변과 처리 상태 조회는 제공하지 않습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              )
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      '더 나은 Y-Sync를 함께 만들어요.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppDesignTokens.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '의견은 관리자만 확인합니다. 비밀번호, 연락처 등 개인정보는 내용과 이미지에서 지워주세요.',
                      style: TextStyle(
                        color: AppDesignTokens.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: '유형'),
                      items: feedbackCategories.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: _sending
                          ? null
                          : (value) => setState(() => _category = value!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _title,
                      enabled: !_sending,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: '제목',
                        hintText: '어떤 의견인가요?',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '제목을 입력해주세요.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _content,
                      enabled: !_sending,
                      maxLength: 3000,
                      minLines: 5,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: '내용',
                        hintText: '오류가 발생한 순서와 기대한 동작, 또는 개선 아이디어를 알려주세요.',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '내용을 입력해주세요.'
                          : null,
                    ),
                    TextFormField(
                      controller: _screen,
                      enabled: !_sending,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: '관련 화면 (선택)',
                        hintText: '예: 개인 시간표',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _sending ? null : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text('이미지 첨부 (${_images.length}/3)'),
                    ),
                    const Text(
                      'PNG/JPG · 한 장당 최대 2MB',
                      style: TextStyle(color: AppDesignTokens.muted),
                    ),
                    const SizedBox(height: 8),
                    if (!_sending)
                      SelectedAttachmentList(
                        files: _images,
                        onRemove: (index) =>
                            setState(() => _images.removeAt(index)),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      '오류 확인을 위해 앱 버전과 실행 환경(Web/PWA·운영체제 종류)이 함께 전송됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _sending ? null : _submit,
                      child: Text(_sending ? '보내는 중…' : '의견 보내기'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    ),
  );
}
