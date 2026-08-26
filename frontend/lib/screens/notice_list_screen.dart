import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notice.dart';
import '../providers/mypage_provider.dart';
import '../providers/notice_provider.dart';
import '../providers/scrap_provider.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/content_filter_bar.dart';
import '../widgets/notification_action_button.dart';
import 'deep_link_loading_screen.dart';
import 'notice_form_screen.dart';

class NoticeListScreen extends ConsumerStatefulWidget {
  const NoticeListScreen({super.key});

  @override
  ConsumerState<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends ConsumerState<NoticeListScreen> {
  final _searchController = TextEditingController();

  static const _grades = <(String, String)>[
    ('ALL', '전체'),
    ('GRADE_1', '1학년'),
    ('GRADE_2', '2학년'),
    ('GRADE_3', '3학년'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    ref
        .read(searchKeywordProvider.notifier)
        .updateKeyword(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(noticesProvider);
    final selectedGrade = ref.watch(noticeGradeProvider);
    final myPageAsync = ref.watch(myPageProvider);
    final isAdmin = myPageAsync.maybeWhen(
      data: (data) =>
          data.member.role == 'ADMIN' || data.member.role == 'SUPER_ADMIN',
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          '공지사항',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: NotificationActionButton(),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: AppDesignTokens.blue,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              tooltip: '공지 작성',
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const NoticeFormScreen()),
                );
                if (created == true) ref.invalidate(noticesProvider);
              },
              child: const Icon(Icons.edit_outlined),
            )
          : null,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDesignTokens.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Text(
                  '학과의 중요한 소식과 안내를 확인하세요',
                  style: TextStyle(
                    color: AppDesignTokens.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _SearchField(
                controller: _searchController,
                onSearch: _performSearch,
              ),
              const SizedBox(height: 14),
              _GradeFilter(
                selectedGrade: selectedGrade,
                onChanged: (grade) =>
                    ref.read(noticeGradeProvider.notifier).updateGrade(grade),
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildNoticeList(noticesAsync, selectedGrade)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeList(
    AsyncValue<List<Notice>> noticesAsync,
    String selectedGrade,
  ) {
    return noticesAsync.when(
      data: (notices) {
        final filteredNotices = selectedGrade == 'ALL'
            ? notices
            : notices
                  .where(
                    (notice) =>
                        notice.targetGrade == 'ALL' ||
                        notice.targetGrade == selectedGrade,
                  )
                  .toList();

        if (filteredNotices.isEmpty) {
          return _EmptyNoticeList(
            hasKeyword: ref.read(searchKeywordProvider).trim().isNotEmpty,
            onRefresh: () async => ref.invalidate(noticesProvider),
          );
        }

        return RefreshIndicator(
          color: AppDesignTokens.blue,
          onRefresh: () async => ref.invalidate(noticesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
            itemCount: filteredNotices.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppDesignTokens.divider),
            itemBuilder: (context, index) => NoticeCard(
              notice: filteredNotices[index],
              onOpen: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeepLinkLoadingScreen(
                      targetType: 'NOTICE',
                      targetId: '${filteredNotices[index].id}',
                    ),
                  ),
                );
                ref.invalidate(noticesProvider);
              },
            ),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppDesignTokens.blue),
      ),
      error: (_, _) =>
          _NoticeListError(onRetry: () => ref.invalidate(noticesProvider)),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSearch});

  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppDesignTokens.contentPadding,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onSubmitted: (_) => onSearch(),
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            color: AppDesignTokens.navy,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: '공지 제목이나 내용 검색',
            hintStyle: const TextStyle(color: AppDesignTokens.subtle),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppDesignTokens.muted,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '검색어 지우기',
                    onPressed: () {
                      controller.clear();
                      onSearch();
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
            filled: true,
            fillColor: AppDesignTokens.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppDesignTokens.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppDesignTokens.blue,
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradeFilter extends StatelessWidget {
  const _GradeFilter({required this.selectedGrade, required this.onChanged});

  final String selectedGrade;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppDesignTokens.contentPadding,
      child: ContentFilterBar(
        label: '학년',
        icon: Icons.school_outlined,
        options: _NoticeListScreenState._grades,
        selectedValue: selectedGrade,
        onChanged: onChanged,
      ),
    );
  }
}

class NoticeCard extends ConsumerWidget {
  const NoticeCard({super.key, required this.notice, required this.onOpen});

  final Notice notice;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrapsAsync = ref.watch(scrapsProvider);
    final isScrapped = scrapsAsync.maybeWhen(
      data: (scraps) => scraps.any(
        (scrap) => scrap.targetType == 'NOTICE' && scrap.targetId == notice.id,
      ),
      orElse: () => false,
    );
    final isImportant = notice.noticeType == 'NOTICE';

    return Material(
      color: notice.isPinned
          ? AppDesignTokens.paleBlue.withValues(alpha: 0.42)
          : Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _NoticeLabel(
                    label: notice.isPinned ? '고정' : (isImportant ? '중요' : '일반'),
                    isImportant: isImportant || notice.isPinned,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _gradeLabel(notice.targetGrade),
                    style: const TextStyle(
                      color: AppDesignTokens.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: isScrapped ? '스크랩 해제' : '스크랩',
                    onPressed: () => ref
                        .read(scrapNotifierProvider)
                        .toggleScrap('NOTICE', notice.id),
                    icon: Icon(
                      isScrapped
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 21,
                      color: isScrapped
                          ? AppDesignTokens.blue
                          : AppDesignTokens.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                notice.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppDesignTokens.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                notice.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppDesignTokens.muted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      notice.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppDesignTokens.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.visibility_outlined,
                    size: 15,
                    color: AppDesignTokens.subtle,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${notice.viewCount}',
                    style: const TextStyle(
                      color: AppDesignTokens.subtle,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: AppDesignTokens.subtle,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${notice.commentCount}',
                    style: const TextStyle(
                      color: AppDesignTokens.subtle,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _shortDate(notice.createdAt),
                    style: const TextStyle(
                      color: AppDesignTokens.subtle,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value.split('T').first;
    return '${date.month}.${date.day.toString().padLeft(2, '0')}';
  }

  static String _gradeLabel(String grade) {
    return switch (grade) {
      'GRADE_1' => '1학년',
      'GRADE_2' => '2학년',
      'GRADE_3' => '3학년',
      _ => '전체 학년',
    };
  }
}

class _NoticeLabel extends StatelessWidget {
  const _NoticeLabel({required this.label, required this.isImportant});

  final String label;
  final bool isImportant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isImportant
            ? AppDesignTokens.coral.withValues(alpha: 0.1)
            : AppDesignTokens.paleBlue,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isImportant ? AppDesignTokens.coral : AppDesignTokens.blue,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyNoticeList extends StatelessWidget {
  const _EmptyNoticeList({required this.hasKeyword, required this.onRefresh});

  final bool hasKeyword;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppDesignTokens.blue,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 76),
        children: [
          const Icon(
            Icons.campaign_outlined,
            size: 42,
            color: AppDesignTokens.subtle,
          ),
          const SizedBox(height: 14),
          Text(
            hasKeyword ? '검색 결과가 없습니다.' : '등록된 공지가 없습니다.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppDesignTokens.navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasKeyword ? '다른 검색어를 입력해보세요.' : '새 공지가 등록되면 알려드릴게요.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppDesignTokens.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _NoticeListError extends StatelessWidget {
  const _NoticeListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '공지사항을 불러오지 못했습니다.',
            style: TextStyle(
              color: AppDesignTokens.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
