import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  String _title = '';
  String _content = '';
  bool _anonymous = false;

  bool _isLoading = false;

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
          TextButton(
            onPressed: _isLoading ? null : _savePost,
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('완료', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                items: const [
                  DropdownMenuItem(value: 'FREE', child: Text('자유')),
                  DropdownMenuItem(value: 'QA', child: Text('Q&A')),
                  DropdownMenuItem(value: 'TEAM', child: Text('팀원모집')),
                ],
                onChanged: (val) => setState(() => _category = val!),
              ),
              const SizedBox(height: 20),
              // 💡 제목 입력
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '제목',
                  hintText: '제목을 입력하세요',
                  border: UnderlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? '제목을 입력해주세요.' : null,
                onSaved: (val) => _title = val!,
              ),
              const SizedBox(height: 20),
              // 💡 본문 입력
              TextFormField(
                decoration: const InputDecoration(
                  hintText: '내용을 입력하세요',
                  border: InputBorder.none,
                ),
                maxLines: 15,
                validator: (val) => val == null || val.isEmpty ? '내용을 입력해주세요.' : null,
                onSaved: (val) => _content = val!,
              ),
              const Divider(),
              // 💡 익명 설정 체크박스
              Row(
                children: [
                  Checkbox(
                    value: _anonymous,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (val) => setState(() => _anonymous = val!),
                  ),
                  const Text('익명으로 작성하기', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(
                    '(이름 대신 "익명의 학생"으로 표시됩니다)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
