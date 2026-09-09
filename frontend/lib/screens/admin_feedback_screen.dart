import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feedback_provider.dart';
import '../providers/notice_provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/selection_highlight.dart';

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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppDesignTokens.paleBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.forum_outlined,
                      color: AppDesignTokens.blue,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '사용자 의견함',
                          style: TextStyle(
                            color: AppDesignTokens.navy,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '오류 신고와 개선 제안을 확인합니다.',
                          style: TextStyle(
                            color: AppDesignTokens.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '새로고침',
                    onPressed: () => ref.invalidate(provider),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                height: 42,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppDesignTokens.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppDesignTokens.divider),
                ),
                child: Row(
                  children: [
                    _AdminFilterOption(
                      label: '미확인',
                      icon: Icons.mark_email_unread_outlined,
                      selected: _reviewed == false,
                      onTap: () => _setFilter(false),
                    ),
                    _AdminFilterOption(
                      label: '확인',
                      icon: Icons.task_alt_rounded,
                      selected: _reviewed == true,
                      onTap: () => _setFilter(true),
                    ),
                    _AdminFilterOption(
                      label: '전체',
                      icon: Icons.inbox_outlined,
                      selected: _reviewed == null,
                      onTap: () => _setFilter(null),
                    ),
                  ],
                ),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Row(
                    children: [
                      Text(
                        _reviewed == false
                            ? '확인이 필요한 의견'
                            : (_reviewed == true ? '확인한 의견' : '모든 의견'),
                        style: const TextStyle(
                          color: AppDesignTokens.navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '총 ${result['totalElements'] ?? items.length}건',
                        style: const TextStyle(
                          color: AppDesignTokens.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 46),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignTokens.divider),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.mark_email_read_outlined,
                            size: 34,
                            color: AppDesignTokens.subtle,
                          ),
                          SizedBox(height: 10),
                          Text(
                            '등록된 의견이 없습니다.',
                            style: TextStyle(color: AppDesignTokens.muted),
                          ),
                        ],
                      ),
                    ),
                  for (final raw in items)
                    _card(Map<String, dynamic>.from(raw as Map)),
                  if (_page > 0 || result['last'] != true) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: '이전 페이지',
                          onPressed: _page == 0
                              ? null
                              : () => setState(() => _page--),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_page + 1} 페이지',
                            style: const TextStyle(
                              color: AppDesignTokens.navy,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '다음 페이지',
                          onPressed: result['last'] == true
                              ? null
                              : () => setState(() => _page++),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _setFilter(bool? reviewed) {
    setState(() {
      _reviewed = reviewed;
      _page = 0;
    });
  }

  Widget _card(Map<String, dynamic> item) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    color: AppDesignTokens.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: item['reviewed'] == false
            ? AppDesignTokens.blue.withValues(alpha: 0.35)
            : AppDesignTokens.divider,
      ),
    ),
    child: ExpansionTile(
      tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      iconColor: AppDesignTokens.blue,
      collapsedIconColor: AppDesignTokens.subtle,
      title: Text(
        item['title'] as String,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppDesignTokens.navy,
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            _MetaBadge(
              label: feedbackCategories[item['category']] ?? '기타 의견',
              emphasized: item['category'] == 'BUG',
            ),
            _MetaBadge(
              label: item['reviewed'] == false ? '미확인' : '확인',
              emphasized: item['reviewed'] == false,
            ),
            _MetaBadge(
              label: item['createdAt'].toString().split('T').first,
              emphasized: false,
            ),
          ],
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      children: [
        const Divider(height: 1, color: AppDesignTokens.divider),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppDesignTokens.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            item['content'] as String,
            style: const TextStyle(
              color: AppDesignTokens.navy,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                icon: Icons.smartphone_outlined,
                label: '관련 화면',
                value: (item['screen'] as String).isEmpty
                    ? '입력 없음'
                    : item['screen'],
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.devices_outlined,
                label: '실행 환경',
                value: item['clientInfo'] as String,
              ),
            ],
          ),
        ),
        if ((item['imageIds'] as List).isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final indexed in (item['imageIds'] as List).indexed)
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _FeedbackImageDialog(id: indexed.$2 as int),
                  ),
                  icon: const Icon(Icons.image_outlined, size: 17),
                  label: Text('첨부 ${indexed.$1 + 1}'),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (item['reviewed'] == false)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: ValueKey('admin-feedback-review-${item['id']}'),
              onPressed: _pending.contains(item['id'])
                  ? null
                  : () => _review(item['id'] as int),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('확인 완료로 표시'),
            ),
          )
        else
          const Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color: AppDesignTokens.blue,
                ),
                SizedBox(width: 6),
                Text(
                  '확인한 의견',
                  style: TextStyle(
                    color: AppDesignTokens.blue,
                    fontSize: 12,
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

class _AdminFilterOption extends StatelessWidget {
  const _AdminFilterOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppDesignTokens.blue : AppDesignTokens.muted,
            ),
            const SizedBox(width: 6),
            SelectionHighlight(
              selected: selected,
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppDesignTokens.navy
                      : AppDesignTokens.muted,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label, required this.emphasized});
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: emphasized ? AppDesignTokens.paleBlue : AppDesignTokens.background,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: emphasized ? AppDesignTokens.blue : AppDesignTokens.muted,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: AppDesignTokens.subtle),
      const SizedBox(width: 8),
      SizedBox(
        width: 58,
        child: Text(
          label,
          style: const TextStyle(color: AppDesignTokens.muted, fontSize: 12),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            color: AppDesignTokens.navy,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
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
