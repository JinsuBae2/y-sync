import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notice.dart';
import '../providers/mypage_provider.dart';
import '../providers/notice_feed_provider.dart';
import '../providers/notice_provider.dart';
import '../providers/scrap_provider.dart';
import '../theme/app_design_tokens.dart';
import '../utils/content_detail_navigation.dart';
import '../widgets/content_filter_bar.dart';
import '../widgets/notification_action_button.dart';
import 'notice_form_screen.dart';

class NoticeListScreen extends ConsumerStatefulWidget {
  const NoticeListScreen({super.key});

  @override
  ConsumerState<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends ConsumerState<NoticeListScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _newNoticeTimer;

  /// 💡 새 공지를 확인하는 주기입니다. 공지는 자주 올라오지 않으므로 짧게 잡을 이유가 없습니다.
  static const _newNoticePollInterval = Duration(seconds: 60);

  /// 바닥에서 이만큼 남았을 때 미리 다음 페이지를 불러옵니다. 바닥에 닿은 뒤 부르면 빈 화면이 보입니다.
  static const _loadMoreThreshold = 400.0;

  /// 이보다 위로 올라와 있으면 "새 공지" 칩을 띄웁니다. 최상단에서는 당겨서 새로고침이면 충분합니다.
  static const _chipVisibleOffset = 200.0;

  static const _grades = <(String, String)>[
    ('ALL', '전체'),
    ('GRADE_1', '1학년'),
    ('GRADE_2', '2학년'),
    ('GRADE_3', '3학년'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _newNoticeTimer = Timer.periodic(
      _newNoticePollInterval,
      (_) => ref.read(noticeFeedProvider.notifier).checkForNewNotices(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newNoticeTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 💡 앱을 다시 열었을 때는 주기를 기다리지 않고 바로 확인합니다. 백그라운드에 있는 동안
    //    타이머가 멈춰 있었을 수 있고, 사용자가 가장 궁금해하는 순간이기도 합니다.
    if (state == AppLifecycleState.resumed) {
      ref.read(noticeFeedProvider.notifier).checkForNewNotices();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < _loadMoreThreshold) {
      ref.read(noticeFeedProvider.notifier).loadMore();
    }
    // 칩 노출 조건이 스크롤 위치에 걸려 있어 다시 그려야 합니다.
    setState(() {});
  }

  Future<void> _goToTopAndRefresh() async {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await ref.read(noticeFeedProvider.notifier).refresh();
  }

  void _performSearch() {
    ref
        .read(searchKeywordProvider.notifier)
        .updateKeyword(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(noticeFeedProvider);
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
                if (created == true) ref.invalidate(noticeFeedProvider);
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
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildNoticeList(feedAsync)),
                    // 💡 스크롤을 내린 상태에서만 띄웁니다. 최상단에서는 당겨서 새로고침이면 충분하고,
                    //    읽는 중에 목록을 자동으로 밀어 넣으면 보던 자리를 잃습니다.
                    if (_shouldShowNewNoticeChip(feedAsync))
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _NewNoticeChip(
                            count: feedAsync.value!.newCount,
                            onTap: _goToTopAndRefresh,
                          ),
                        ),
                      ),
                    if (feedAsync.isRefreshing)
                      const Positioned(
                        top: 0,
                        left: 20,
                        right: 20,
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          color: AppDesignTokens.blue,
                          backgroundColor: AppDesignTokens.paleBlue,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 칩은 "새 공지가 있고" + "스크롤을 내려둔 상태"일 때만 띄웁니다.
  bool _shouldShowNewNoticeChip(AsyncValue<NoticeFeedState> feedAsync) {
    final feed = feedAsync.value;
    if (feed == null || feed.newCount <= 0) return false;
    if (!_scrollController.hasClients) return false;
    return _scrollController.offset > _chipVisibleOffset;
  }

  Widget _buildNoticeList(AsyncValue<NoticeFeedState> feedAsync) {
    return feedAsync.when(
      // 💡 더 불러오는 중에도 이미 받은 목록을 계속 보여줍니다. skipLoadingOnReload를 쓰지 않고
      //    상태에 isLoadingMore를 두는 이유가 이것입니다.
      data: (feed) {
        if (feed.isEmpty) {
          return _EmptyNoticeList(
            hasKeyword: ref.read(searchKeywordProvider).trim().isNotEmpty,
            onRefresh: () => ref.read(noticeFeedProvider.notifier).refresh(),
          );
        }

        // 💡 학년 필터는 더 이상 여기서 걸지 않습니다. 서버가 걸러 줍니다.
        //    받은 10건을 클라이언트가 필터하면 0건이 남을 수 있고, 그게 "끝"인지
        //    "이 페이지에 없음"인지 구분할 수 없어 무한 스크롤과 양립하지 못합니다.
        final notices = feed.visibleNotices;

        return RefreshIndicator(
          color: AppDesignTokens.blue,
          onRefresh: () => ref.read(noticeFeedProvider.notifier).refresh(),
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            // 마지막 한 칸은 더 불러오는 중 표시이거나 목록 끝 안내입니다.
            itemCount: notices.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == notices.length) {
                return _FeedFooter(
                  isLoadingMore: feed.isLoadingMore,
                  hasNext: feed.hasNext,
                );
              }
              final notice = notices[index];
              return NoticeCard(
                notice: notice,
                onOpen: () async {
                  final result = await openContentDetail(
                    context,
                    ref,
                    targetType: 'NOTICE',
                    targetId: notice.id,
                  );
                  if (result != null) {
                    ref.invalidate(noticeFeedProvider);
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppDesignTokens.blue),
      ),
      error: (_, _) =>
          _NoticeListError(onRetry: () => ref.invalidate(noticeFeedProvider)),
    );
  }
}

/// 목록 맨 아래에 붙는 한 칸입니다. 더 불러오는 중이면 진행 표시, 끝이면 안내를 보여줍니다.
class _FeedFooter extends StatelessWidget {
  const _FeedFooter({required this.isLoadingMore, required this.hasNext});

  final bool isLoadingMore;
  final bool hasNext;

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppDesignTokens.blue,
            ),
          ),
        ),
      );
    }
    if (hasNext) {
      return const SizedBox(height: 18);
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          '마지막 공지입니다',
          style: TextStyle(color: AppDesignTokens.muted, fontSize: 12),
        ),
      ),
    );
  }
}

/// 스크롤 도중 새 공지가 올라왔을 때 뜨는 칩입니다. 누르면 최상단으로 올라가며 새로고침합니다.
class _NewNoticeChip extends StatelessWidget {
  const _NewNoticeChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesignTokens.blue,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: InkWell(
        key: const ValueKey('notice-new-chip'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                // 상한을 넘으면 서버가 99로 잘라 보냅니다.
                count >= 99 ? '새 공지 99+개' : '새 공지 $count개',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
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
        isGlass: true,
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
      key: ValueKey('notice-card-${notice.id}'),
      color: notice.isPinned
          ? AppDesignTokens.paleBlue.withValues(alpha: 0.58)
          : AppDesignTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppDesignTokens.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
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
                  if (notice.attachments.isNotEmpty) ...[
                    const Icon(
                      Icons.attach_file_rounded,
                      size: 14,
                      color: AppDesignTokens.subtle,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '첨부 ${notice.attachments.length}',
                      style: const TextStyle(
                        color: AppDesignTokens.subtle,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
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
