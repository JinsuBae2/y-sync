import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feedback_provider.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/selection_highlight.dart';
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
    appBar: AppBar(
      title: const Text('의견 보내기'),
      backgroundColor: AppDesignTokens.background,
      foregroundColor: AppDesignTokens.navy,
      surfaceTintColor: Colors.transparent,
    ),
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.paleBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: AppDesignTokens.blue,
                            size: 22,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '관리자에게 안전하게 전달돼요',
                                  style: TextStyle(
                                    color: AppDesignTokens.navy,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  '보낸 의견은 다른 사용자에게 공개되지 않습니다. 개인정보는 내용과 이미지에서 지워주세요.',
                                  style: TextStyle(
                                    color: AppDesignTokens.muted,
                                    fontSize: 12.5,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _FormSection(
                      number: '1',
                      title: '어떤 의견인가요?',
                      description: '가장 가까운 유형을 선택해주세요.',
                      child: LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: feedbackCategories.entries
                              .map(
                                (entry) => _CategoryOption(
                                  label: entry.value,
                                  icon: switch (entry.key) {
                                    'BUG' => Icons.bug_report_outlined,
                                    'SUGGESTION' =>
                                      Icons.lightbulb_outline_rounded,
                                    _ => Icons.chat_bubble_outline_rounded,
                                  },
                                  selected: _category == entry.key,
                                  width: constraints.maxWidth < 420
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 16) / 3,
                                  onTap: _sending
                                      ? null
                                      : () => setState(
                                          () => _category = entry.key,
                                        ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      number: '2',
                      title: '내용을 알려주세요',
                      description: '상황을 구체적으로 적을수록 빠르게 이해할 수 있어요.',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _title,
                            enabled: !_sending,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: '제목',
                              hintText: '핵심 내용을 한 문장으로 적어주세요',
                              filled: true,
                              fillColor: AppDesignTokens.paleBlue,
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? '제목을 입력해주세요.'
                                : null,
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _content,
                            enabled: !_sending,
                            maxLength: 3000,
                            minLines: 6,
                            maxLines: 12,
                            decoration: InputDecoration(
                              labelText: '상세 내용',
                              hintText: _category == 'BUG'
                                  ? '무엇을 하다가 문제가 발생했나요?\n기대한 결과와 실제 결과를 함께 알려주세요.'
                                  : '어떤 점이 달라지면 더 편리할지 알려주세요.',
                              alignLabelWithHint: true,
                              filled: true,
                              fillColor: AppDesignTokens.paleBlue,
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? '내용을 입력해주세요.'
                                : null,
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _screen,
                            enabled: !_sending,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: '관련 화면',
                              hintText: '예: 개인 시간표 (선택)',
                              prefixIcon: Icon(Icons.smartphone_outlined),
                              filled: true,
                              fillColor: AppDesignTokens.paleBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      number: '3',
                      title: '이미지를 첨부할까요?',
                      description: '문제가 보이는 화면이 있다면 확인에 도움이 됩니다. 선택 사항이에요.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              side: const BorderSide(
                                color: AppDesignTokens.divider,
                              ),
                            ),
                            onPressed: _sending ? null : _pickImages,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: Text('이미지 선택  ${_images.length}/3'),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'PNG/JPG · 한 장당 최대 2MB',
                            style: TextStyle(
                              color: AppDesignTokens.muted,
                              fontSize: 12,
                            ),
                          ),
                          if (!_sending && _images.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SelectedAttachmentList(
                              files: _images,
                              onRemove: (index) =>
                                  setState(() => _images.removeAt(index)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppDesignTokens.divider),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppDesignTokens.muted,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '앱 버전과 실행 환경이 오류 확인용으로 함께 전송됩니다.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppDesignTokens.muted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _sending ? null : _submit,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 19),
                        label: Text(_sending ? '보내는 중…' : '의견 보내기'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.number,
    required this.title,
    required this.description,
    required this.child,
  });

  final String number;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppDesignTokens.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppDesignTokens.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppDesignTokens.navy,
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppDesignTokens.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppDesignTokens.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 52,
    child: Material(
      color: AppDesignTokens.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? AppDesignTokens.blue : AppDesignTokens.divider,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppDesignTokens.blue : AppDesignTokens.muted,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: SelectionHighlight(
                  selected: selected,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected
                          ? AppDesignTokens.navy
                          : AppDesignTokens.muted,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
