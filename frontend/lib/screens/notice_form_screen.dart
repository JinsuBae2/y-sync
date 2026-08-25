import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../theme/app_design_tokens.dart';

class NoticeFormScreen extends ConsumerStatefulWidget {
  const NoticeFormScreen({super.key, this.notice});

  final Notice? notice;

  @override
  ConsumerState<NoticeFormScreen> createState() => _NoticeFormScreenState();
}

class _NoticeFormScreenState extends ConsumerState<NoticeFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  String _noticeType = 'NEWS';
  String _targetGrade = 'ALL';
  bool _isLoading = false;
  final List<XFile> _images = [];
  bool _isEvent = false;
  DateTime _eventStartDate = DateTime.now();
  DateTime _eventEndDate = DateTime.now();

  static const _grades = <(String, String)>[
    ('ALL', '전체'),
    ('GRADE_1', '1학년'),
    ('GRADE_2', '2학년'),
    ('GRADE_3', '3학년'),
  ];

  @override
  void initState() {
    super.initState();
    final notice = widget.notice;
    _titleController = TextEditingController(text: notice?.title ?? '');
    _contentController = TextEditingController(text: notice?.content ?? '');
    if (notice != null) {
      _noticeType = notice.noticeType;
      _targetGrade = notice.targetGrade;
      _isEvent = notice.eventStartDate != null;
      if (_isEvent) {
        _eventStartDate = DateTime.parse(notice.eventStartDate!);
        _eventEndDate = DateTime.parse(
          notice.eventEndDate ?? notice.eventStartDate!,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final selectedImages = await ImagePicker().pickMultiImage();
    if (!mounted || selectedImages.isEmpty) return;
    setState(() => _images.addAll(selectedImages));
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목과 내용을 모두 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);
    final startDate = _isEvent ? _apiDate(_eventStartDate) : null;
    final endDate = _isEvent ? _apiDate(_eventEndDate) : null;

    try {
      final notifier = ref.read(noticeNotifierProvider);
      if (widget.notice == null) {
        await notifier.createNotice(
          title,
          content,
          _noticeType,
          targetGrade: _targetGrade,
          images: _images,
          eventStartDate: startDate,
          eventEndDate: endDate,
        );
      } else {
        await notifier.updateNotice(
          widget.notice!.id,
          title,
          content,
          _noticeType,
          targetGrade: _targetGrade,
          images: _images,
          eventStartDate: startDate,
          eventEndDate: endDate,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.notice == null ? '공지사항이 등록되었습니다.' : '공지사항이 수정되었습니다.',
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
    final isEdit = widget.notice != null;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          isEdit ? '공지사항 수정' : '공지사항 작성',
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
              const _FormSectionTitle(
                title: '기본 정보',
                subtitle: '학생이 목록에서 바로 이해할 수 있게 작성해주세요.',
              ),
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
                decoration: _inputDecoration(label: '제목', hint: '공지 제목을 입력하세요'),
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
                  hint: '일정, 장소, 준비사항 등 필요한 내용을 입력하세요',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 28),
              const _FormSectionTitle(title: '공지 설정'),
              const SizedBox(height: 12),
              _OptionSelector(
                options: const [('NEWS', '일반'), ('NOTICE', '중요')],
                value: _noticeType,
                onChanged: (value) => setState(() => _noticeType = value),
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
              const SizedBox(height: 28),
              const _FormSectionTitle(title: '학사일정 연동'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppDesignTokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppDesignTokens.divider),
                ),
                child: SwitchListTile(
                  value: _isEvent,
                  activeTrackColor: AppDesignTokens.blue,
                  title: const Text(
                    '캘린더에 함께 표시',
                    style: TextStyle(
                      color: AppDesignTokens.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    '공지 기간을 학사일정에도 등록합니다.',
                    style: TextStyle(
                      color: AppDesignTokens.muted,
                      fontSize: 12,
                    ),
                  ),
                  onChanged: (value) => setState(() => _isEvent = value),
                ),
              ),
              if (_isEvent) ...[
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    if (compact) {
                      return Column(
                        children: [
                          _DateField(
                            label: '시작일',
                            date: _eventStartDate,
                            onTap: _selectStartDate,
                          ),
                          const SizedBox(height: 10),
                          _DateField(
                            label: '종료일',
                            date: _eventEndDate,
                            onTap: _selectEndDate,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: '시작일',
                            date: _eventStartDate,
                            onTap: _selectStartDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DateField(
                            label: '종료일',
                            date: _eventEndDate,
                            onTap: _selectEndDate,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 28),
              const _FormSectionTitle(title: '첨부 이미지'),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _images.isEmpty ? '이미지 선택' : '${_images.length}장 추가됨',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppDesignTokens.blue,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppDesignTokens.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => _ImagePreview(
                      image: _images[index],
                      onRemove: () => setState(() => _images.removeAt(index)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          decoration: const BoxDecoration(
            color: AppDesignTokens.surface,
            border: Border(top: BorderSide(color: AppDesignTokens.divider)),
          ),
          child: FilledButton(
            onPressed: _isLoading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignTokens.blue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppDesignTokens.subtle,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
                    isEdit ? '수정 완료' : '공지 등록',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eventStartDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (!mounted || date == null) return;
    setState(() {
      _eventStartDate = date;
      if (_eventEndDate.isBefore(date)) _eventEndDate = date;
    });
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eventEndDate,
      firstDate: _eventStartDate,
      lastDate: DateTime(2030),
    );
    if (!mounted || date == null) return;
    setState(() => _eventEndDate = date);
  }

  static String _apiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
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
      fillColor: AppDesignTokens.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppDesignTokens.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppDesignTokens.blue, width: 1.5),
      ),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle({required this.title, this.subtitle});

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
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppDesignTokens.paleBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Material(
                color: option.$1 == value
                    ? AppDesignTokens.surface
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () => onChanged(option.$1),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: option.$1 == value
                          ? Border.all(color: AppDesignTokens.divider)
                          : null,
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
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppDesignTokens.navy,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: const BorderSide(color: AppDesignTokens.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: AppDesignTokens.blue,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppDesignTokens.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.year}.$month.$day',
                  style: const TextStyle(
                    color: AppDesignTokens.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.image, required this.onRemove});

  final XFile image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppDesignTokens.divider),
            image: DecorationImage(
              image: kIsWeb
                  ? NetworkImage(image.path) as ImageProvider
                  : FileImage(File(image.path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: AppDesignTokens.navy.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
