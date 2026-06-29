# Y-Sync Code Style & Commenting Conventions

Y-Sync 프로젝트에서 코드를 작성하고 수정할 때 AI 어시스턴트와 개발자가 반드시 지켜야 하는 주석 작성 규격, 한글 주석 컨벤션 및 네이밍 스타일 가이드라인입니다.

---

## 1. 주석 작성 규칙 (Commenting Policy)

코드의 가독성을 극대화하고 수정/버그 픽스/추가 내역을 한눈에 식별할 수 있도록 특유의 주석 컨벤션을 적용합니다.

### A. 전두 이모지(💡) 및 대괄호 활용
* **신규 추가/수정**: 새로 구현되거나 수정된 로직에는 반드시 한글 설명 전두에 **전구 이모지(`💡`)**를 필수로 삽입합니다.
  - 예: `// 💡 대댓글(답글) 작성 시 선택된 부모 댓글 상태를 포스트 ID별로 추적하는 Notifier`
* **버그 픽스 및 보완**: 특정 버그나 이슈 해결 과정에서 추가된 코드에는 버그 ID나 라벨을 명시합니다.
  - 예: `// 💡 [Bug4 Fix] 커뮤니티 목록 갱신을 위해 추가`
  - 예: `// 💡 [FCM 마운트] 외부 파이어베이스 키 설정 경로 지정`
* **UI/UX 데이터 매핑**: 프론트엔드 내에서 백엔드 데이터 모델을 주입하거나 매핑하는 지점에도 이모지 주석을 명시합니다.
  - 예: `parentId: activeParent?.id, // 💡 대댓글 parentId 주입`

### B. 한글 주석 원칙
* 소스 코드 내의 모든 설명 주석은 한국어로 작성하며, 비즈니스 목적을 명확히 명시합니다.
* 단순히 "코드 추가"라고 적기보다, **"왜 이 코드가 이 시점에 필요했는지"** 맥락과 부연 설명을 상세하고 친절하게 기입합니다.

---

## 2. 백엔드 코딩 규칙 (Java/Spring Boot)

* **네이밍 컨벤션**:
  - 클래스 및 인터페이스: PascalCase (예: `AdminMemberController`, `MemberRepository`)
  - 메소드 및 변수: camelCase (예: `dismissReport()`, `isAuthorSuspended`)
  - 데이터베이스 테이블 및 컬럼: snake_case (예: `member_id`, `is_deleted`)
* **DTO 정의**:
  - Request DTO는 요청 성격이 명확히 보이도록 접미사를 맞춥니다 (예: `ReportDismissRequest`).
  - Response DTO는 응답 구조를 명확히 투영하도록 설계합니다 (예: `AdminReportSummaryResponse`).
* **JPA 제약 조건 명시**:
  - 엔티티 필드 선언 시 단순히 기본 타입만 선언하지 말고, `@Column(nullable = false, length = ...)` 등 데이터베이스 수준의 제약 조건을 명시적으로 기입하여 정합성을 보장합니다.

---

## 3. 프론트엔드 코딩 규칙 (Dart/Flutter)

* **네이밍 컨벤션**:
  - 파일 및 디렉토리: snake_case (예: `admin_post_management_screen.dart`, `admin_provider.dart`)
  - 클래스 및 위젯: PascalCase (예: `AdminPostManagementScreen`)
  - 변수 및 함수: camelCase (예: `fetchPendingRequests()`, `_isSubmitting`)
* **Riverpod 3.x 상태 명명 규칙**:
  - `Notifier` 클래스: PascalCase + `Notifier` 접미사 (예: `ActiveParentCommentNotifier`)
  - `Provider` 변수: camelCase + `Provider` 접미사 (예: `activeParentCommentProvider`)
  - Notifier 내부 상태 수정 메소드는 `updateState(Value)` 또는 `set(Value)` 로 통일하여 직관성을 높입니다.

---

## 4. 소스 코드 보존 정책 (Documentation Integrity)

* **기존 주석 및 Javadoc 보존**: 수정을 요청받지 않은 영역의 기존 주석, 영문 설명문, Javadoc 다큐멘테이션은 절대로 임의로 지우거나 훼손하지 않고 원본 그대로 보존합니다.
* **불필요한 리포맷팅 지양**: 의미 없는 공백 라인 삽입, 단순 줄바꿈 수정 등을 통해 Git Diff의 크기를 불필요하게 부풀리지 말고, 오직 수정하고자 하는 비즈니스 로직 단위에만 집중하여 코드를 변경합니다.
