import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../providers/scrap_provider.dart';
import 'community_detail_screen.dart';
import 'community_form_screen.dart';
import '../utils/image_url_helper.dart';
import '../widgets/notification_action_button.dart'; // 💡 추가

class CommunityListScreen extends ConsumerStatefulWidget {
  final bool isAdminMode; // 💡 관리자 모드 플래그 추가

  const CommunityListScreen({super.key, this.isAdminMode = false});

  @override
  ConsumerState<CommunityListScreen> createState() => _CommunityListScreenState();
}

class _CommunityListScreenState extends ConsumerState<CommunityListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 💡 검색 실행 함수: 엔터키를 누르거나 돋보기 아이콘을 눌렀을 때 호출됩니다.
  void _performSearch() {
    ref.read(communitySearchKeywordProvider.notifier).updateKeyword(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(communityPostsProvider);
    final selectedCategory = ref.watch(communityCategoryProvider);
    final selectedGrade = ref.watch(communityGradeProvider); // 💡 추가된 학년 상태

    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: const [
          NotificationActionButton(), // 💡 추가
        ],
      ),
      body: Column(
        children: [
          // 💡 커뮤니티 검색 바 (Search Bar) UI
          Container(
            color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.1),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _performSearch(), // 엔터키 입력 시 검색
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '커뮤니티 제목이나 내용 검색...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Color(0xFF164687), width: 2),
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (value.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch();
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.search_rounded, color: Color(0xFF164687)),
                          onPressed: _performSearch,
                        ),
                      ],
                    );
                  },
                ),
                prefixIcon: const Icon(Icons.article_outlined, color: Colors.grey),
              ),
            ),
          ),
          // 💡 상단 (Grade Filter): 학년 필터링 칩
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildGradeChip(ref, '전체', 'ALL', selectedGrade),
                _buildGradeChip(ref, '1학년', 'GRADE_1', selectedGrade),
                _buildGradeChip(ref, '2학년', 'GRADE_2', selectedGrade),
                _buildGradeChip(ref, '3학년', 'GRADE_3', selectedGrade),
              ],
            ),
          ),
          // 💡 하단 (Category Filter): 카테고리 필터링 칩
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Row(
              children: [
                _buildCategoryChip(context, ref, '전체', 'ALL', selectedCategory),
                _buildCategoryChip(context, ref, 'Q&A', 'QA', selectedCategory),
                _buildCategoryChip(context, ref, '팀원모집', 'TEAM', selectedCategory),
                _buildCategoryChip(context, ref, '자유', 'FREE', selectedCategory),
              ],
            ),
          ),
          // 💡 커뮤니티 게시글 리스트
          Expanded(
            child: postsAsync.when(
              data: (allPosts) {
                // 💡 관리자 모드가 아닐 때만 삭제된 게시글 숨김 처리
                final posts = widget.isAdminMode ? allPosts : allPosts.where((p) => !p.isDeleted).toList();

                // 💡 학년 필터링 추가 (전체이거나, 타겟 학년이 ALL이거나 일치하는 경우)
                final filteredPosts = selectedGrade == 'ALL' 
                    ? posts 
                    : posts.where((p) => p.targetGrade == 'ALL' || p.targetGrade == selectedGrade).toList();

                if (filteredPosts.isEmpty) {
                  // 검색 결과 없음 (Empty State) UI
                  final keyword = ref.read(communitySearchKeywordProvider);
                  final isSearch = keyword.isNotEmpty;
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      padding: const EdgeInsets.only(top: 80),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isSearch ? Icons.search_off_rounded : Icons.inbox_rounded, 
                               size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 24),
                          Text(
                            isSearch ? "'$keyword' 검색 결과가 없습니다." : '게시글이 없습니다. 첫 글을 작성해보세요!',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isSearch ? '다른 키워드로 다시 검색해보세요.' : '새로운 게시글을 작성해보세요.',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(communityPostsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredPosts.length,
                    itemBuilder: (context, index) {
                      return CommunityPostCard(post: filteredPosts[index]);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('에러: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CommunityFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('글쓰기'),
      ),
    );
  }

  Widget _buildGradeChip(WidgetRef ref, String label, String value, String selectedValue) {
    final isSelected = value == selectedValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          ref.read(communityGradeProvider.notifier).updateGrade(selected ? value : 'ALL');
        },
        selectedColor: const Color(0xFF164687).withOpacity(0.15),
        checkmarkColor: const Color(0xFF164687),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF164687) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, WidgetRef ref, String label, String value, String selectedValue) {
    final isSelected = value == selectedValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          ref.read(communityCategoryProvider.notifier).updateCategory(selected ? value : 'ALL');
        },
        selectedColor: const Color(0xFF164687).withOpacity(0.15),
        checkmarkColor: const Color(0xFF164687),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF164687) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class CommunityPostCard extends ConsumerWidget {
  final CommunityPost post;

  const CommunityPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrapsAsync = ref.watch(scrapsProvider);
    final isScrapped = scrapsAsync.maybeWhen(
      data: (scraps) => scraps.any((s) => s.targetType == 'COMMUNITY' && s.targetId == post.id),
      orElse: () => false,
    );

    final isPinned = post.isPinned;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isPinned ? const Color(0xFF164687).withOpacity(0.04) : Colors.white, // 💡 상단 고정 글은 브랜드 컬러 연하게
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPinned 
              ? const Color(0xFF164687).withOpacity(0.12) 
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CommunityDetailScreen(post: post),
              ),
            );
            // 💡 상세 화면에서 돌아올 때 조회수 증가를 반영하기 위해 리스트 새로고침
            ref.invalidate(communityPostsProvider);
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 💡 상단 영역: 작성자 아바타 및 정보 + 북마크
                Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: post.anonymous ? Colors.grey.shade200 : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                      child: Icon(
                        post.anonymous ? Icons.person_off_rounded : Icons.person_rounded,
                        size: 16,
                        color: post.anonymous ? Colors.grey : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          post.createdAt.split('T')[0],
                          style: const TextStyle(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // 💡 북마크 아이콘 (토글)
                    InkWell(
                      onTap: () {
                        ref.read(scrapNotifierProvider).toggleScrap('COMMUNITY', post.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isScrapped ? Icons.bookmark : Icons.bookmark_border,
                          size: 22,
                          color: const Color(0xFF164687),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 💡 중간 영역: 제목 및 본문 내용 + 우측 이미지 썸네일
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isPinned) // 💡 핀 고정 벡터 아이콘
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.push_pin_rounded,
                                    size: 16,
                                    color: Color(0xFF164687),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  post.title,
                                  style: const TextStyle(
                                    fontSize: 17, 
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            post.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14, 
                              color: Colors.grey.shade700, 
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (post.imageUrls != null && post.imageUrls!.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12), // 💡 둥근 모서리 곡률 조정
                        child: Image.network(
                          getCleanImageUrl(post.imageUrls!.first),
                          width: 80, // 💡 크기 80x80으로 조절
                          height: 80,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF164687)),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.broken_image_rounded, size: 24, color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                // 💡 하단 영역: 카테고리 태그 뱃지 + 댓글 수
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        post.category == 'QA' ? 'Q&A' : (post.category == 'TEAM' ? '팀원모집' : '자유'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          '${post.commentCount}', 
                          style: TextStyle(
                            fontSize: 12, 
                            color: Colors.grey.shade600, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
