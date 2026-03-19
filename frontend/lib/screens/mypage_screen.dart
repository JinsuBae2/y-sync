import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/mypage_provider.dart';
import '../providers/auth_provider.dart';
import '../models/community_post.dart';
import '../models/my_comment.dart';
import '../models/notice.dart';
import 'community_detail_screen.dart';
import 'notice_detail_screen.dart'; // 💡 추가

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPageAsync = ref.watch(myPageProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('마이페이지', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: myPageAsync.when(
        data: (data) => _buildContent(context, ref, data),
        loading: () => _buildLoading(context),
        error: (error, stack) => Center(child: Text('에러 발생: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, dynamic data) {
    final member = data.member;
    final posts = data.posts as List<CommunityPost>;
    final comments = data.comments as List<MyComment>;
    final notices = data.notices as List<Notice>?;

    return RefreshIndicator(
      onRefresh: () => ref.read(myPageProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💡 프로필 섹션 (Deep Navy Card)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0A192F), // 💡 Deep Navy (#0A192F)
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A192F).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            member.loginId, // 💡 학번
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // 💡 역할 배지 (Amber Color)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107), // 💡 Amber (#FFC107)
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          member.role == 'ADMIN' ? '관리자' : '학생',
                          style: const TextStyle(
                            color: Color(0xFF0A192F),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildStatItem('작성글', (posts.length + (notices?.length ?? 0)).toString()),
                      _buildDivider(),
                      _buildStatItem('댓글', comments.length.toString()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 💡 활동 내역 섹션
            const Text(
              '활동 내역',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A192F)),
            ),
            const SizedBox(height: 16),
            
            // 💡 내가 쓴 공지사항 (관리자 전용)
            if (member.role == 'ADMIN' && notices != null) ...[
              _buildActivityTile(
                context,
                icon: Icons.campaign_rounded,
                title: '내가 작성한 공지사항',
                count: notices.length,
                children: notices.map((notice) => ListTile(
                  title: Text(notice.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  subtitle: Text(notice.createdAt.toString().split('T')[0], style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => NoticeDetailScreen(notice: notice)),
                    );
                  },
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // 내가 쓴 게시글
            _buildActivityTile(
              context,
              icon: Icons.article_outlined,
              title: '내가 쓴 게시글',
              count: posts.length,
              children: posts.map((post) => ListTile(
                title: Text(post.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text(post.createdAt.toString().split('T')[0], style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CommunityDetailScreen(post: post)),
                  );
                },
              )).toList(),
            ),
            const SizedBox(height: 12),
            
            // 내가 남긴 댓글
            _buildActivityTile(
              context,
              icon: Icons.comment_outlined,
              title: '내가 남긴 댓글',
              count: comments.length,
              children: comments.map((comment) => ListTile(
                title: Text(comment.content, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('원문: ${comment.postTitle}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  // TODO: 댓글 클릭 시 해당 게시글 상세로 이동 (postId와 category 활용)
                },
              )).toList(),
            ),

            const SizedBox(height: 32),

            // 💡 설정 및 기타
            const Text(
              '설정',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A192F)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('로그아웃', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: Colors.red.shade50,
              onTap: () {
                _showLogoutDialog(context, ref);
              },
            ),

            const SizedBox(height: 48),
            const Center(
              child: Text(
                'Version 1.0.0 (Stable)',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 40),
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildActivityTile(BuildContext context, {required IconData icon, required String title, required int count, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: const Color(0xFF0A192F)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(count.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        children: children.isEmpty 
            ? [const Padding(padding: EdgeInsets.all(20), child: Text('내역이 없습니다.', style: TextStyle(color: Colors.grey)))]
            : children,
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
            const SizedBox(height: 40),
            Container(height: 24, width: 100, color: Colors.white),
            const SizedBox(height: 16),
            Container(height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
            const SizedBox(height: 12),
            Container(height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            }, 
            child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
