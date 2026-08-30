import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/selected_attachment_list.dart';

class CommunityFormScreen extends ConsumerStatefulWidget {
  const CommunityFormScreen({super.key, this.post});

  final CommunityPost? post;

  @override
  ConsumerState<CommunityFormScreen> createState() =>
      _CommunityFormScreenState();
}

class _CommunityFormScreenState extends ConsumerState<CommunityFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  String _category = 'FREE';
  String _targetGrade = 'ALL';
  bool _anonymous = false;
  bool _isLoading = false;
  final List<PlatformFile> _files = [];

  static const _categories = <(String, String)>[
    ('FREE', '자유'),
    ('QA', 'Q&A'),
    ('TEAM', '팀원 모집'),
  ];
  static const _grades = <(String, String)>[
    ('ALL', '전체'),
    ('GRADE_1', '1학년'),
    ('GRADE_2', '2학년'),
    ('GRADE_3', '3학년'),
  ];

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _titleController = TextEditingController(text: post?.title ?? '');
    _contentController = TextEditingController(text: post?.content ?? '');
    if (post != null) {
      _category = post.category;
      _targetGrade = post.targetGrade;
      _anonymous = post.anonymous;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'png',
        'jpg',
        'jpeg',
        'gif',
        'webp',
        'pdf',
        'hwp',
        'hwpx',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'zip',
      ],
    );
    if (!mounted || result == null) return;
    if (_files.length + result.files.length > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('첨부파일은 최대 10개까지 선택할 수 있습니다.')),
      );
      return;
    }
    if (result.files.any((file) => file.size > 20 * 1024 * 1024)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일 하나의 크기는 20MB 이하여야 합니다.')),
      );
      return;
    }
    final totalSize = [
      ..._files,
      ...result.files,
    ].fold<int>(0, (sum, file) => sum + file.size);
    if (totalSize > 50 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('첨부파일 전체 크기는 50MB 이하여야 합니다.')),
      );
      return;
    }
    setState(() => _files.addAll(result.files));
  }

  Future<void> _savePost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목과 내용을 모두 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(communityNotifierProvider);
      if (widget.post == null) {
        await notifier.createPost(
          category: _category,
          title: title,
          content: content,
          anonymous: _anonymous,
          targetGrade: _targetGrade,
          files: _files,
        );
      } else {
        await notifier.updatePost(
          id: widget.post!.id,
          category: _category,
          title: title,
          content: content,
          anonymous: _anonymous,
          targetGrade: _targetGrade,
          files: _files,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.post == null ? '게시글이 등록되었습니다.' : '게시글이 수정되었습니다.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $error')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.post != null;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          isEdit ? '게시글 수정' : '게시글 작성',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDesignTokens.contentMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const _SectionTitle(
                title: '게시글 정보',
                subtitle: '주제와 대상이 분명할수록 답변을 빠르게 받을 수 있어요.',
              ),
              const SizedBox(height: 12),
              _OptionSelector(
                options: _categories,
                value: _category,
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 16),
              const Text(
                '대상 학년',
                style: TextStyle(
                  color: AppDesignTokens.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _OptionSelector(
                options: _grades,
                value: _targetGrade,
                onChanged: (value) => setState(() => _targetGrade = value),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppDesignTokens.navy.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SwitchListTile(
                  value: _anonymous,
                  activeTrackColor: AppDesignTokens.blue,
                  title: const Text(
                    '익명으로 작성',
                    style: TextStyle(
                      color: AppDesignTokens.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    '작성자 이름 대신 익명의 학생으로 표시됩니다.',
                    style: TextStyle(
                      color: AppDesignTokens.muted,
                      fontSize: 12,
                    ),
                  ),
                  onChanged: (value) => setState(() => _anonymous = value),
                ),
              ),
              const SizedBox(height: 28),
              const _SectionTitle(title: '내용'),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                style: const TextStyle(
                  color: AppDesignTokens.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDecoration(label: '제목', hint: '제목을 입력하세요'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                minLines: 10,
                maxLines: 18,
                style: const TextStyle(
                  color: AppDesignTokens.navy,
                  fontSize: 15,
                  height: 1.55,
                ),
                decoration: _inputDecoration(
                  label: '내용',
                  hint: _category == 'TEAM'
                      ? '모집 인원, 역할, 기간 등 필요한 내용을 입력하세요'
                      : '내용을 입력하세요',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 28),
              const _SectionTitle(
                title: '첨부 파일',
                subtitle: '이미지, PDF, HWP, Office 문서 등을 첨부할 수 있어요.',
              ),
              if (isEdit && widget.post!.attachments.isNotEmpty) ...[
                const SizedBox(height: 6),
                const Text(
                  '새 파일을 선택하지 않으면 기존 첨부파일이 유지됩니다.',
                  style: TextStyle(color: AppDesignTokens.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickFiles,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(_files.isEmpty ? '파일 선택' : '${_files.length}개 추가됨'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppDesignTokens.blue,
                  backgroundColor: Colors.white.withValues(alpha: 0.48),
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_files.isNotEmpty) ...[
                const SizedBox(height: 10),
                SelectedAttachmentList(
                  files: _files,
                  onRemove: (index) => setState(() => _files.removeAt(index)),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ),
              child: FilledButton(
                onPressed: _isLoading ? null : _savePost,
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignTokens.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppDesignTokens.subtle,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEdit ? '수정 완료' : '게시글 등록',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static InputDecoration _inputDecoration({
    required String label,
    required String hint,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      labelStyle: const TextStyle(color: AppDesignTokens.muted),
      hintStyle: const TextStyle(color: AppDesignTokens.subtle),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.68),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppDesignTokens.blue, width: 1.5),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppDesignTokens.navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(color: AppDesignTokens.muted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _OptionSelector extends StatelessWidget {
  const _OptionSelector({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Material(
                      color: option.$1 == value
                          ? AppDesignTokens.paleBlue.withValues(alpha: 0.72)
                          : Colors.white.withValues(alpha: 0.3),
                      child: InkWell(
                        onTap: () => onChanged(option.$1),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          child: Text(
                            option.$2,
                            maxLines: 1,
                            style: TextStyle(
                              color: option.$1 == value
                                  ? AppDesignTokens.navy
                                  : AppDesignTokens.muted,
                              fontSize: 13,
                              fontWeight: option.$1 == value
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
