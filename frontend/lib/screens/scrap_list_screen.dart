import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scrap.dart';
import '../providers/community_provider.dart';
import '../providers/notice_provider.dart';
import '../providers/scrap_provider.dart';
import '../theme/app_design_tokens.dart';
import 'community_detail_screen.dart';
import 'notice_detail_screen.dart';

class ScrapListScreen extends ConsumerWidget {
  const ScrapListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrapsAsync = ref.watch(scrapsProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          '스크랩한 글',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDesignTokens.contentMaxWidth,
          ),
          child: scrapsAsync.when(
            data: (scraps) => scraps.isEmpty
                ? const _EmptyState()
                : RefreshIndicator(
                    color: AppDesignTokens.blue,
                    onRefresh: () async => ref.invalidate(scrapsProvider),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                      itemCount: scraps.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        color: AppDesignTokens.divider,
                      ),
                      itemBuilder: (context, index) => _ScrapRow(
                        scrap: scraps[index],
                        onOpen: () => _openScrap(context, ref, scraps[index]),
                        onRemove: () => ref
                            .read(scrapNotifierProvider)
                            .toggleScrap(
                              scraps[index].targetType,
                              scraps[index].targetId,
                            ),
                      ),
                    ),
                  ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppDesignTokens.blue),
            ),
            error: (_, _) =>
                _ErrorState(onRetry: () => ref.invalidate(scrapsProvider)),
          ),
        ),
      ),
    );
  }

  Future<void> _openScrap(
    BuildContext context,
    WidgetRef ref,
    Scrap scrap,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('글을 불러오는 중입니다.'),
        duration: Duration(milliseconds: 500),
      ),
    );

    try {
      bool? changed;
      if (scrap.targetType == 'NOTICE') {
        final notice = await ref
            .read(noticeNotifierProvider)
            .getNotice(scrap.targetId);
        if (!context.mounted) return;
        changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: notice)),
        );
      } else {
        final post = await ref
            .read(communityNotifierProvider)
            .getPost(scrap.targetId);
        if (!context.mounted) return;
        changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => CommunityDetailScreen(post: post)),
        );
      }
      if (changed == true) {
        ref.invalidate(scrapsProvider);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('글을 불러올 수 없습니다.')));
    }
  }
}

class _ScrapRow extends StatelessWidget {
  const _ScrapRow({
    required this.scrap,
    required this.onOpen,
    required this.onRemove,
  });

  final Scrap scrap;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isNotice = scrap.targetType == 'NOTICE';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isNotice
                      ? AppDesignTokens.paleBlue
                      : AppDesignTokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppDesignTokens.divider),
                ),
                child: Icon(
                  isNotice ? Icons.campaign_outlined : Icons.forum_outlined,
                  color: isNotice ? AppDesignTokens.blue : AppDesignTokens.navy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isNotice ? '공지' : _categoryLabel(scrap.category),
                          style: const TextStyle(
                            color: AppDesignTokens.blue,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            scrap.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppDesignTokens.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      scrap.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppDesignTokens.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${_formatDate(scrap.postCreatedAt)}  ·  댓글 ${scrap.commentCount}',
                      style: const TextStyle(
                        color: AppDesignTokens.subtle,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '스크랩 해제',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(
                  Icons.bookmark_rounded,
                  color: AppDesignTokens.blue,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 42,
            color: AppDesignTokens.subtle,
          ),
          SizedBox(height: 16),
          Text(
            '스크랩한 글이 없습니다',
            style: TextStyle(
              color: AppDesignTokens.navy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '나중에 다시 볼 공지나 게시글을 저장해보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppDesignTokens.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '스크랩을 불러오지 못했습니다.',
          style: TextStyle(color: AppDesignTokens.muted),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('다시 시도'),
        ),
      ],
    ),
  );
}

String _formatDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

String _categoryLabel(String? category) => switch (category) {
  'QA' => 'Q&A',
  'TEAM' => '팀원 모집',
  _ => '자유',
};
