import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notice.dart';
import 'api_client_provider.dart';
import 'notice_provider.dart';

/// 💡 공지 피드 한 화면의 상태입니다.
///
/// [pinned]는 첫 페이지에서만 채워지고 더 불러와도 바뀌지 않습니다. 고정 공지는 커서 페이징에서
/// 빠져 있어 스크롤 도중 목록 중간에 끼어들지 않습니다.
///
/// [latestId]는 "이 목록을 만들 때 가장 최신이던 공지"입니다. 새 공지가 올라왔는지 물을 때
/// 기준값으로 씁니다. [newCount]는 그 질의 결과이고, 목록에는 아직 반영되지 않은 수입니다.
class NoticeFeedState {
  const NoticeFeedState({
    this.pinned = const [],
    this.items = const [],
    this.nextCursor,
    this.hasNext = false,
    this.latestId,
    this.isLoadingMore = false,
    this.newCount = 0,
  });

  final List<Notice> pinned;
  final List<Notice> items;
  final String? nextCursor;
  final bool hasNext;
  final int? latestId;
  final bool isLoadingMore;
  final int newCount;

  /// 화면에 그릴 순서입니다. 고정 공지가 항상 위입니다.
  List<Notice> get visibleNotices => [...pinned, ...items];

  bool get isEmpty => pinned.isEmpty && items.isEmpty;

  NoticeFeedState copyWith({
    List<Notice>? pinned,
    List<Notice>? items,
    String? nextCursor,
    bool? hasNext,
    int? latestId,
    bool? isLoadingMore,
    int? newCount,
    bool clearNextCursor = false,
  }) {
    return NoticeFeedState(
      pinned: pinned ?? this.pinned,
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasNext: hasNext ?? this.hasNext,
      latestId: latestId ?? this.latestId,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      newCount: newCount ?? this.newCount,
    );
  }
}

/// 💡 커서 기반으로 공지를 이어 받는 Notifier입니다.
///
/// 이전에는 `/notices`를 페이지 지정 없이 불러 서버 기본값인 20건만 받았고, 화면에도 더 보는
/// 수단이 없어서 **21번째 공지부터는 아예 볼 수 없었습니다.**
///
/// 학년 필터와 검색어를 `watch`하므로 둘 중 하나가 바뀌면 Riverpod이 [build]를 다시 실행합니다.
/// 커서는 그 과정에서 자연스럽게 버려지고 목록이 처음부터 다시 쌓입니다.
class NoticeFeedNotifier extends AsyncNotifier<NoticeFeedState> {
  static const int pageSize = 10;

  String _grade = 'ALL';
  String _keyword = '';

  @override
  Future<NoticeFeedState> build() async {
    _grade = ref.watch(noticeGradeProvider);
    _keyword = ref.watch(searchKeywordProvider).trim();
    return _fetch(cursor: null);
  }

  Future<NoticeFeedState> _fetch({required String? cursor}) async {
    final dio = ref.read(dioProvider);
    final response = await dio.get(
      '/notices/feed',
      queryParameters: {
        'size': pageSize,
        'grade': _grade,
        'cursor': ?cursor,
        if (_keyword.isNotEmpty) 'keyword': _keyword,
      },
    );

    final data = response.data as Map<String, dynamic>;
    List<Notice> parse(String key) => (data[key] as List<dynamic>? ?? const [])
        .map((json) => Notice.fromJson(json as Map<String, dynamic>))
        .toList();

    return NoticeFeedState(
      pinned: parse('pinned'),
      items: parse('items'),
      nextCursor: data['nextCursor'] as String?,
      hasNext: data['hasNext'] as bool? ?? false,
      latestId: data['latestId'] as int?,
    );
  }

  /// 다음 페이지를 이어 붙입니다. 이미 불러오는 중이거나 마지막 페이지면 아무 일도 하지 않습니다.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasNext ||
        current.nextCursor == null) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _fetch(cursor: current.nextCursor);

      // 💡 커서 페이징이라 겹칠 일이 없어야 하지만, 방어적으로 한 번 더 거릅니다.
      //    같은 공지가 두 번 그려지면 ListView가 키 충돌로 깨집니다.
      final existingIds = current.items.map((notice) => notice.id).toSet();
      final appended = next.items
          .where((notice) => !existingIds.contains(notice.id))
          .toList();

      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...appended],
          nextCursor: next.nextCursor,
          hasNext: next.hasNext,
          isLoadingMore: false,
          clearNextCursor: next.nextCursor == null,
        ),
      );
    } catch (_) {
      // 더 불러오기 실패는 이미 보고 있는 목록을 지우지 않습니다. 다음 스크롤에서 다시 시도합니다.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  /// 새로 올라온 공지 수를 확인합니다. 목록은 건드리지 않고 [NoticeFeedState.newCount]만 갱신합니다.
  Future<void> checkForNewNotices() async {
    final current = state.value;
    if (current?.latestId == null) return;

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/notices/feed-updates',
        queryParameters: {
          'sinceId': current!.latestId,
          'grade': _grade,
          if (_keyword.isNotEmpty) 'keyword': _keyword,
        },
      );
      final count = (response.data as Map<String, dynamic>)['newCount'] as int?;
      final latest = state.value;
      if (latest == null || count == null) return;
      state = AsyncData(latest.copyWith(newCount: count));
    } catch (_) {
      // 조용히 넘어갑니다. 다음 주기에 다시 확인하며, 실패를 알릴 만한 사용자 행동이 없습니다.
    }
  }

  /// 목록을 처음부터 다시 불러옵니다. 당겨서 새로고침과 "새 공지" 칩이 함께 씁니다.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(cursor: null));
  }
}

final noticeFeedProvider =
    AsyncNotifierProvider<NoticeFeedNotifier, NoticeFeedState>(
      NoticeFeedNotifier.new,
    );
