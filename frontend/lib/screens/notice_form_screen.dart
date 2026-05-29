import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
  String _targetGrade = 'ALL';
  bool _isLoading = false;
  List<XFile> _images = [];
  bool _isEvent = false;
  DateTime _eventStartDate = DateTime.now();
  DateTime _eventEndDate = DateTime.now();

  // 💡 기기에서 이미지를 여러 장 선택하는 함수
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> selectedImages = await picker.pickMultiImage();
    if (selectedImages.isNotEmpty) {
      setState(() {
        _images.addAll(selectedImages);
      });
    }
  }

  // 💡 선택된 이미지 삭제 함수
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  @override
  void initState() {
    super.initState();
    final isEdit = widget.notice != null;
    _titleController = TextEditingController(text: isEdit ? widget.notice!.title : '');
    _contentController = TextEditingController(text: isEdit ? widget.notice!.content : '');
    if (isEdit) {
      _noticeType = widget.notice!.noticeType;
      _targetGrade = widget.notice!.targetGrade;
      _isEvent = widget.notice!.eventStartDate != null;
      if (_isEvent) {
        _eventStartDate = DateTime.parse(widget.notice!.eventStartDate!);
        _eventEndDate = DateTime.parse(widget.notice!.eventEndDate!);
      }
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
      final List<String> paths = _images.map((e) => e.path).toList();
      final startStr = _isEvent ? "${_eventStartDate.year}-${_eventStartDate.month.toString().padLeft(2, '0')}-${_eventStartDate.day.toString().padLeft(2, '0')}" : null;
      final endStr = _isEvent ? "${_eventEndDate.year}-${_eventEndDate.month.toString().padLeft(2, '0')}-${_eventEndDate.day.toString().padLeft(2, '0')}" : null;

      if (widget.notice == null) {
        await notifier.createNotice(title, content, _noticeType, targetGrade: _targetGrade, imagePaths: paths, eventStartDate: startStr, eventEndDate: endStr);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공지사항이 등록되었습니다.')),
          );
        }
      } else {
        await notifier.updateNotice(widget.notice!.id, title, content, _noticeType, targetGrade: _targetGrade, imagePaths: paths, eventStartDate: startStr, eventEndDate: endStr);
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
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: const Icon(Icons.check, color: Color(0xFF164687)),
            label: const Text('등록', style: TextStyle(color: Color(0xFF164687), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _noticeType,
              decoration: const InputDecoration(
                labelText: '공지 타입', 
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
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
            const Divider(color: Colors.black12, thickness: 1, height: 1),
            const SizedBox(height: 16),
            // 💡 대상 학년 칩 필터
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('대상 학년 필터', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8.0,
                  children: ['ALL', 'GRADE_1', 'GRADE_2', 'GRADE_3'].map((grade) {
                    final Map<String, String> gradeLabels = {
                      'ALL': '전체',
                      'GRADE_1': '1학년',
                      'GRADE_2': '2학년',
                      'GRADE_3': '3학년',
                    };
                    final isSelected = _targetGrade == grade;
                    return ChoiceChip(
                      label: Text(gradeLabels[grade]!),
                      selected: isSelected,
                      selectedColor: const Color(0xFF164687),
                      backgroundColor: Colors.grey.shade200,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _targetGrade = grade);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.black12, thickness: 1, height: 1),
            // 💡 학사 일정 연동 섹션 추가
            SwitchListTile(
              title: const Text('학사 일정(캘린더)에 연동', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('캘린더에 연동되면 학생들이 달력에서 볼 수 있습니다.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              value: _isEvent,
              activeColor: const Color(0xFF164687),
              onChanged: (bool value) {
                setState(() => _isEvent = value);
              },
            ),
            if (_isEvent) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _eventStartDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setState(() {
                              _eventStartDate = date;
                              if (_eventEndDate.isBefore(_eventStartDate)) {
                                _eventEndDate = _eventStartDate;
                              }
                            });
                          }
                        },
                        child: Text('시작일: ${_eventStartDate.year}-${_eventStartDate.month.toString().padLeft(2, '0')}-${_eventStartDate.day.toString().padLeft(2, '0')}'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _eventEndDate,
                            firstDate: _eventStartDate,
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setState(() => _eventEndDate = date);
                          }
                        },
                        child: Text('종료일: ${_eventEndDate.year}-${_eventEndDate.month.toString().padLeft(2, '0')}-${_eventEndDate.day.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(color: Colors.black12, thickness: 1, height: 1),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목', 
                hintText: '제목을 입력하세요',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const Divider(color: Colors.black12, thickness: 1, height: 1),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: '내용',
                  hintText: '내용을 입력하세요',
                  alignLabelWithHint: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const Divider(color: Colors.black12, thickness: 1, height: 1),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            // 💡 -------------------------
            // 이미지 추가 버튼 및 가로 스크롤 미리보기 영역
            Row(
              children: [
                IconButton(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.camera_alt),
                  color: const Color(0xFF164687), // 💡 테마 컬러 #164687
                  iconSize: 32,
                ),
                const Text('사진 추가', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF164687))),
              ],
            ),
            if (_images.isNotEmpty)
              Container(
                height: 100,
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            image: DecorationImage(
                              image: FileImage(File(_images[index].path)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 16,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            // -------------------------
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF164687),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isEdit ? '수정하기' : '등록하기', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
