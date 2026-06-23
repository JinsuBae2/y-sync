import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../providers/admin_provider.dart';
import '../providers/comment_provider.dart';
import 'community_detail_screen.dart';

class AdminPostManagementScreen extends ConsumerStatefulWidget {
  final bool isTabMode;
  const AdminPostManagementScreen({super.key, this.isTabMode = false});

  @override
  ConsumerState<AdminPostManagementScreen> createState() => _AdminPostManagementScreenState();
}

class _AdminPostManagementScreenState extends ConsumerState<AdminPostManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(communityPostsProvider);
    final themeColor = const Color(0xFF164687);

    final content = Column(
      children: [
        if (widget.isTabMode) ...[
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: themeColor,
              labelColor: themeColor,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
              tabs: const [
                Tab(text: '전체 게시글'),
                Tab(text: '삭제된 게시글 복구'),
                Tab(text: '신고 누적 블랙리스트'),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black12),
        ],
        // 💡 검색 바 영역
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '제목, 내용, 작성자 검색...',
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: postsAsync.when(
            data: (allPosts) {
              // 검색어 필터링
              final filtered = allPosts.where((post) {
                if (_searchQuery.isEmpty) return true;
                final query = _searchQuery.toLowerCase();
                return post.title.toLowerCase().contains(query) ||
                    post.content.toLowerCase().contains(query) ||
                    post.authorName.toLowerCase().contains(query);
              }).toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  // 탭 1: 전체 게시글 목록
                  _buildAllPostsTab(filtered),
                  // 탭 2: 삭제된 게시글 복구 목록
                  _buildDeletedPostsTab(filtered.where((p) => p.isDeleted).toList()),
                  // 탭 3: 신고 누적 블랙리스트 목록
                  _buildReportBlacklistTab(),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF164687))),
            error: (err, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('데이터 로드 실패: $err', style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.isTabMode) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: content,
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '전체 게시글 관리',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: themeColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: '전체 게시글'),
            Tab(text: '삭제된 게시글 복구'),
            Tab(text: '신고 누적 블랙리스트'),
          ],
        ),
      ),
      body: content,
    );
  }

  // 💡 탭 1: 전체 게시글 탭 빌더
  Widget _buildAllPostsTab(List<CommunityPost> posts) {
    if (posts.isEmpty) {
      return const Center(
        child: Text('해당하는 게시글이 없습니다.', style: TextStyle(color: Colors.black45)),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(communityPostsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return Opacity(
            opacity: post.isDeleted ? 0.55 : 1.0,
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  children: [
                    if (post.isDeleted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          '삭제됨',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        post.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration: post.isDeleted ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.content,
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(post.category, style: const TextStyle(fontSize: 11, color: Color(0xFF164687), fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('작성자: ${post.anonymous ? "익명" : post.authorName}', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                          const SizedBox(width: 8),
                          Text(post.createdAt.split('T')[0], style: const TextStyle(fontSize: 11, color: Colors.black38)),
                        ],
                      ),
                    ],
                  ),
                ),
                trailing: post.isDeleted
                    ? IconButton(
                        icon: const Icon(Icons.settings_backup_restore_rounded, color: Color(0xFF164687)),
                        tooltip: '복구하기',
                        onPressed: () => _confirmRestore(post),
                      )
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _showDeleteDialog(post);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('삭제하기', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                onTap: () {
                  if (post.isDeleted) {
                    _showDeletedPostDetails(post);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommunityDetailScreen(post: post),
                      ),
                    );
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // 💡 탭 2: 삭제된 게시글 복구 탭 빌더
  Widget _buildDeletedPostsTab(List<CommunityPost> deletedPosts) {
    if (deletedPosts.isEmpty) {
      return const Center(
        child: Text('삭제된 게시글이 없습니다.', style: TextStyle(color: Colors.black45)),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(communityPostsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: deletedPosts.length,
        itemBuilder: (context, index) {
          final post = deletedPosts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.shade100),
            ),
            color: Colors.red.shade50.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          post.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                            decoration: TextDecoration.lineThrough,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _confirmRestore(post),
                        icon: const Icon(Icons.settings_backup_restore_rounded, size: 16, color: Colors.white),
                        label: const Text('복구', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF164687),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.content,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🚨 삭제 사유:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          post.deletionReason ?? '사유가 입력되지 않았습니다.',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('카테고리: ${post.category}', style: const TextStyle(fontSize: 11, color: Color(0xFF164687), fontWeight: FontWeight.bold)),
                      Text('작성자: ${post.anonymous ? "익명" : post.authorName}', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                      Text('작성일: ${post.createdAt.split('T')[0]}', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 💡 복구 확인 대화상자
  void _confirmRestore(CommunityPost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시글 복구', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('"${post.title}" 게시글을 다시 복구하시겠습니까?\n복구 시 모든 사용자가 다시 조회할 수 있게 됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showLoading();
              try {
                await ref.read(communityNotifierProvider).restorePostByAdmin(post.id);
                _hideLoading();
                _showSuccessToast('게시글이 복구되었습니다.');
              } catch (e) {
                _hideLoading();
                _showErrorDialog('복구 실패: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF164687)),
            child: const Text('복구하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 💡 삭제 사유 입력 대화상자
  void _showDeleteDialog(CommunityPost post) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시글 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${post.title}" 게시글을 관리자 권한으로 삭제합니다.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: '삭제 사유를 입력하세요 (필수)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                _showErrorToast('삭제 사유를 반드시 입력해주세요.');
                return;
              }
              Navigator.pop(context);
              _showLoading();
              try {
                await ref.read(communityNotifierProvider).deletePostByAdmin(post.id, reason);
                _hideLoading();
                _showSuccessToast('게시글이 성공적으로 삭제되었습니다.');
              } catch (e) {
                _hideLoading();
                _showErrorDialog('삭제 실패: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 💡 삭제된 게시물 디테일 다이얼로그 노출
  void _showDeletedPostDetails(CommunityPost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text('삭제됨', style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            const Text('삭제된 게시글 정보', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, decoration: TextDecoration.lineThrough)),
              const SizedBox(height: 8),
              Text(post.content, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🚨 삭제 사유:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 4),
                    Text(post.deletionReason ?? '사유 없음', style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmRestore(post);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF164687)),
            child: const Text('복구하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 💡 로딩/알림 유틸 함수
  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _hideLoading() {
    Navigator.pop(context);
  }

  void _showSuccessToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('에러 발생', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 💡 탭 3: 신고 누적 블랙리스트 탭 빌더
  Widget _buildReportBlacklistTab() {
    final reportsAsync = ref.watch(adminReportsProvider);

    return reportsAsync.when(
      data: (reports) {
        if (reports.isEmpty) {
          return const Center(
            child: Text('신고된 게시글 및 댓글이 없습니다.', style: TextStyle(color: Colors.black45)),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminReportsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final isPost = report.targetType == 'POST';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.shade200),
                ),
                color: report.isDeleted ? Colors.grey.shade100 : Colors.orange.shade50.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPost ? Colors.blue.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isPost ? Colors.blue.shade200 : Colors.green.shade200),
                            ),
                            child: Text(
                              isPost ? '게시글' : '댓글',
                              style: TextStyle(
                                color: isPost ? Colors.blue.shade700 : Colors.green.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                                const SizedBox(width: 4),
                                Text(
                                  '신고 ${report.reportCount}회',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (report.isDeleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '숨김 처리됨',
                                style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            ElevatedButton(
                              onPressed: () => _confirmReportDelete(report),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: Size.zero,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text(
                                '블라인드',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (isPost && report.title.isNotEmpty) ...[
                        Text(
                          report.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: report.isDeleted ? TextDecoration.lineThrough : null,
                            color: report.isDeleted ? Colors.black38 : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        report.content,
                        style: TextStyle(
                          fontSize: 13,
                          color: report.isDeleted ? Colors.black38 : Colors.black54,
                          decoration: report.isDeleted ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Colors.black12),
                      const SizedBox(height: 8),
                      // 신고 사유 리스트
                      const Text(
                        '신고 사유 목록:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      ...report.reasons.map((r) => Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.subdirectory_arrow_right_rounded, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    r,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text('작성자: ${report.authorName}', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                              if (report.authorId != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: report.isAuthorSuspended ? Colors.red.shade50 : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: report.isAuthorSuspended ? Colors.red.shade200 : Colors.green.shade200),
                                  ),
                                  child: Text(
                                    report.isAuthorSuspended ? '차단됨' : '정상',
                                    style: TextStyle(
                                      color: report.isAuthorSuspended ? Colors.red.shade700 : Colors.green.shade700,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (isPost && !report.isDeleted)
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      final fullPost = await ref.read(communityNotifierProvider).getPost(report.targetId);
                                      if (context.mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => CommunityDetailScreen(post: fullPost)),
                                        );
                                      }
                                    } catch (e) {
                                      _showErrorToast('게시글 조회 실패: $e');
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('원문 보기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              if (report.authorId != null)
                                OutlinedButton(
                                  onPressed: () => _toggleSuspend(report),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: report.isAuthorSuspended ? const Color(0xFF164687) : Colors.red,
                                    side: BorderSide(color: report.isAuthorSuspended ? const Color(0xFF164687) : Colors.red),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    report.isAuthorSuspended ? '차단 해제' : '작성자 차단',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              OutlinedButton(
                                onPressed: () => _confirmDismissReport(report),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.teal,
                                  side: const BorderSide(color: Colors.teal),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  '기각/복구',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF164687))),
      error: (err, stack) => Center(child: Text('블랙리스트 로드 실패: $err')),
    );
  }

  void _confirmReportDelete(AdminReportSummary report) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${report.targetType == 'POST' ? '게시글' : '댓글'} 블라인드 처리', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('신고 누적 대상을 강제로 숨김(블라인드) 처리합니다.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: '블라인드 사유를 입력하세요 (필수)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                _showErrorToast('사유를 입력해주세요.');
                return;
              }
              Navigator.pop(context);
              _showLoading();
              try {
                if (report.targetType == 'POST') {
                  await ref.read(communityNotifierProvider).deletePostByAdmin(report.targetId, reason);
                } else {
                  await ref.read(commentNotifierProvider).deleteCommentByAdmin(CommentSource.community, 0, report.targetId, reason);
                }
                ref.invalidate(adminReportsProvider);
                _hideLoading();
                _showSuccessToast('정상적으로 블라인드 처리되었습니다.');
              } catch (e) {
                _hideLoading();
                _showErrorDialog('블라인드 실패: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('블라인드 처리', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _toggleSuspend(AdminReportSummary report) {
    if (report.authorId == null) return;
    final isSuspending = !report.isAuthorSuspended;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isSuspending ? '작성자 차단' : '작성자 차단 해제', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(isSuspending
            ? '"${report.authorName}" 유저를 차단(정지) 상태로 변경하시겠습니까?\n차단 시 해당 유저의 모든 API 요청이 거부됩니다.'
            : '"${report.authorName}" 유저의 차단(정지) 상태를 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showLoading();
              try {
                if (isSuspending) {
                  await ref.read(adminProvider.notifier).suspendMember(report.authorId!);
                  _showSuccessToast('작성자가 차단되었습니다.');
                } else {
                  await ref.read(adminProvider.notifier).unsuspendMember(report.authorId!);
                  _showSuccessToast('작성자 차단이 해제되었습니다.');
                }
                ref.invalidate(adminReportsProvider);
                _hideLoading();
              } catch (e) {
                _hideLoading();
                _showErrorDialog('처리 실패: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: isSuspending ? Colors.red : const Color(0xFF164687)),
            child: Text(isSuspending ? '차단하기' : '해제하기', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDismissReport(AdminReportSummary report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신고 기각 / 복구', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('해당 ${report.targetType == 'POST' ? '게시글' : '댓글'}에 대한 모든 신고 내역을 삭제하고, 만약 블라인드(삭제) 상태인 경우 다시 정상 복구합니다.\n\n진행하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showLoading();
              try {
                await ref.read(adminProvider.notifier).dismissReport(report.targetType, report.targetId);
                ref.invalidate(adminReportsProvider);
                ref.invalidate(communityPostsProvider); // 게시글 목록도 갱신
                _hideLoading();
                _showSuccessToast('신고가 기각되고 정상 복구되었습니다.');
              } catch (e) {
                _hideLoading();
                _showErrorDialog('신고 기각 실패: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('기각 및 복구', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
