import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../providers/auth_provider.dart';
import 'notice_detail_screen.dart';
import 'notice_form_screen.dart';

class NoticeListScreen extends ConsumerStatefulWidget {
  const NoticeListScreen({super.key});

  @override
  ConsumerState<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends ConsumerState<NoticeListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 💡 검색 실행 함수: 엔터키를 누르거나 돋보기 아이콘을 눌렀을 때 호출됩니다.
  void _performSearch() {
    ref.read(searchKeywordProvider.notifier).updateKeyword(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    // noticesAsync는 searchKeywordProvider의 상태 변경을 감지하여 자동으로 다시 fetch 합니다.
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
      body: Column(
        children: [
          // 💡 공지사항 검색 바 (Search Bar) UI
          Container(
            color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.3),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _performSearch(), // 엔터키 입력 시 검색
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '공지 제목이나 내용 검색...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary),
                  onPressed: _performSearch, // 아이콘 클릭 시 검색
                ),
                /* 검색어 초기화 버튼 (Optional: 텍스트가 있을 때만 보이게 구현 가능) */
                prefixIcon: const Icon(Icons.article_outlined, color: Colors.grey),
              ),
            ),
          ),
          // 💡 공지사항 리스트 영역
          Expanded(
            child: noticesAsync.when(
              data: (notices) {
                if (notices.isEmpty) {
                  // 검색 결과 없음 (Empty State) UI
                  final keyword = ref.read(searchKeywordProvider);
                  final isSearch = keyword.isNotEmpty;
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      padding: const EdgeInsets.only(top: 80),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isSearch ? Icons.search_off_rounded : Icons.inbox_rounded, 
                               size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 24),
                          Text(
                            isSearch ? "'$keyword' 검색 결과가 없습니다." : '등록된 공지사항이 없습니다.',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isSearch ? '다른 키워드로 다시 검색해보세요.' : '새로운 공지사항을 작성해보세요.',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    // 새로고침 시 검색어도 초기화할지 여부는 기획에 따라 다름. 여기서는 유지하며 리프레시.
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
          ),
        ],
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
