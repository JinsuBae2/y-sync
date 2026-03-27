import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/community_provider.dart';

// 💡 커뮤니티 게시글을 작성하거나 수정하는 화면입니다.
class CommunityFormScreen extends ConsumerStatefulWidget {
  const CommunityFormScreen({super.key});

  @override
  ConsumerState<CommunityFormScreen> createState() => _CommunityFormScreenState();
}

class _CommunityFormScreenState extends ConsumerState<CommunityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String _category = 'FREE';
  String _targetGrade = 'ALL';
  String _title = '';
  String _content = '';
  bool _anonymous = false;
  List<XFile> _images = [];

  bool _isLoading = false;

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

  // 💡 게시글 저장 함수
  Future<void> _savePost() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      await ref.read(communityNotifierProvider).createPost(
        category: _category,
        title: _title,
        content: _content,
        anonymous: _anonymous,
        targetGrade: _targetGrade,
        imagePaths: _images.map((e) => e.path).toList(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('글 쓰기', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _savePost,
            icon: const Icon(Icons.check, color: Color(0xFF164687)),
            label: const Text('등록', style: TextStyle(color: Color(0xFF164687), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 💡 카테고리 선택 드롭다운
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: '카테고리',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'FREE', child: Text('자유')),
                  DropdownMenuItem(value: 'QA', child: Text('Q&A')),
                  DropdownMenuItem(value: 'TEAM', child: Text('팀원모집')),
                ],
                onChanged: (val) => setState(() => _category = val!),
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
              // 💡 제목 입력
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '제목',
                  hintText: '제목을 입력하세요',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (val) => val == null || val.isEmpty ? '제목을 입력해주세요.' : null,
                onSaved: (val) => _title = val!,
              ),
              const Divider(color: Colors.black12, thickness: 1, height: 1),
              // 💡 본문 입력
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '내용',
                  hintText: '내용을 입력하세요',
                  alignLabelWithHint: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                maxLines: 15,
                validator: (val) => val == null || val.isEmpty ? '내용을 입력해주세요.' : null,
                onSaved: (val) => _content = val!,
              ),
              const Divider(),
              // 💡 이미지 추가 버튼 및 가로 스크롤 미리보기 영역
              Row(
                children: [
                  IconButton(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.camera_alt),
                    color: const Color(0xFF164687), // 💡 요청하신 테마 컬러 #164687
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
              const Divider(),
              // 💡 익명 설정 체크박스 (Flexible을 사용해 오버플로우 방지)
              Row(
                children: [
                  Checkbox(
                    value: _anonymous,
                    activeColor: const Color(0xFF164687),
                    onChanged: (val) => setState(() => _anonymous = val!),
                  ),
                  const Text('익명으로 작성하기', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '(이름 대신 "익명의 학생"으로 표시됩니다)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 💡 하단 큰 등록 버튼 추가
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF164687),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _savePost,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('등록하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
