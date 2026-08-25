import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_post.dart';
import '../models/my_comment.dart';
import '../models/notice.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/mypage_provider.dart';
import '../theme/app_design_tokens.dart';
import 'admin_dashboard_screen.dart';
import 'auth_settings_screen.dart';
import 'login_screen.dart';
import 'my_comments_screen.dart';
import 'my_posts_screen.dart';
import 'notification_settings_screen.dart';
import 'scrap_list_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPageAsync = ref.watch(myPageProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDesignTokens.contentMaxWidth,
            ),
            child: myPageAsync.when(
              data: (data) => _ProfileContent(data: data),
              loading: () => const _ProfileLoading(),
              error: (error, _) =>
                  _ProfileError(onRetry: () => ref.invalidate(myPageProvider)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.data});

  final dynamic data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = data.member;
    final posts = data.posts as List<CommunityPost>;
    final comments = data.comments as List<MyComment>;
    final notices = data.notices as List<Notice>?;
    final isManager = member.role == 'ADMIN' || member.role == 'SUPER_ADMIN';

    return RefreshIndicator(
      color: AppDesignTokens.blue,
      onRefresh: () => ref.read(myPageProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
        children: [
          const Text(
            '내정보',
            style: TextStyle(
              color: AppDesignTokens.navy,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            '내 활동과 계정 설정을 관리하세요',
            style: TextStyle(
              color: AppDesignTokens.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          _IdentityPanel(
            name: member.name,
            loginId: member.loginId,
            role: member.role,
            postCount: posts.length + (notices?.length ?? 0),
            commentCount: comments.length,
          ),
          if (isManager) ...[
            const SizedBox(height: 28),
            const _GroupTitle(title: '관리'),
            const SizedBox(height: 10),
            _MenuGroup(
              children: [
                _ProfileMenuItem(
                  icon: Icons.admin_panel_settings_outlined,
                  title: '학과 관리자 페이지',
                  subtitle: '회원, 공지, 게시글을 관리합니다',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          const _GroupTitle(title: '내 활동'),
          const SizedBox(height: 10),
          _MenuGroup(
            children: [
              _ProfileMenuItem(
                icon: Icons.bookmark_border_rounded,
                title: '스크랩한 글',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScrapListScreen()),
                ),
              ),
              if (member.role == 'ADMIN' && notices != null)
                _ProfileMenuItem(
                  icon: Icons.campaign_outlined,
                  title: '작성한 공지사항',
                  count: notices.length,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyPostsScreen(
                        posts: const [],
                        notices: notices,
                        isNoticeOnly: true,
                      ),
                    ),
                  ),
                ),
              _ProfileMenuItem(
                icon: Icons.article_outlined,
                title: '내가 쓴 게시글',
                count: posts.length,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyPostsScreen(posts: posts),
                  ),
                ),
              ),
              _ProfileMenuItem(
                icon: Icons.chat_bubble_outline_rounded,
                title: '내가 남긴 댓글',
                count: comments.length,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyCommentsScreen(comments: comments),
                  ),
                ),
              ),
            ],
          ),
          if (member.role == 'USER') ...[
            const SizedBox(height: 28),
            const _GroupTitle(title: '권한'),
            const SizedBox(height: 10),
            _MenuGroup(
              children: [
                _ProfileMenuItem(
                  icon: Icons.verified_user_outlined,
                  title: '관리자 권한 신청',
                  subtitle: '학부 조교 또는 운영진 권한을 신청합니다',
                  onTap: () => _showAdminRequestDialog(context, ref),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          const _GroupTitle(title: '설정'),
          const SizedBox(height: 10),
          _MenuGroup(
            children: [
              _ProfileMenuItem(
                icon: Icons.lock_outline_rounded,
                title: '보안 및 간편 로그인',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthSettingsScreen()),
                ),
              ),
              _ProfileMenuItem(
                icon: Icons.notifications_none_rounded,
                title: '알림 설정',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                ),
              ),
              _ProfileMenuItem(
                icon: Icons.logout_rounded,
                title: '로그아웃',
                isDestructive: true,
                onTap: () => _showLogoutDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            'Y-Sync 1.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppDesignTokens.subtle,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminRequestDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('관리자 권한 신청'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('권한이 필요한 사유를 입력해주세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '예: 학과 운영진 활동',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              try {
                await ref.read(adminProvider.notifier).submitRequest(reason);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('관리자 신청이 완료되었습니다.')),
                );
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('신청 실패: $error')));
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignTokens.navy,
            ),
            child: const Text('신청'),
          ),
        ],
      ),
    ).whenComplete(reasonController.dispose);
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('현재 기기에서 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(color: AppDesignTokens.coral),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel({
    required this.name,
    required this.loginId,
    required this.role,
    required this.postCount,
    required this.commentCount,
  });

  final String name;
  final String loginId;
  final String role;
  final int postCount;
  final int commentCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignTokens.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.navy,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    name.isEmpty ? 'Y' : name.characters.first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppDesignTokens.navy,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _RoleLabel(role: role),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        loginId,
                        style: const TextStyle(
                          color: AppDesignTokens.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppDesignTokens.paleBlue,
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: _ProfileStat(label: '작성한 글', value: postCount),
                ),
                const SizedBox(
                  height: 28,
                  child: VerticalDivider(
                    width: 1,
                    color: AppDesignTokens.divider,
                  ),
                ),
                Expanded(
                  child: _ProfileStat(label: '남긴 댓글', value: commentCount),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleLabel extends StatelessWidget {
  const _RoleLabel({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      'SUPER_ADMIN' => '슈퍼 관리자',
      'ADMIN' => '관리자',
      _ => '학생',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: AppDesignTokens.divider),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppDesignTokens.blue,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: AppDesignTokens.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppDesignTokens.muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppDesignTokens.navy,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignTokens.divider),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(
                height: 1,
                indent: 58,
                color: AppDesignTokens.divider,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.count,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int? count;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppDesignTokens.coral : AppDesignTokens.navy;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppDesignTokens.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (count != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: AppDesignTokens.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (!isDestructive)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppDesignTokens.subtle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppDesignTokens.blue),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '내정보를 불러오지 못했습니다.',
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
