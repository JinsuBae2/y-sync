import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../providers/auth_provider.dart';
import 'notice_detail_screen.dart';
import 'notice_form_screen.dart';

class NoticeListScreen extends ConsumerWidget {
  const NoticeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(noticesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: noticesAsync.when(
        data: (notices) {
          if (notices.isEmpty) {
            return const Center(child: Text('등록된 공지사항이 없습니다.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(noticesProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: notices.length,
              itemBuilder: (context, index) {
                final notice = notices[index];
                return NoticeCard(notice: notice);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('에러가 발생했습니다:\n$error', textAlign: TextAlign.center),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NoticeFormScreen(),
            ),
          );
        },
        icon: const Icon(Icons.edit),
        label: const Text('글쓰기'),
      ),
    );
  }
}

class NoticeCard extends StatelessWidget {
  final Notice notice;

  const NoticeCard({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    final isOfficial = notice.noticeType == 'OFFICIAL';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoticeDetailScreen(notice: notice),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOfficial ? Colors.red.shade500 : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        notice.noticeType,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isOfficial ? Colors.white : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 24),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  notice.title,
                  style: const TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                    letterSpacing: -0.5,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  notice.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15, 
                    color: Colors.black54,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                      child: Icon(Icons.person_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      notice.authorName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(notice.createdAt),
                      style: const TextStyle(fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
