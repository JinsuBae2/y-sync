import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/community_provider.dart';
import '../providers/notice_provider.dart';
import '../screens/community_detail_screen.dart';
import '../screens/notice_detail_screen.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/load_failure_view.dart';
import 'adaptive_page_route.dart';

enum ContentDetailResult { viewed, changed }

Future<ContentDetailResult?> openContentDetail(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required int targetId,
}) async {
  var viewed = false;
  final changed = await Navigator.push<bool>(
    context,
    adaptivePageRoute(
      builder: (_) => _ContentDetailPage(
        targetType: targetType,
        targetId: targetId,
        onLoaded: () => viewed = true,
      ),
    ),
  );
  if (changed == true) return ContentDetailResult.changed;
  return viewed ? ContentDetailResult.viewed : null;
}

class _ContentDetailPage extends ConsumerStatefulWidget {
  const _ContentDetailPage({
    required this.targetType,
    required this.targetId,
    required this.onLoaded,
  });

  final String targetType;
  final int targetId;
  final VoidCallback onLoaded;

  @override
  ConsumerState<_ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends ConsumerState<_ContentDetailPage> {
  late Future<Widget> _detail;

  @override
  void initState() {
    super.initState();
    _detail = _load();
  }

  Future<Widget> _load() async {
    if (widget.targetType == 'NOTICE') {
      final notice = await ref
          .read(noticeNotifierProvider)
          .getNotice(widget.targetId);
      return NoticeDetailScreen(notice: notice);
    }
    final post = await ref
        .read(communityNotifierProvider)
        .getPost(widget.targetId);
    return CommunityDetailScreen(post: post);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _detail,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData) {
        widget.onLoaded();
        return snapshot.requireData;
      }
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(widget.targetType == 'NOTICE' ? '공지사항' : '커뮤니티'),
        ),
        body: snapshot.hasError
            ? LoadFailureView(
                message: '게시글을 불러올 수 없습니다.',
                onRetry: () => setState(() {
                  _detail = _load();
                }),
              )
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppDesignTokens.blue),
                    SizedBox(height: 16),
                    Text(
                      '게시글을 불러오는 중입니다',
                      style: TextStyle(
                        color: AppDesignTokens.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
      );
    },
  );
}
