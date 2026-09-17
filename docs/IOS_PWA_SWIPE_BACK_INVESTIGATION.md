# iPhone PWA 게시글 스와이프 복귀 문제 조사 기록

작성일: 2026-09-16
상태: 진단 모드 구현 — 원인 미확정, 화면 전환 수정·운영 배포하지 않음

## 사용자 제보

- iPhone에서 홈 화면에 추가한 PWA로 실행한다.
- 공지와 커뮤니티 게시글에서 왼쪽 가장자리를 스와이프해 뒤로 갈 때 모두 발생한다.
- 스와이프 중 상세 화면이 오른쪽으로 이동하고 왼쪽에 넓은 회색 영역과 이전 화면 일부가 보인다.
- 손을 떼면 목록 대신 회색 화면이 나타났다가 로딩 후 목록이 표시된다.
- 항상 발생하지는 않으며 바로 목록으로 돌아올 때도 있다.
- 상단 뒤로가기 버튼에서도 같은 현상이 발생하는지는 확인하지 않았다.

## 확인한 코드 경로

- `frontend/lib/utils/content_detail_navigation.dart`
  - 공지·커뮤니티 공통 상세 진입 함수 `openContentDetail()`.
  - 로딩 다이얼로그 표시 → 상세 데이터 조회 → 다이얼로그 pop → `adaptivePageRoute`로 상세 push.
  - 상세에서 돌아오면 `ContentDetailResult`를 반환한다.
- `frontend/lib/utils/adaptive_page_route.dart`
  - `defaultTargetPlatform == TargetPlatform.iOS`이면 `CupertinoPageRoute`를 사용한다.
  - 웹 여부를 별도로 분기하지 않아 iPhone PWA에서도 적용된다.
- `frontend/lib/screens/notice_list_screen.dart`
  - 상세 복귀 결과가 null이 아니면 `noticesProvider`를 invalidate한다.
- `frontend/lib/screens/community_list_screen.dart`
  - 동일하게 `communityPostsProvider`를 invalidate한다.
- `frontend/lib/screens/home_screen.dart`
  - 홈에서 상세 복귀 시에도 홈 목록 provider를 invalidate한다. 이번 지연 응답 테스트는 공지·커뮤니티 목록 화면을 대상으로 했으며 홈은 별도 검증하지 않았다.
- `docs/WORK_LOG.md`의 2026-09-01 기록
  - iOS 스와이프 지원을 추가했고 위젯 테스트를 수행했다.
  - iPhone PWA 실기기 전환 확인은 후속 작업으로 기록되어 있다.

## 수행한 진단과 결과

기존 `frontend/test/content_flow_design_test.dart`를 바탕으로 임시 진단 테스트를 작성했다.

1. 테스트 플랫폼을 iOS로 설정했다.
2. 공지·커뮤니티 목록에서 상세로 진입했다.
3. 왼쪽 가장자리에서 오른쪽으로 드래그해 복귀했다.
4. 두 번째 목록 요청은 Completer로 응답을 보류했다.
5. 전환 후 기존 제목과 목록이 남아 있고 CircularProgressIndicator가 없는지 확인했다.
6. 응답을 완료하고 예외 없이 마무리되는지 확인했다.

최종 결과: **공지·커뮤니티 2개 테스트 통과**.

응답 보류 중 상태는 두 화면 모두 `AsyncData(isLoading: true, value: 기존 목록)`이고, 표시 중인 CircularProgressIndicator는 0개였다.

로컬 Riverpod 3.2.1의 `AsyncValue.when`은 `skipLoadingOnRefresh = true`가 기본값이다. 따라서 단순 invalidate에 의한 재조회는 기존 데이터를 유지한다.

**정정:** 초기 설명인 “복귀 후 invalidate 때문에 목록이 반드시 로딩 화면으로 바뀐다”는 부정확했다. 단순 재조회만으로 제보 증상을 재현하지 못했다. 다만 다른 의존성 변경·오류·화면 재생성까지 배제한 것은 아니다.

테스트 작성 중 미완료 비동기 상태에서 pumpAndSettle이 끝나지 않는 문제와 테스트 플랫폼 복구 문제를 조정했다. 이 중간 실패를 실기기 증상 재현으로 해석하면 안 된다.

임시 테스트 `frontend/test/swipe_diagnostic_temp_test.dart`는 조사 후 제거했다. 운영 코드는 변경하지 않았다.

## 아직 확인되지 않은 것

- PWA 페이지 전체가 재로드되는지, Flutter 내부 라우트만 전환되는지.
- 회색 영역이 WebKit의 뒤로가기 화면인지, Flutter 전환 중 렌더링 결과인지.
- 다이얼로그 종료와 상세 진입의 전환 타이밍이 영향을 주는지.
- 버튼 복귀와 스와이프 복귀의 차이, 제스처 취소·속도에 따른 차이.
- 실제 iOS 버전 및 기기 조건.

현재 가설은 **iOS PWA의 브라우저 뒤로가기 처리와 Flutter 화면 전환의 상호작용**이다. 사진과 간헐적 발생 특성에 근거한 가설이며 확정 원인이 아니다.

유사 참고 보고: https://github.com/flutter/flutter/issues/99755
오래된 Flutter 공식 저장소 이슈이며, 현 서비스와 같은 원인이거나 현재 버전에 그대로 적용된다는 증거는 아니다.

## 다음 조사 순서

1. 최소 진단 기록 추가
   - 앱 시작마다 구분 가능한 실행 ID.
   - 페이지 표시·숨김·히스토리 이동 이벤트(웹 구현에서 지원 여부 확인).
   - Navigator push/pop 및 사용자 제스처 시작·종료.
   - 목록 요청 시작·종료와 기존 데이터 보유 여부.
   - 토큰, 개인정보, 게시글 본문은 기록하지 않는다.
2. 동일 게시글에서 버튼 복귀와 스와이프 복귀를 비교한다.
3. 느린 스와이프·빠른 스와이프·취소 후 재시도를 비교한다.
4. 문제가 발생한 시점의 앱 실행 ID와 라우트 기록으로 전체 재로드와 내부 전환을 구분한다.
5. 원인이 좁혀진 뒤 하나의 변경만 적용해 비교한다.

로컬 위젯 테스트에는 Safari/WebKit의 실제 PWA 제스처와 화면 합성이 포함되지 않는다. 에이전트가 가능한 코드 추적·로컬 검증을 먼저 수행하고, 실기기 확인은 진단 준비 후 최소한으로 요청한다.

## 수정 범위 주의

- 원인 확인 없이 목록 invalidate를 제거하거나 iOS 스와이프를 일괄 비활성화하지 않는다.
- 공지·커뮤니티를 따로 고치기 전에 공통 전환 경로를 확인한다.
- provider 공통 클라이언트 분리 작업과 별개다. `api_client_provider.dart` 추출은 동작 유지 리팩터링이며 이 문제를 해결한 변경이 아니다.
- OAuth, 서버 보안 설정, 페이징 개편과 묶지 않는다.
- 사용자 요청에 따라 이 문서는 후속 작업을 위한 인수인계용으로 작성했다. 새 수정·PR·배포를 실행하라는 지시가 아니다.


## 후속 작업: 선택적 진단 모드

페이지 전체 재로드와 Flutter 내부 pop을 구분하기 위한 로컬 진단을 추가했다. 화면 전환이나 목록 갱신 정책은 변경하지 않았다.

- `frontend/web/swipe_diagnostics.js`: 페이지 시작, pageshow/pagehide, visibility, popstate, 터치 시작/종료/취소. 최근 150개만 sessionStorage에 보관한다.
- `frontend/lib/utils/swipe_diagnostics*.dart`: Flutter 시작과 Navigator 이동·제스처 기록. 네이티브에서는 기록하지 않는다.
- `frontend/lib/providers/api_client_provider.dart`: 공지·커뮤니티 목록 요청 시작/성공/실패를 고정 분류만으로 기록한다.
- 기본 비활성. 서버 전송은 없으며 URL, 검색어, 토큰, 회원 ID, 게시글 본문을 기록하지 않는다.

### 실행 방법

이미 설치한 PWA에서 확실히 켜려면 별도 진단 빌드를 사용한다.

```sh
cd frontend
flutter build web --release --dart-define=SWIPE_DIAGNOSTICS=true
```

빌드가 배포된 뒤 PWA를 다시 열면 우측 상단에 `진단 저장`·`진단 종료` 버튼이 표시된다. 버튼은 진단 모드에서만 보인다. 실제 배포는 이 작업에서 수행하지 않았다.

일반 웹 브라우저에서는 URL의 `swipeDebug=1` 쿼리로도 켤 수 있다. Safari 탭에서 켠 설정이 별도 설치 PWA로 전달된다고 가정하면 안 된다. `swipeDebug=0` 또는 `진단 종료`는 보관 기록을 삭제하고 기록을 중단한다. 진단 빌드는 다음 앱 시작 시 다시 활성화하므로 조사 종료 후 일반 빌드로 돌아간다.

현상이 발생한 뒤 `진단 저장`으로 JSON을 저장한다. 저장 버튼은 다운로드 동작을 사용하며 iOS 실기기에서 저장 UI 확인이 필요하다. sessionStorage가 제한되는 환경에서는 메모리에만 기록되어 재로드 이전 기록이 남지 않을 수 있다. 앱 종료·탭 폐기까지 영구 보관하는 장치는 아니다.

### 기록 해석

- 서로 다른 `run`의 `page_start`가 이어짐: JS 페이지가 다시 실행됨. 각 `flutter_start`와 함께 보면 Flutter 재시작 여부를 확인할 수 있다.
- 같은 run에서 `page_show`의 `cached`: 브라우저의 이전 문서 복원 경로. 단순 Flutter pop과 구분한다.
- 같은 run에서 `gesture_start → route_pop → gesture_stop`: Flutter 제스처에 의한 화면 복귀. 실제 순서는 프레임 타이밍에 따라 다를 수 있다.
- `history_pop`와 페이지 이벤트가 겹치면 브라우저 히스토리 관여 가능성을 조사한다. 이 이벤트 하나만으로 충돌을 확정하지 않는다.
- `request_start → request_end`만 지연되고 새 page_start가 없다면 목록 요청 또는 내부 전환 쪽을 추적한다.

진단 버튼과 기록 자체가 타이밍에 약간 영향을 줄 수 있다. 문제가 진단 모드에서 사라진 것만으로 수정됐다고 판단하지 않는다.

### 이번 구현의 검증

- JavaScript 진단 테스트 6개 통과: 기본 비활성, 재로드 전후 기록 유지, 150개 상한, 민감한 임의 상세값 제외, 종료 시 삭제, 저장소 차단 시 안전 동작.
- Flutter 전체 테스트 55개 통과: 기존 화면 전환 회귀와 새 진단 observer·요청 분류 테스트 포함.
- Flutter 분석: 오류 없음. 기존 경고 3개·정보 27개 유지.
- 실제 iPhone PWA에서 진단 모드를 켜고 회색 화면을 재현한 기록은 아직 없다.
- 진단 플래그를 켠 웹 릴리스 빌드 성공. 출력물의 진단 스크립트 포함 및 Flutter 부트스트랩 이전 로딩 순서를 확인했다.

## 실기기 기록 분석 및 수정 후보

두 진단 파일에서 브라우저 history_pop 이후 Flutter route_pop으로 복귀하는 경로와, history_pop 없이 Flutter gesture_start → route_pop으로 복귀하는 경로가 모두 관찰됐다. 두 번째 기록의 반복 복귀 중 페이지 재시작은 없었다. 전체 페이지 재시작 기록은 일반 터치 직후여서 진단 파일 다운로드에 따른 이탈 가능성도 있으며, 이를 회색 화면 원인으로 단정하지 않는다.

로컬 Flutter 엔진의 `SingleEntryBrowserHistory.onPopState`는 브라우저 popstate를 받아 Flutter `popRoute`를 호출한다. 즉 목록 API 외에 브라우저 전환과 Flutter 자체 전환이라는 두 경로가 존재한다.

수정 후보: iOS의 설치형 PWA에서 공통 공지·커뮤니티 상세 라우트가 최상단일 때만 왼쪽 20px의 단일 touchstart에 preventDefault를 적용한다. 이벤트 전파를 막지 않아 Flutter의 포인터·스와이프 처리를 유지한다. 목록·다이얼로그·Safari 일반 탭·Android는 적용하지 않으며, 다중 터치도 제외한다. 라우트 이름과 URL은 변경하지 않는다.

근거 참고: https://bugs.webkit.org/show_bug.cgi?id=240892 (iOS touchstart 기본 동작 차단 관련 보고). 브라우저 버전별 실기기 효과까지 보장하는 근거는 아니다.

이 변경은 두 제스처 경로의 경합을 줄이는 검증 대상 수정안이다. 로컬 테스트는 적용 조건과 Flutter 복귀 유지 여부를 확인하며, **아이폰에서 회색 화면 해결 여부는 배포 후 확인해야 한다.** 진단 모드는 유지하여 비교할 수 있다.


## 2026-09-17 목록 스와이프 후속 대응 (PR 1)

배포 후 수집한 네 번째 기록에서 상세 복귀 4회는 Flutter 제스처로 처리됐고, 목록에서는 history_pop이 반복됐다. 해당 기록 안에는 페이지 재시작이나 목록 스와이프 직후 API 재요청이 없었다. other → touch_cancel → history_pop도 관찰되지만 좌표·방향이 없어 가장자리 밖에서 시작한 뒤로가기라고 확정하지 않는다.

이에 설치형 iOS PWA 전체의 왼쪽 20px에 기본 제스처 차단을 적용하고, 메인 탭에 PopScope 안전망을 추가했다. Flutter의 PageView 탭 이동과 상세 스와이프는 유지한다. 진단 기준 역시 20px로 맞추고 JavaScript 테스트를 CI에 포함했다. 상세 전용 observer·라우트 표식은 더 이상 필요하지 않아 제거했다.

검증: Flutter 57개·JavaScript 9개 테스트 통과, 진단 활성 웹 릴리스 빌드 성공, 분석 오류 없음(기존 경고 3개·정보 27개). 루트 안전망은 Flutter에 전달된 뒤로가기 요청만 처리한다. **실기기 회색 화면 해결 및 브라우저 차원의 모든 이탈 방지는 아직 검증되지 않았다.**


## 2026-09-17 차단 핸들러 진단 보완

PR #101 운영 배포 성공 후 수집한 다섯 번째 기록에서도 상세 복귀 시 history_pop이 관찰됐다. 기록 중 페이지 재시작은 없었고, 공지·커뮤니티 복귀 후 목록 요청은 각각 약 84ms·59ms였다. 기존 기록만으로는 기기에 로드된 스크립트 버전이나 preventDefault 실행 여부를 알 수 없어 동작 변경 대신 진단을 보완했다.

- `guard_touch`: 차단 핸들러가 실제 실행된 터치에 남긴다.
  - `prevented`: preventDefault 호출 후 defaultPrevented=true. WebKit 화면 전환 차단 성공을 보장하지 않는다.
  - `not_prevented`: 호출했지만 defaultPrevented=false.
  - `not_cancelable`: 왼쪽 20px 단일 터치지만 cancelable=false라 호출하지 않음.
  - `outside_edge` / `multi_touch`: 기존 차단 대상 밖이어서 호출하지 않음.
- 매 이벤트의 `diagnosticVersion=diag_v2`, `guardVersion=guard_v3`, `flutterVersion=flutter_v2`는 각 진단 구현의 고정 세대 표식이다. Git SHA 또는 전체 앱 빌드 번호가 아니다. Flutter 시작 이전에는 flutterVersion이 unknown이다.
- `guardEnabled`: 실제 JS가 판단한 설치형 iOS PWA 여부. 브리지가 없으면 null, 버전 표식이 없거나 알 수 없는 값이면 unknown으로 남긴다. 이전 기록에 필드가 없는 경우도 최신 버전으로 추정하지 않는다.
- 이벤트별 표식이므로 150개 순환 기록에서 시작 이벤트가 밀려나도 버전을 확인할 수 있다. 서버 전송 없이 기기에 보관하며, 진단 API가 없거나 실패해도 터치 처리에 영향이 없도록 보호했다.

해석 순서: 실행 표식 → guardEnabled → 해당 터치의 guard_touch 결과 → history_pop 순서로 비교한다. guard_touch가 없다는 사실만으로 WebKit 버그라고 단정하지 않는다. 기존 진단 저장 버튼을 사용하며 추가 활성화 절차는 없다.

검증: Flutter 57개·JavaScript 13개 테스트 통과, 분석 오류 없음(기존 경고 3개·정보 27개), 진단 활성 웹 빌드 성공. 실기기 재현 기록은 배포 후 확인한다.
