import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 현재 인증 세션의 소유자를 나타냅니다.
///
/// 계정 전용 Provider는 이 값을 watch해 계정 경계를 넘는 캐시 재사용을 막습니다.
class SessionMemberIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void activate(int memberId) => state = memberId;

  void clear() => state = null;
}

final sessionMemberIdProvider = NotifierProvider<SessionMemberIdNotifier, int?>(
  SessionMemberIdNotifier.new,
);
