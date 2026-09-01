import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/community_provider.dart';
import '../providers/notice_provider.dart';
import '../screens/community_detail_screen.dart';
import '../screens/notice_detail_screen.dart';
import '../theme/app_design_tokens.dart';

Future<bool?> openContentDetail(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required int targetId,
}) async {
  final loadingDialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ContentLoadingDialog(),
  );

  try {
    final Widget detailScreen;
    if (targetType == 'NOTICE') {
      final notice = await ref.read(noticeNotifierProvider).getNotice(targetId);
      detailScreen = NoticeDetailScreen(notice: notice);
    } else {
      final post = await ref.read(communityNotifierProvider).getPost(targetId);
      detailScreen = CommunityDetailScreen(post: post);
    }
    if (!context.mounted) return null;

    Navigator.of(context, rootNavigator: true).pop();
    await loadingDialog;
    if (!context.mounted) return null;

    return Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => detailScreen),
    );
  } catch (_) {
    if (!context.mounted) return null;
    Navigator.of(context, rootNavigator: true).pop();
    await loadingDialog;
    if (!context.mounted) return null;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('게시글을 불러올 수 없습니다.')));
    return null;
  }
}

class _ContentLoadingDialog extends StatelessWidget {
  const _ContentLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: Center(
        child: Card(
          color: Colors.white,
          elevation: 8,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
        ),
      ),
    );
  }
}
