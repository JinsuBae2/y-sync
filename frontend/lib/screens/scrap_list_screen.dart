import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scrap.dart';
import '../providers/scrap_provider.dart';
import '../providers/community_provider.dart';
import '../providers/notice_provider.dart';
import 'community_detail_screen.dart';
import 'notice_detail_screen.dart';

class ScrapListScreen extends ConsumerWidget {
  const ScrapListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrapsAsync = ref.watch(scrapsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내가 스크랩한 글', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: scrapsAsync.when(
        data: (scraps) {
          if (scraps.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('스크랩한 게시글이 없습니다.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(scrapsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scraps.length,
              itemBuilder: (context, index) {
                final scrap = scraps[index];
                return _buildScrapCard(context, ref, scrap);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('불러오는 중 오류가 발생했습니다: $err')),
      ),
    );
  }

  Widget _buildScrapCard(BuildContext context, WidgetRef ref, Scrap scrap) {
    final d = scrap.postCreatedAt;
    final dateStr = '${d.year.toString().substring(2)}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () async {
          try {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('게시글을 불러오는 중...'), duration: Duration(milliseconds: 500)),
              );
            }
            if (scrap.targetType == 'NOTICE') {
              final notice = await ref.read(noticeNotifierProvider).getNotice(scrap.targetId);
              if (context.mounted) {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (context) => NoticeDetailScreen(notice: notice),
                ));
              }
            } else {
              final post = await ref.read(communityNotifierProvider).getPost(scrap.targetId);
              if (context.mounted) {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (context) => CommunityDetailScreen(post: post),
                ));
              }
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('게시글을 불러올 수 없습니다: $e')),
              );
            }
          }
          // 상세 화면에서 스크랩이 취소될 수 있으므로 돌아오면 리프레시
          ref.invalidate(scrapsProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 카테고리/작성자 및 우측 북마크 토글 버튼
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF164687).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      scrap.category ?? '공지사항',
                      style: const TextStyle(color: Color(0xFF164687), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(scrap.authorName, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const Spacer(),
                  // 💡 스크랩 취소 아이콘 (Optimistic UI: 누르면 즉시 빈 아이콘으로 보이거나 삭제됨. 전체 스크린이므로 누르면 목록 무효화)
                  IconButton(
                    icon: const Icon(Icons.bookmark, color: Color(0xFF164687)),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      ref.read(scrapNotifierProvider).toggleScrap(scrap.targetType, scrap.targetId);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 제목
              Text(scrap.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // 하단: 댓글수 및 작성일
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('${scrap.commentCount}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const Spacer(),
                  Text(dateStr, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
