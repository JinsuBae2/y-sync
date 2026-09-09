import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feedback_provider.dart';
import '../providers/notice_provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_design_tokens.dart';

final _feedbackImageProvider = FutureProvider.autoDispose
    .family<Uint8List?, int>((ref, id) async {
      if (ref.watch(sessionMemberIdProvider) == null) return null;
      final response = await ref
          .watch(dioProvider)
          .get<List<int>>(
            '/admin/feedback/images/$id',
            options: Options(responseType: ResponseType.bytes),
          );
      return Uint8List.fromList(response.data!);
    });

class AdminFeedbackScreen extends ConsumerStatefulWidget {
  const AdminFeedbackScreen({super.key});
  @override
  ConsumerState<AdminFeedbackScreen> createState() =>
      _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends ConsumerState<AdminFeedbackScreen> {
  bool? _reviewed = false;
  int _page = 0;
  final _pending = <int>{};

  Future<void> _review(int id) async {
    if (_pending.contains(id)) return;
    setState(() => _pending.add(id));
    try {
      await ref.read(dioProvider).put('/admin/feedback/$id/reviewed');
      ref.invalidate(adminFeedbackProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('확인 처리에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = adminFeedbackProvider((reviewed: _reviewed, page: _page));
    final data = ref.watch(provider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<bool?>(
                  initialValue: _reviewed,
                  decoration: const InputDecoration(labelText: '사용자 의견'),
                  items: const [
                    DropdownMenuItem(value: false, child: Text('미확인')),
                    DropdownMenuItem(value: true, child: Text('확인')),
                    DropdownMenuItem(value: null, child: Text('전체')),
                  ],
                  onChanged: (value) => setState(() {
                    _reviewed = value;
                    _page = 0;
                  }),
                ),
              ),
              IconButton(
                tooltip: '새로고침',
                onPressed: () => ref.invalidate(provider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: data.when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(provider),
                child: const Text('의견을 불러오지 못했습니다. 다시 시도'),
              ),
            ),
            data: (result) {
              final items = result['content'] as List;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('등록된 의견이 없습니다.')),
                    ),
                  for (final raw in items)
                    _card(Map<String, dynamic>.from(raw as Map)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _page == 0
                            ? null
                            : () => setState(() => _page--),
                        child: const Text('이전'),
                      ),
                      Text('${_page + 1} 페이지'),
                      TextButton(
                        onPressed: result['last'] == true
                            ? null
                            : () => setState(() => _page++),
                        child: const Text('다음'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _card(Map<String, dynamic> item) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      title: Text(
        item['title'] as String,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${feedbackCategories[item['category']]} · ${item['createdAt'].toString().split('T').first}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(item['content'] as String),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '관련 화면: ${item['screen']}\n${item['clientInfo']}',
            style: const TextStyle(fontSize: 12, color: AppDesignTokens.muted),
          ),
        ),
        for (final id in item['imageIds'] as List)
          TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _FeedbackImageDialog(id: id as int),
            ),
            icon: const Icon(Icons.image_outlined),
            label: const Text('첨부 이미지 보기'),
          ),
        if (item['reviewed'] == false)
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: _pending.contains(item['id'])
                  ? null
                  : () => _review(item['id'] as int),
              child: const Text('확인 처리'),
            ),
          )
        else
          const Align(alignment: Alignment.centerRight, child: Text('확인한 의견')),
      ],
    ),
  );
}

class _FeedbackImageDialog extends ConsumerWidget {
  const _FeedbackImageDialog({required this.id});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Dialog(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ref
                .watch(_feedbackImageProvider(id))
                .when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, _) => const Text('이미지를 불러오지 못했습니다.'),
                  data: (bytes) => bytes == null
                      ? const Text('로그인이 필요합니다.')
                      : Image.memory(
                          bytes,
                          errorBuilder: (_, _, _) =>
                              const Text('이미지를 표시할 수 없습니다.'),
                        ),
                ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    ),
  );
}
