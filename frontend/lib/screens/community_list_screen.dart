import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import 'community_detail_screen.dart';
import 'community_form_screen.dart';

class CommunityListScreen extends ConsumerWidget {
  final bool isAdminMode; // 💡 관리자 모드 플래그 추가

  const CommunityListScreen({super.key, this.isAdminMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(communityPostsProvider);
    final selectedCategory = ref.watch(communityCategoryProvider);
    final selectedGrade = ref.watch(communityGradeProvider); // 💡 추가된 학년 상태

    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
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
                final posts = isAdminMode ? allPosts : allPosts.where((p) => !p.isDeleted).toList();

                // 💡 학년 필터링 추가 (전체이거나, 타겟 학년이 ALL이거나 일치하는 경우)
                final filteredPosts = selectedGrade == 'ALL' 
                    ? posts 
                    : posts.where((p) => p.targetGrade == 'ALL' || p.targetGrade == selectedGrade).toList();

                if (filteredPosts.isEmpty) {
                  return const Center(child: Text('게시글이 없습니다. 첫 글을 작성해보세요!'));
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: post.isPinned ? const Color(0xFF164687).withOpacity(0.05) : Colors.white, // 💡 상단 고정 글은 브랜드 컬러 연하게
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
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    post.createdAt.split('T')[0], // 간단한 날짜 표시
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (post.isPinned) // 💡 핀 고정 아이콘
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Text('📌', style: TextStyle(fontSize: 18)),
                    ),
                  Expanded(
                    child: Text(
                      post.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                style: TextStyle(color: Colors.grey.shade700, height: 1.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: post.anonymous ? Colors.grey.shade200 : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                    child: Icon(
                      post.anonymous ? Icons.person_off_rounded : Icons.person_rounded,
                      size: 14,
                      color: post.anonymous ? Colors.grey : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post.authorName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  // 💡 댓글수 표시 (조회수 제거)
                  Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('${post.commentCount}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
