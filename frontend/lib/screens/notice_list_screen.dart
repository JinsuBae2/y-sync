import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../providers/mypage_provider.dart'; // 💡 추가
import '../providers/scrap_provider.dart';
import 'notice_detail_screen.dart';
import 'notice_form_screen.dart';
import '../widgets/notification_action_button.dart'; // 💡 추가

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
    final selectedGrade = ref.watch(noticeGradeProvider); // 💡 추가된 학년 상태

    // 💡 관리자 권한 확인 (ADMIN 또는 SUPER_ADMIN만 글쓰기 가능)
    final myPageAsync = ref.watch(myPageProvider);
    final bool isAdmin = myPageAsync.when(
      data: (data) => data.member.role == 'ADMIN' || data.member.role == 'SUPER_ADMIN',
      loading: () => false,
      error: (_, __) => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: const [
          NotificationActionButton(), // 💡 추가
        ],
      ),
      body: Column(
        children: [
          // 💡 공지사항 검색 바 (Search Bar) UI
          Container(
            color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.1),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                prefixIcon: const Icon(Icons.article_outlined, color: Colors.grey),
              ),
            ),
          ),
          // 💡 학년 필터링 칩 (Grade Filter Chips) - 검색창 아래로 이동
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildGradeChip(context, ref, '전체', 'ALL', selectedGrade),
                _buildGradeChip(context, ref, '1학년', 'GRADE_1', selectedGrade),
                _buildGradeChip(context, ref, '2학년', 'GRADE_2', selectedGrade),
                _buildGradeChip(context, ref, '3학년', 'GRADE_3', selectedGrade),
              ],
            ),
          ),
          // 💡 공지사항 리스트 영역
          Expanded(
            child: noticesAsync.when(
              data: (notices) {
                // 💡 학년 필터링 추가
                final filteredNotices = selectedGrade == 'ALL' 
                    ? notices 
                    : notices.where((n) => n.targetGrade == 'ALL' || n.targetGrade == selectedGrade).toList();

                if (filteredNotices.isEmpty) {
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
                    ref.invalidate(noticesProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredNotices.length,
                    itemBuilder: (context, index) {
                      final notice = filteredNotices[index];
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
      floatingActionButton: isAdmin ? FloatingActionButton.extended(
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
      ) : null,
    );
  }

  Widget _buildGradeChip(BuildContext context, WidgetRef ref, String label, String value, String selectedValue) {
    final isSelected = value == selectedValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          ref.read(noticeGradeProvider.notifier).updateGrade(selected ? value : 'ALL');
        },
        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
        checkmarkColor: Theme.of(context).colorScheme.primary,
        labelStyle: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class NoticeCard extends ConsumerWidget {
  final Notice notice;

  const NoticeCard({super.key, required this.notice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrapsAsync = ref.watch(scrapsProvider);
    final isScrapped = scrapsAsync.maybeWhen(
      data: (scraps) => scraps.any((s) => s.targetType == 'NOTICE' && s.targetId == notice.id),
      orElse: () => false,
    );

    final isNotice = notice.noticeType == 'NOTICE';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: notice.isPinned ? const Color(0xFF164687).withOpacity(0.05) : Colors.white, // 💡 상단 고정 글은 브랜드 컬러 연하게
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
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoticeDetailScreen(notice: notice),
              ),
            );
            // 💡 상세 화면에서 돌아올 때 조회수 증가를 반영하기 위해 리스트 새로고침
            ref.invalidate(noticesProvider);
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isNotice 
                            ? const Color(0xFFE53935).withOpacity(0.08) // 💡 연한 다홍색 파스텔 톤
                            : Theme.of(context).colorScheme.primary.withOpacity(0.08), // 💡 연한 블루 파스텔 톤
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isNotice 
                                ? Icons.campaign_rounded // 💡 중요 공지는 확성기 아이콘
                                : Icons.info_outline_rounded, // 💡 일반 공지는 정보 아이콘
                            size: 14,
                            color: isNotice ? const Color(0xFFE53935) : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isNotice ? '공지' : '일반',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isNotice ? const Color(0xFFE53935) : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 💡 북마크 아이콘 (토글)
                    InkWell(
                      onTap: () {
                        ref.read(scrapNotifierProvider).toggleScrap('NOTICE', notice.id);
                      },
                      child: Icon(
                        isScrapped ? Icons.bookmark : Icons.bookmark_border,
                        size: 24,
                        color: const Color(0xFF164687),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 24),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (notice.isPinned) // 💡 핀 고정 벡터 아이콘
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.push_pin_rounded,
                          size: 18,
                          color: Color(0xFF164687),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        notice.title,
                        style: const TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                          letterSpacing: -0.5,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
                    // 💡 댓글수 및 날짜 표시 (조회수 제거)
                    Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text('${notice.commentCount}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    const SizedBox(width: 12),
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
