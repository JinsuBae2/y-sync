# Y-Sync Troubleshooting & Solutions

Y-Sync 프로젝트 개발 과정에서 직면했던 크리티컬한 에러들과 이에 대한 아키텍처적 해결 방안을 보존한 문서입니다. 유사한 상황에서 해결 패턴을 학습하기 위한 용도로 사용됩니다.

---

## 1. Flutter Web 릴리즈 빌드 내 파일 업로드 `LateInitializationError` 해결

### 문제 현황
- **원인**: Flutter Web 환경에서 릴리즈 컴파일(`--release` 난독화/최적화) 진행 시, `file_picker` 패키지의 static late 인스턴스가 컴파일러 최적화에 의해 유실되거나 초기화 시점이 어긋나, 어드민 학생 대량 등록(CSV 파일 업로드) 팝업 클릭 시 `LateInitializationError`와 함께 앱이 크래시되는 현상이 발견되었습니다.
- **해결 방안**: 외부 라이브러리 의존성을 제거하고 플랫폼 스텁을 제작하여 우회했습니다.
  * **[csv_picker_web.dart](file:///c:/Users/YNC/Desktop/ysync/y-sync/frontend/lib/utils/csv_picker_web.dart)**: Web 환경일 경우, `dart:html` 패키지의 `FileUploadInputElement`를 동적으로 생성 및 클릭 이벤트를 강제 실행하여 파일을 가로채는 순수 HTML5 업로드 기법으로 전면 대체했습니다.
  * 모바일 앱용 stub과 Web 업로더를 추상화 레이어로 래핑하여 플랫폼 안정성을 극대화했습니다.

---

## 2. Riverpod 3.0 Notifier Family 타입 바인딩 컴파일 에러 해결

### 문제 현황
- **원인**: 프로젝트의 상태 관리 라이브러리인 `flutter_riverpod`가 3.x 버전으로 올라감에 따라, 2.x 버전의 레거시 상태 클래스인 `StateProvider`와 `FamilyNotifier`가 완전히 삭제 및 폐기 처리되었습니다.
- **실패 사례**: 대댓글 작성 상태(답글 대상 댓글 지정)를 개별 포스트 화면마다 격리하여 관리하기 위해 `FamilyNotifier`를 적용했으나, 다트 컴파일러가 `FamilyNotifier` 타입을 찾지 못하고 컴파일 빌드 단계(`flutter build`)에서 작동을 거부했습니다.
- **해결 방안**: Notifier family를 쓰지 않고, 상태 자체를 **Map 형태**로 전역 격리하여 관리하는 구조로 패러다임을 우회 적용했습니다.

```dart
// [AS-IS] 컴파일 에러 유발 코드
class ActiveParentCommentNotifier extends FamilyNotifier<Comment?, int> { ... }
final activeParentCommentProvider = NotifierProvider.family<ActiveParentCommentNotifier, Comment?, int>(...);

// [TO-BE] Riverpod 3.x 완전 호환 우회 패턴
class ActiveParentCommentNotifier extends Notifier<Map<int, Comment?>> {
  @override
  Map<int, Comment?> build() => {};

  void updateState(int postId, Comment? comment) {
    state = {
      ...state,
      postId: comment,
    };
  }
}
final activeParentCommentProvider = NotifierProvider<ActiveParentCommentNotifier, Map<int, Comment?>>(
  ActiveParentCommentNotifier.new,
);
```

- **효과**: Riverpod 3.0 컴파일러 사양에 완전히 부합하게 되었으며, UI에서의 조회를 `ref.watch(activeParentCommentProvider)[postId]` 형태로 직관적으로 처리할 수 있게 되었습니다.

---

## 3. Spring MVC 컨트롤러 내 `AuthUtil` 주입 에러 (NPE) 해결

### 문제 현황
- **원인**: REST 컨트롤러(예: `MemberProfileController`, `ScrapController`)의 개별 요청 핸들러 메소드 파라미터로 `AuthUtil` 클래스를 직접 명시하여 컴파일 및 실행 시 스프링 MVC 리졸버가 null을 강제로 바인딩함으로써 실행 시점에 `NullPointerException`이 속출하는 버그가 발생했습니다.
- **해결 방안**: 핸들러 메소드 내부 매개변수가 아닌, 스프링 빈 컨테이너의 DI를 통해 필드 레벨로 생성자 주입을 하도록 조치하였습니다.

```java
// [TO-BE] 올바른 생성자 주입 방식
@RestController
@RequiredArgsConstructor
public class MemberProfileController {
    private final AuthUtil authUtil; // 생성자 필드 주입

    @GetMapping("/profile")
    public ResponseEntity<?> getProfile() {
        Long memberId = authUtil.getLoginMemberId(); // 내부에서 직접 조회
        ...
    }
}
```
