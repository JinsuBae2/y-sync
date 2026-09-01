import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/calendar_event.dart';
import '../models/community_post.dart';
import '../models/notice.dart';
import '../providers/auth_provider.dart';
import '../providers/home_provider.dart';
import '../providers/notice_provider.dart';
import '../utils/content_detail_navigation.dart';
import '../widgets/brand_logo.dart';
import '../widgets/notification_action_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onOpenNotices,
    required this.onOpenCommunity,
    required this.onOpenSchedule,
  });

  final VoidCallback onOpenNotices;
  final VoidCallback onOpenCommunity;
  final VoidCallback onOpenSchedule;

  static const _navy = Color(0xFF10213F);
  static const _blue = Color(0xFF246BFD);
  static const _coral = Color(0xFFFF6258);
  static const _background = Color(0xFFF5F7FA);
  static const _paleBlue = Color(0xFFEAF1FF);
  static const _divider = Color(0xFFE1E6EE);
  static const _muted = Color(0xFF697386);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final noticesAsync = ref.watch(homeNoticesProvider);
    final eventsAsync = ref.watch(homeCalendarEventsProvider);
    final postsAsync = ref.watch(homeCommunityPostsProvider);
    final memberName = authState.asData?.value?.name ?? '학생';

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              color: _blue,
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
                children: [
                  _HomeHeader(memberName: memberName),
                  const SizedBox(height: 26),
                  _buildPinnedNotice(context, ref, noticesAsync),
                  const SizedBox(height: 30),
                  _SectionHeader(
                    title: '다가오는 학사일정',
                    actionLabel: '전체 일정',
                    onAction: onOpenSchedule,
                  ),
                  const SizedBox(height: 12),
                  _buildUpcomingEvents(eventsAsync),
                  const SizedBox(height: 32),
                  _SectionHeader(
                    title: '최근 공지',
                    actionLabel: '전체 보기',
                    onAction: () => _openNoticeList(ref),
                  ),
                  const SizedBox(height: 10),
                  _buildRecentNotices(context, ref, noticesAsync),
                  const SizedBox(height: 32),
                  _SectionHeader(
                    title: '커뮤니티 인기글',
                    actionLabel: '전체 보기',
                    onAction: onOpenCommunity,
                  ),
                  const SizedBox(height: 10),
                  _buildPopularPosts(context, ref, postsAsync),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(homeNoticesProvider);
    ref.invalidate(homeCalendarEventsProvider);
    ref.invalidate(homeCommunityPostsProvider);
    await Future.wait([
      ref.read(homeNoticesProvider.future),
      ref.read(homeCalendarEventsProvider.future),
      ref.read(homeCommunityPostsProvider.future),
    ]);
  }

  Widget _buildPinnedNotice(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Notice>> noticesAsync,
  ) {
    return noticesAsync.when(
      data: (notices) {
        final featured = _featuredNotice(notices);
        if (featured == null) return const SizedBox.shrink();
        return _PinnedNoticeHero(
          notice: featured,
          deadlineLabel: _noticeDeadlineLabel(featured),
          gradeLabel: _gradeLabel(featured.targetGrade),
          onTap: () => _openNotice(context, ref, featured),
        );
      },
      loading: () => const _LoadingBlock(height: 214),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildUpcomingEvents(AsyncValue<List<CalendarEvent>> eventsAsync) {
    return eventsAsync.when(
      data: (events) {
        final upcoming = _upcomingEvents(events).take(2).toList();
        if (upcoming.isEmpty) {
          return const _EmptyRow(
            icon: Icons.event_available_outlined,
            message: '예정된 학사일정이 없습니다.',
          );
        }
        return Column(
          children: [
            for (var index = 0; index < upcoming.length; index++) ...[
              _AcademicEventRow(
                event: upcoming[index],
                dDayLabel: _eventDDayLabel(upcoming[index]),
                onTap: onOpenSchedule,
              ),
              if (index != upcoming.length - 1)
                const Divider(height: 1, color: _divider),
            ],
          ],
        );
      },
      loading: () => const _LoadingRows(count: 2),
      error: (error, stackTrace) => _InlineError(onRetry: onOpenSchedule),
    );
  }

  Widget _buildRecentNotices(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Notice>> noticesAsync,
  ) {
    return noticesAsync.when(
      data: (notices) {
        final featuredId = _featuredNotice(notices)?.id;
        final recent = _recentNotices(
          notices,
          excludedId: featuredId,
        ).take(2).toList();
        if (recent.isEmpty) {
          return const _EmptyRow(
            icon: Icons.article_outlined,
            message: '등록된 공지가 없습니다.',
          );
        }
        return Column(
          children: [
            for (var index = 0; index < recent.length; index++) ...[
              _NoticePreviewRow(
                notice: recent[index],
                isNew: _isNew(recent[index].createdAt),
                onTap: () => _openNotice(context, ref, recent[index]),
              ),
              if (index != recent.length - 1)
                const Divider(height: 1, color: _divider),
            ],
          ],
        );
      },
      loading: () => const _LoadingRows(count: 2),
      error: (error, stackTrace) =>
          _InlineError(onRetry: () => ref.invalidate(homeNoticesProvider)),
    );
  }

  Widget _buildPopularPosts(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<CommunityPost>> postsAsync,
  ) {
    return postsAsync.when(
      data: (posts) {
        final popular = _popularPosts(posts).take(2).toList();
        if (popular.isEmpty) {
          return const _EmptyRow(
            icon: Icons.forum_outlined,
            message: '등록된 커뮤니티 글이 없습니다.',
          );
        }
        return Column(
          children: [
            for (var index = 0; index < popular.length; index++) ...[
              _CommunityPreviewRow(
                post: popular[index],
                onTap: () => _openCommunityPost(context, ref, popular[index]),
              ),
              if (index != popular.length - 1)
                const Divider(height: 1, color: _divider),
            ],
          ],
        );
      },
      loading: () => const _LoadingRows(count: 2),
      error: (error, stackTrace) => _InlineError(
        onRetry: () => ref.invalidate(homeCommunityPostsProvider),
      ),
    );
  }

  Future<void> _openNotice(
    BuildContext context,
    WidgetRef ref,
    Notice notice,
  ) async {
    final changed = await openContentDetail(
      context,
      ref,
      targetType: 'NOTICE',
      targetId: notice.id,
    );
    if (changed == true) {
      ref.invalidate(homeNoticesProvider);
    }
  }

  Future<void> _openCommunityPost(
    BuildContext context,
    WidgetRef ref,
    CommunityPost post,
  ) async {
    final changed = await openContentDetail(
      context,
      ref,
      targetType: 'COMMUNITY',
      targetId: post.id,
    );
    if (changed == true) {
      ref.invalidate(homeCommunityPostsProvider);
    }
  }

  void _openNoticeList(WidgetRef ref) {
    ref.read(searchKeywordProvider.notifier).updateKeyword('');
    ref.read(noticeGradeProvider.notifier).updateGrade('ALL');
    onOpenNotices();
  }

  static Notice? _featuredNotice(List<Notice> notices) {
    for (final notice in notices) {
      if (notice.isPinned) return notice;
    }
    for (final notice in notices) {
      if (notice.noticeType == 'NOTICE') return notice;
    }
    return null;
  }

  static List<Notice> _recentNotices(List<Notice> notices, {int? excludedId}) {
    final sorted = notices.where((notice) => notice.id != excludedId).toList();
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  static List<CalendarEvent> _upcomingEvents(List<CalendarEvent> events) {
    final today = DateUtils.dateOnly(DateTime.now());
    return events.where((event) {
      final end = DateTime.tryParse(event.endDate);
      return end != null && !DateUtils.dateOnly(end).isBefore(today);
    }).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  static List<CommunityPost> _popularPosts(List<CommunityPost> posts) {
    final sorted = posts.where((post) => !post.isDeleted).toList();
    sorted.sort((a, b) {
      final aScore = a.viewCount + (a.commentCount * 3);
      final bScore = b.viewCount + (b.commentCount * 3);
      final scoreComparison = bScore.compareTo(aScore);
      if (scoreComparison != 0) return scoreComparison;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  static String? _noticeDeadlineLabel(Notice notice) {
    final rawDate = notice.eventStartDate ?? notice.eventEndDate;
    final date = rawDate == null ? null : DateTime.tryParse(rawDate);
    if (date == null) return null;
    final days = DateUtils.dateOnly(
      date,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    if (days < 0) return null;
    return days == 0 ? '오늘 마감' : '마감 D-$days';
  }

  static String _eventDDayLabel(CalendarEvent event) {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateTime.tryParse(event.startDate);
    final end = DateTime.tryParse(event.endDate);
    if (start == null || end == null) return '';
    if (DateUtils.dateOnly(start).isBefore(today) &&
        !DateUtils.dateOnly(end).isBefore(today)) {
      return '진행 중';
    }
    final days = DateUtils.dateOnly(start).difference(today).inDays;
    if (days == 0) return 'D-DAY';
    return days > 0 ? 'D-$days' : '';
  }

  static String _gradeLabel(String grade) {
    switch (grade) {
      case 'GRADE_1':
        return '1학년';
      case 'GRADE_2':
        return '2학년';
      case 'GRADE_3':
        return '3학년';
      default:
        return '전체 학년';
    }
  }

  static bool _isNew(String createdAt) {
    final date = DateTime.tryParse(createdAt);
    if (date == null) return false;
    final difference = DateTime.now().difference(date);
    return !difference.isNegative && difference.inHours < 48;
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.memberName});

  final String memberName;

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('M월 d일 EEEE', 'ko_KR').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BrandLogo(size: 40, padding: 3),
            const SizedBox(width: 8),
            const Text(
              'Y-Sync',
              style: TextStyle(
                color: HomeScreen._navy,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: HomeScreen._paleBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const NotificationActionButton(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: HomeScreen._blue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          dateText,
          style: const TextStyle(
            color: HomeScreen._muted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '안녕하세요, $memberName님',
          style: const TextStyle(
            color: HomeScreen._navy,
            fontSize: 30,
            height: 1.25,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PinnedNoticeHero extends StatelessWidget {
  const _PinnedNoticeHero({
    required this.notice,
    required this.deadlineLabel,
    required this.gradeLabel,
    required this.onTap,
  });

  final Notice notice;
  final String? deadlineLabel;
  final String gradeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeScreen._navy,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      shadowColor: HomeScreen._navy.withValues(alpha: 0.16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            const Positioned(
              right: 18,
              bottom: 18,
              child: Icon(
                Icons.campaign_outlined,
                size: 142,
                color: Colors.white12,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: HomeScreen._coral,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '필독',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (deadlineLabel != null)
                        Text(
                          deadlineLabel!,
                          style: const TextStyle(
                            color: HomeScreen._coral,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 470),
                    child: Text(
                      notice.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Text(
                        gradeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(width: 1, height: 16, color: Colors.white24),
                      const SizedBox(width: 14),
                      const Text(
                        '자세히 보기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: HomeScreen._navy,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: HomeScreen._navy,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right_rounded, size: 20),
          label: Text(actionLabel),
          style: TextButton.styleFrom(
            foregroundColor: HomeScreen._blue,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            minimumSize: const Size(44, 44),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _AcademicEventRow extends StatelessWidget {
  const _AcademicEventRow({
    required this.event,
    required this.dDayLabel,
    required this.onTap,
  });

  final CalendarEvent event;
  final String dDayLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(event.startDate);
    final dateLabel = date == null
        ? event.startDate
        : DateFormat('MM.dd').format(date);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HomeScreen._paleBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    color: HomeScreen._navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomeScreen._navy,
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (dDayLabel.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  dDayLabel,
                  style: const TextStyle(
                    color: HomeScreen._blue,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: HomeScreen._muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticePreviewRow extends StatelessWidget {
  const _NoticePreviewRow({
    required this.notice,
    required this.isNew,
    required this.onTap,
  });

  final Notice notice;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(notice.createdAt);
    final dateLabel = date == null ? '' : DateFormat('MM.dd').format(date);
    final typeLabel = notice.noticeType == 'NOTICE' ? '공지' : '일반';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: HomeScreen._paleBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.article_outlined,
                  color: HomeScreen._blue,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomeScreen._navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: HomeScreen._paleBlue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeLabel,
                            style: const TextStyle(
                              color: HomeScreen._blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isNew)
                          const Text(
                            'NEW',
                            style: TextStyle(
                              color: HomeScreen._coral,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                dateLabel,
                style: const TextStyle(
                  color: HomeScreen._muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, color: HomeScreen._muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityPreviewRow extends StatelessWidget {
  const _CommunityPreviewRow({required this.post, required this.onTap});

  final CommunityPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final author = post.anonymous ? '익명' : post.authorName;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: HomeScreen._muted,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: HomeScreen._navy),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _communityCategoryLabel(post.category),
                            style: const TextStyle(
                              color: HomeScreen._navy,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomeScreen._navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '$author · ${_relativeTime(post.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomeScreen._muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: HomeScreen._muted,
                size: 18,
              ),
              const SizedBox(width: 5),
              Text(
                '${post.commentCount}',
                style: const TextStyle(
                  color: HomeScreen._muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, color: HomeScreen._muted),
            ],
          ),
        ),
      ),
    );
  }

  static String _communityCategoryLabel(String category) {
    switch (category) {
      case 'QA':
        return '질문';
      case 'TEAM':
        return '팀원';
      default:
        return '자유';
    }
  }

  static String _relativeTime(String createdAt) {
    final date = DateTime.tryParse(createdAt);
    if (date == null) return createdAt;
    final difference = DateTime.now().difference(date);
    if (difference.isNegative || difference.inMinutes < 1) return '방금 전';
    if (difference.inMinutes < 60) return '${difference.inMinutes}분 전';
    if (difference.inHours < 24) return '${difference.inHours}시간 전';
    if (difference.inDays < 7) return '${difference.inDays}일 전';
    return DateFormat('MM.dd').format(date);
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF3),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _LoadingRows extends StatelessWidget {
  const _LoadingRows({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < count; index++) ...[
          const _LoadingBlock(height: 68),
          if (index != count - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HomeScreen._divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: HomeScreen._muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: HomeScreen._muted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '내용을 불러오지 못했습니다.',
            style: TextStyle(color: HomeScreen._muted, fontSize: 14),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    );
  }
}
