import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/models/comment.dart';
import 'package:y_sync/models/community_post.dart';
import 'package:y_sync/models/my_comment.dart';
import 'package:y_sync/models/notice.dart';
import 'package:y_sync/providers/admin_provider.dart';

void main() {
  test('공지와 커뮤니티는 현재 및 기존 고정 키를 모두 파싱한다', () {
    expect(Notice.fromJson(_noticeJson('isPinned')).isPinned, isTrue);
    expect(Notice.fromJson(_noticeJson('pinned')).isPinned, isTrue);
    expect(CommunityPost.fromJson(_communityJson('isPinned')).isPinned, isTrue);
    expect(CommunityPost.fromJson(_communityJson('pinned')).isPinned, isTrue);
  });

  test('관리자 신고 상태는 현재 및 기존 boolean 키를 모두 파싱한다', () {
    final current = AdminReportSummary.fromJson({
      ..._reportJson(),
      'isAuthorSuspended': true,
      'isDeleted': true,
    });
    final legacy = AdminReportSummary.fromJson({
      ..._reportJson(),
      'authorSuspended': true,
      'deleted': true,
    });

    expect(current.isAuthorSuspended, isTrue);
    expect(current.isDeleted, isTrue);
    expect(legacy.isAuthorSuspended, isTrue);
    expect(legacy.isDeleted, isTrue);
  });

  test('게시글과 댓글 삭제 상태는 현재 및 기존 키를 모두 파싱한다', () {
    expect(CommunityPost.fromJson(_communityJson('isDeleted')).isDeleted, isTrue);
    expect(CommunityPost.fromJson(_communityJson('deleted')).isDeleted, isTrue);
    expect(Comment.fromJson(_commentJson('isDeleted')).isDeleted, isTrue);
    expect(Comment.fromJson(_commentJson('deleted')).isDeleted, isTrue);
    expect(MyComment.fromJson(_myCommentJson('isDeleted')).isDeleted, isTrue);
    expect(MyComment.fromJson(_myCommentJson('deleted')).isDeleted, isTrue);
  });
}

Map<String, dynamic> _noticeJson(String pinnedKey) => {
  'id': 1,
  'title': '공지',
  'content': '내용',
  'authorName': '관리자',
  'noticeType': 'NOTICE',
  'createdAt': '2026-08-25T12:00:00',
  pinnedKey: true,
};

Map<String, dynamic> _communityJson(String pinnedKey) => {
  'id': 1,
  'category': 'FREE',
  'title': '게시글',
  'content': '내용',
  'anonymous': false,
  'authorName': '학생',
  'memberId': 1,
  'createdAt': '2026-08-25T12:00:00',
  pinnedKey: true,
};

Map<String, dynamic> _commentJson(String deletedKey) => {
  'id': 1,
  'content': '댓글',
  'memberId': 1,
  'authorName': '학생',
  'createdAt': '2026-08-25T12:00:00',
  deletedKey: true,
};

Map<String, dynamic> _myCommentJson(String deletedKey) => {
  'id': 1,
  'content': '댓글',
  'postTitle': '게시글',
  'category': 'COMMUNITY',
  'postId': 1,
  'createdAt': '2026-08-25T12:00:00',
  deletedKey: true,
};

Map<String, dynamic> _reportJson() => {
  'targetType': 'POST',
  'targetId': 1,
  'reportCount': 1,
  'title': '신고 글',
  'content': '내용',
  'authorName': '학생',
  'reasons': <String>[],
};
