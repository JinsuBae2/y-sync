import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/providers/admin_provider.dart';
import 'package:y_sync/providers/api_client_provider.dart';
import 'package:y_sync/providers/community_provider.dart';
import 'package:y_sync/providers/comment_provider.dart';
import 'package:y_sync/screens/admin_post_management_screen.dart';

Map<String, dynamic> _post(int id, String title, String category) => {
  'id': id,
  'title': title,
  'category': category,
  'content': '본문',
  'anonymous': false,
  'authorName': '작성자',
  'memberId': 1,
  'createdAt': '2026-10-28T09:00:00',
  'isDeleted': false,
};

void main() {
  test('삭제·복구와 댓글 작성 후 분리된 관리자 목록도 갱신한다', () async {
    final post = _post(1, '관리 대상', 'QA');
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'DELETE' && options.path == '/admin/posts/1') {
            post['isDeleted'] = true;
          } else if (options.path == '/admin/posts/1/restore') {
            post['isDeleted'] = false;
          } else if (options.method == 'POST' &&
              options.path == '/community/1/comments') {
            post['commentCount'] = 1;
          } else {
            expect(options.method, 'GET');
            expect(options.path, '/community');
            expect(options.queryParameters, isEmpty);
          }
          handler.resolve(
            Response(requestOptions: options, data: [Map.of(post)]),
          );
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);
    addTearDown(dio.close);
    container.listen(adminCommunityPostsProvider, (_, _) {});
    expect(
      (await container.read(adminCommunityPostsProvider.future))
          .single
          .isDeleted,
      isFalse,
    );

    final notifier = container.read(communityNotifierProvider);
    await notifier.deletePostByAdmin(1, '테스트');
    expect(
      (await container.read(adminCommunityPostsProvider.future))
          .single
          .isDeleted,
      isTrue,
    );
    await notifier.restorePostByAdmin(1);
    expect(
      (await container.read(adminCommunityPostsProvider.future))
          .single
          .isDeleted,
      isFalse,
    );
    await container
        .read(commentNotifierProvider)
        .createComment(CommentSource.community, 1, '댓글');
    expect(
      (await container.read(adminCommunityPostsProvider.future))
          .single
          .commentCount,
      1,
    );
  });

  testWidgets('관리자 전체·삭제 목록과 검색은 커뮤니티 검색·분류와 독립적이다', (tester) async {
    final posts = [
      _post(1, '깃허브 질문', 'QA'),
      _post(2, '동아리 소식', 'FREE'),
      {..._post(3, '삭제된 소식', 'FREE'), 'isDeleted': true},
    ];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final category = options.queryParameters['category'];
          final keyword = options.queryParameters['keyword'] as String?;
          handler.resolve(
            Response(
              requestOptions: options,
              data: posts
                  .where(
                    (post) =>
                        (category == null || post['category'] == category) &&
                        (keyword == null ||
                            (post['title'] as String).contains(keyword)),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        adminReportsProvider.overrideWith((ref) async => []),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(dio.close);
    container.read(communityCategoryProvider.notifier).updateCategory('QA');
    container
        .read(communitySearchKeywordProvider.notifier)
        .updateKeyword('깃허브');
    final communityPosts = await tester.runAsync(
      () => container.read(communityPostsProvider.future),
    );
    expect(communityPosts!.single.id, 1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AdminPostManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('깃허브 질문'), findsOneWidget);
    expect(find.text('동아리 소식'), findsOneWidget);
    expect(find.text('삭제된 소식'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '동아리');
    await tester.pumpAndSettle();
    expect(find.text('동아리 소식'), findsOneWidget);
    expect(find.text('깃허브 질문'), findsNothing);
    expect(container.read(communitySearchKeywordProvider), '깃허브');
    expect(container.read(communityCategoryProvider), 'QA');
    expect(container.read(communityPostsProvider).requireValue.single.id, 1);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(Tab, '삭제됨'));
    await tester.pumpAndSettle();
    expect(find.text('삭제된 소식'), findsOneWidget);
    expect(find.text('동아리 소식'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
