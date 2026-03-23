import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../providers/auth_provider.dart';
import 'community_detail_screen.dart';
import 'community_form_screen.dart';

class CommunityListScreen extends ConsumerWidget {
  final bool isAdminMode; // 💡 관리자 모드 플래그 추가

  const CommunityListScreen({super.key, this.isAdminMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(communityPostsProvider);
    final selectedCategory = ref.watch(communityCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 💡 카테고리 필터링 칩 (Category Filter Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildCategoryChip(ref, '전체', 'ALL', selectedCategory),
                _buildCategoryChip(ref, 'Q&A', 'QA', selectedCategory),
                _buildCategoryChip(ref, '팀원모집', 'TEAM', selectedCategory),
                _buildCategoryChip(ref, '자유', 'FREE', selectedCategory),
              ],
            ),
          ),
          // 💡 커뮤니티 게시글 리스트
          Expanded(
            child: postsAsync.when(
              data: (allPosts) {
                // 💡 관리자 모드가 아닐 때만 삭제된 게시글 숨김 처리
                final posts = isAdminMode ? allPosts : allPosts.where((p) => !p.isDeleted).toList();

                if (posts.isEmpty) {
                  return const Center(child: Text('게시글이 없습니다. 첫 글을 작성해보세요!'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(communityPostsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      return CommunityPostCard(post: posts[index]);
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

  Widget _buildCategoryChip(WidgetRef ref, String label, String value, String selectedValue) {
    final isSelected = value == selectedValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          ref.read(communityCategoryProvider.notifier).updateCategory(value);
        },
        selectedColor: Colors.amber.shade100,
        checkmarkColor: Colors.amber.shade900,
        labelStyle: TextStyle(
          color: isSelected ? Colors.amber.shade900 : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class CommunityPostCard extends StatelessWidget {
  final CommunityPost post;

  const CommunityPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityDetailScreen(post: post),
            ),
          );
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
              Text(
                post.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    backgroundColor: post.anonymous ? Colors.grey.shade200 : Colors.amber.shade100,
                    child: Icon(
                      post.anonymous ? Icons.person_off_rounded : Icons.person_rounded,
                      size: 14,
                      color: post.anonymous ? Colors.grey : Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post.authorName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
