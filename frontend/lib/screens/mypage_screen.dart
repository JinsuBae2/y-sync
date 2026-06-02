import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/mypage_provider.dart';
import '../providers/auth_provider.dart';
import '../models/community_post.dart';
import '../models/my_comment.dart';
import '../models/notice.dart';
import '../providers/admin_provider.dart';
import 'notice_form_screen.dart';
import 'scrap_list_screen.dart'; // 💡 추가
import 'auth_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'login_screen.dart';
import 'my_posts_screen.dart';
import 'my_comments_screen.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPageAsync = ref.watch(myPageProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '마이페이지',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                      // 💡 역할 배지 (역할에 따라 색상 다르게 표시)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(member.role),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getRoleDisplayName(member.role),
                          style: TextStyle(
                            color: member.role == 'USER'
                                ? Colors.white
                                : const Color(0xFF0A192F),
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
                      _buildStatItem(
                        '작성글',
                        (posts.length + (notices?.length ?? 0)).toString(),
                      ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A192F),
              ),
            ),
            const SizedBox(height: 16),

            // 💡 내가 스크랩한 글 (새 화면 진입용 타일)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: const Icon(Icons.bookmarks_rounded, color: Color(0xFF164687)),
                title: const Text('내가 스크랩한 글', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                trailing: const Icon(Icons.chevron_right),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScrapListScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // 💡 내가 쓴 공지사항 (관리자 전용)
            if (member.role == 'ADMIN' && notices != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: const Icon(Icons.campaign_rounded, color: Color(0xFF0A192F)),
                  title: const Text('내가 작성한 공지사항', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          notices.length.toString(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyPostsScreen(
                          posts: const [],
                          notices: notices,
                          isNoticeOnly: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 내가 쓴 게시글
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: const Icon(Icons.article_outlined, color: Color(0xFF0A192F)),
                title: const Text('내가 쓴 게시글', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        posts.length.toString(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MyPostsScreen(posts: posts)),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // 내가 남긴 댓글
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: const Icon(Icons.comment_outlined, color: Color(0xFF0A192F)),
                title: const Text('내가 남긴 댓글', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        comments.length.toString(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MyCommentsScreen(comments: comments)),
                  );
                },
              ),
            ),



            // 💡 일반 유저 전용 메뉴 (관리자 신청)
            if (member.role == 'USER') ...[
              const Text(
                '기타',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A192F),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.indigo,
                ),
                title: const Text(
                  '관리자 권한 신청',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('학부 조교 또는 운영진 권한을 신청합니다.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAdminRequestDialog(context, ref),
              ),
              const SizedBox(height: 32),
            ],

            // 💡 설정 및 기타
            const Text(
              '설정',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A192F),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.security_rounded,
                color: Colors.blueGrey,
              ),
              title: const Text(
                '보안 및 간편 로그인',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthSettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.notifications_active_rounded,
                color: Colors.orangeAccent,
              ),
              title: const Text(
                '알림 설정',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                '로그아웃',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: Colors.red.shade50,
              onTap: () {
                _showLogoutDialog(context, ref);
              },
            ),

            const SizedBox(height: 48),
            const Center(
              child: Text(
                'Version 1.0.0 (Stable)',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
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
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
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

  Widget _buildActivityTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: const Color(0xFF0A192F)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        children: children.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '내역이 없습니다.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ]
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
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 40),
            Container(height: 24, width: 100, color: Colors.white),
            const SizedBox(height: 16),
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 💡 역할별 색상 정의
  Color _getRoleColor(String role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return const Color(0xFFFFC107); // Amber
      case 'ADMIN':
        return Colors.blue.shade600;
      case 'USER':
        return Colors.grey.shade400;
      default:
        return Colors.grey;
    }
  }

  // 💡 역할별 표시 이름 정의
  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return '슈퍼 관리자';
      case 'ADMIN':
        return '관리자';
      case 'USER':
        return '학생';
      default:
        return '알 수 없음';
    }
  }

  // 💡 관리자 신청 다이얼로그
  void _showAdminRequestDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '관리자 권한 신청',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('학부 조교 또는 운영진 활동을 위해 권한이 필요한 사유를 입력해주세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '신청 사유를 입력하세요 (예: 캡스톤 디자인 조교 활동 등)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              try {
                await ref
                    .read(adminProvider.notifier)
                    .submitRequest(reasonController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('관리자 신청이 완료되었습니다.')),
                  );
                }
              } catch (e) {
                if (context.mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('신청 실패: $e')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A192F),
              foregroundColor: Colors.white,
            ),
            child: const Text('신청하기'),
          ),
        ],
      ),
    );
  }

  // 💡 관리자 승인 대기 리스트 다이얼로그 (SUPER_ADMIN용)
  void _showAdminManagementList(BuildContext context, WidgetRef ref) {
    ref.read(adminProvider.notifier).fetchPendingRequests();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) {
            final adminRequests = ref.watch(adminProvider);

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '관리자 승인 대기 목록',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: adminRequests.when(
                      data: (requests) => requests.isEmpty
                          ? const Center(child: Text('대기 중인 신청이 없습니다.'))
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: requests.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final req = requests[index];
                                return ListTile(
                                  title: Text(
                                    '${req.requesterName} (${req.loginId})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '사유: ${req.reason}\n신청일: ${req.requestedAt.split('T')[0]}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.green,
                                        ),
                                        onPressed: () => ref
                                            .read(adminProvider.notifier)
                                            .approveRequest(req.id),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.cancel_rounded,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => ref
                                            .read(adminProvider.notifier)
                                            .rejectRequest(req.id),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, __) => Center(child: Text('에러: $e')),
                    ),
                  ),
                ],
              ),
            );
          },
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
