import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/models/notification.dart';

void main() {
  test('알림 읽음 상태의 현재 응답 키를 파싱한다', () {
    final notification = AppNotification.fromJson(
      _notificationJson(isRead: true),
    );

    expect(notification.isRead, isTrue);
  });

  test('기존 백엔드의 read 응답 키도 파싱한다', () {
    final json = _notificationJson()..['read'] = true;
    final notification = AppNotification.fromJson(json);

    expect(notification.isRead, isTrue);
  });
}

Map<String, dynamic> _notificationJson({bool? isRead}) {
  final json = <String, dynamic>{
    'id': 1,
    'title': '새 공지',
    'body': '공지 내용',
    'targetType': 'NOTICE',
    'targetId': 10,
    'createdAt': '2026-08-25T12:00:00',
  };
  if (isRead != null) json['isRead'] = isRead;
  return json;
}
