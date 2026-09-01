import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../providers/scrap_provider.dart';
import '../theme/app_design_tokens.dart';
import '../utils/content_detail_navigation.dart';
import '../utils/image_url_helper.dart';
import '../widgets/content_filter_bar.dart';
import '../widgets/notification_action_button.dart';
import 'community_form_screen.dart';

class CommunityListScreen extends ConsumerStatefulWidget {
  const CommunityListScreen({super.key, this.isAdminMode = false});

  final bool isAdminMode;

  @override
  ConsumerState<CommunityListScreen> createState() =>
      _CommunityListScreenState();
}

class _CommunityListScreenState extends ConsumerState<CommunityListScreen> {
  final _searchController = TextEditingController();

  static const categories = <(String, String)>[
    ('ALL', '전체'),
    ('QA', 'Q&A'),
    ('TEAM', '팀원 모집'),
    ('FREE', '자유'),
  ];
  static const grades = <(String, String)>[
    ('ALL', '전체 학년'),
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
        .read(communitySearchKeywordProvider.notifier)
        .updateKeyword(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(communityPostsProvider);
    final selectedCategory = ref.watch(communityCategoryProvider);
    final selectedGrade = ref.watch(communityGradeProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.sizeOf(context).width < 900 ? 76 : 0,
        ),
        child: FloatingActionButton(
          backgroundColor: AppDesignTokens.blue,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tooltip: '글쓰기',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CommunityFormScreen()),
          ),
          child: const Icon(Icons.edit_outlined),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDesignTokens.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _CommunityHeader(),
                _SearchField(
                  controller: _searchController,
                  onSearch: _performSearch,
                ),
                const SizedBox(height: 16),
                _FilterBar(
                  selectedCategory: selectedCategory,
                  selectedGrade: selectedGrade,
                  onCategoryChanged: (value) => ref
                      .read(communityCategoryProvider.notifier)
                      .updateCategory(value),
                  onGradeChanged: (value) => ref
                      .read(communityGradeProvider.notifier)
                      .updateGrade(value),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildPosts(
                          postsAsync,
                          selectedGrade: selectedGrade,
                        ),
                      ),
                      if (postsAsync.isRefreshing)
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
      ),
    );
  }

  Widget _buildPosts(
    AsyncValue<List<CommunityPost>> postsAsync, {
    required String selectedGrade,
  }) {
    return postsAsync.when(
      data: (allPosts) {
        final visiblePosts = widget.isAdminMode
            ? allPosts
            : allPosts.where((post) => !post.isDeleted).toList();
        final posts = selectedGrade == 'ALL'
            ? visiblePosts
            : visiblePosts
                  .where(
                    (post) =>
                        post.targetGrade == 'ALL' ||
                        post.targetGrade == selectedGrade,
                  )
                  .toList();

        if (posts.isEmpty) {
          final keyword = ref.read(communitySearchKeywordProvider);
          return _EmptyCommunity(
            keyword: keyword,
            onRefresh: () async => ref.invalidate(communityPostsProvider),
          );
        }

        return RefreshIndicator(
          color: AppDesignTokens.blue,
          onRefresh: () async => ref.invalidate(communityPostsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => CommunityPostCard(
              post: posts[index],
              onOpen: () async {
                final result = await openContentDetail(
                  context,
                  ref,
                  targetType: 'COMMUNITY',
                  targetId: posts[index].id,
                );
                if (result != null) {
                  ref.invalidate(communityPostsProvider);
                }
              },
            ),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppDesignTokens.blue),
      ),
      error: (error, _) => _CommunityError(
        onRetry: () => ref.invalidate(communityPostsProvider),
      ),
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 20),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '커뮤니티',
                  style: TextStyle(
                    color: AppDesignTokens.navy,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '학우들과 필요한 이야기를 나눠보세요',
                  style: TextStyle(
                    color: AppDesignTokens.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppDesignTokens.paleBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const NotificationActionButton(),
          ),
        ],
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppDesignTokens.navy.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
        ),
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
              hintText: '제목이나 내용 검색',
              hintStyle: const TextStyle(color: AppDesignTokens.subtle),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppDesignTokens.muted,
              ),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '검색어 지우기',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        controller.clear();
                        onSearch();
                      },
                    ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.76),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppDesignTokens.blue,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedCategory,
    required this.selectedGrade,
    required this.onCategoryChanged,
    required this.onGradeChanged,
  });

  final String selectedCategory;
  final String selectedGrade;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onGradeChanged;

  static const _categories = _CommunityListScreenState.categories;
  static const _grades = _CommunityListScreenState.grades;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppDesignTokens.contentPadding,
      child: Column(
        children: [
          ContentFilterBar(
            label: '분류',
            icon: Icons.grid_view_rounded,
            options: _categories,
            selectedValue: selectedCategory,
            onChanged: onCategoryChanged,
            isGlass: true,
          ),
          const SizedBox(height: 8),
          ContentFilterBar(
            label: '학년',
            icon: Icons.school_outlined,
            options: _grades,
            selectedValue: selectedGrade,
            onChanged: onGradeChanged,
            isGlass: true,
          ),
        ],
      ),
    );
  }
}

class CommunityPostCard extends ConsumerWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.onOpen,
  });

  final CommunityPost post;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrapsAsync = ref.watch(scrapsProvider);
    final isScrapped = scrapsAsync.maybeWhen(
      data: (scraps) => scraps.any(
        (scrap) => scrap.targetType == 'COMMUNITY' && scrap.targetId == post.id,
      ),
      orElse: () => false,
    );
    final imageUrls = post.imageUrls;
    final hasImage = imageUrls != null && imageUrls.isNotEmpty;

    return Material(
      key: ValueKey('community-post-${post.id}'),
      color: post.isPinned
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
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _PostLabel(post: post),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${post.authorName} · ${_shortDate(post.createdAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppDesignTokens.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          post.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppDesignTokens.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          post.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppDesignTokens.muted,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: 14),
                    Container(
                      key: ValueKey('community-post-thumbnail-${post.id}'),
                      width: 76,
                      height: 76,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppDesignTokens.divider),
                      ),
                      child: Image.network(
                        getCleanImageUrl(imageUrls.first),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppDesignTokens.paleBlue,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppDesignTokens.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 15,
                    color: AppDesignTokens.subtle,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.viewCount}',
                    style: const TextStyle(
                      color: AppDesignTokens.subtle,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: AppDesignTokens.subtle,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.commentCount}',
                    style: const TextStyle(
                      color: AppDesignTokens.subtle,
                      fontSize: 12,
                    ),
                  ),
                  if (post.attachments.isNotEmpty) ...[
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.attach_file_rounded,
                      size: 15,
                      color: AppDesignTokens.subtle,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${post.attachments.length}',
                      style: const TextStyle(
                        color: AppDesignTokens.subtle,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const Spacer(),
                  SizedBox.square(
                    dimension: 36,
                    child: IconButton(
                      key: ValueKey('community-post-bookmark-${post.id}'),
                      padding: EdgeInsets.zero,
                      tooltip: isScrapped ? '스크랩 해제' : '스크랩',
                      onPressed: () => ref
                          .read(scrapNotifierProvider)
                          .toggleScrap('COMMUNITY', post.id),
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
}

class _PostLabel extends StatelessWidget {
  const _PostLabel({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final label = switch (post.category) {
      'QA' => 'Q&A',
      'TEAM' => '팀원 모집',
      _ => '자유',
    };
    final text = post.isPinned ? '고정' : label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: post.isPinned ? AppDesignTokens.navy : AppDesignTokens.paleBlue,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: post.isPinned ? Colors.white : AppDesignTokens.blue,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyCommunity extends StatelessWidget {
  const _EmptyCommunity({required this.keyword, required this.onRefresh});

  final String keyword;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 76),
        children: [
          const Icon(
            Icons.forum_outlined,
            size: 42,
            color: AppDesignTokens.subtle,
          ),
          const SizedBox(height: 14),
          Text(
            keyword.isEmpty ? '아직 게시글이 없습니다.' : '검색 결과가 없습니다.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppDesignTokens.navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            keyword.isEmpty ? '첫 이야기를 남겨보세요.' : '다른 검색어를 입력해보세요.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppDesignTokens.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CommunityError extends StatelessWidget {
  const _CommunityError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '게시글을 불러오지 못했습니다.',
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
