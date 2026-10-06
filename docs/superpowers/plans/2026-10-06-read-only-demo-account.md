# 읽기 전용 포트폴리오 데모 계정 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 현재 요청은 계획 작성이며 구현·계정 발급·배포는 포함하지 않는다.

**Goal:** 포트폴리오 방문자가 전용 아이디·비밀번호로 로그인하여 일반 사용자 화면을 조회하고 검색하되, 서버 데이터와 계정 상태를 변경하지 못하게 한다.

**Architecture:** 기존 JWT 로그인과 회원 모델을 재사용하고 `DEMO` 역할을 추가한다. 인증 필터 이후에 데모 요청 정책을 적용하여 승인된 조회 경로만 허용하며, 조회 과정의 자동 변경은 별도로 생략한다. Flutter는 역할을 기준으로 변경 UI와 자동 변경 요청을 제한한다.

**Tech Stack:** Java 21, Spring Boot / Security / JPA, MySQL, Flutter, Riverpod, Dio, JUnit / MockMvc, flutter_test.

**Spec:** 이 문서의 확정 요구사항 및 범위. 대화에서 사용자는 “변경만 금지”를 확정했다. 아래 세부 구현 방식은 검토를 위한 제안이다.

## 확정 요구사항 및 범위

- 로그인, 목록·상세 조회, 검색·필터, 페이지 이동은 허용한다.
- 생성·수정·삭제, 업로드, 스크랩 토글, 신고·문의 전송, 관리자 신청, 알림·인증 설정 변경은 금지한다.
- 서버가 최종적으로 요청을 차단한다. UI 비활성화만으로 완료하지 않는다.
- 이번 제안의 최소 범위는 기존 로그인 화면에 공개 데모 아이디·비밀번호를 직접 입력하는 방식이다. 원클릭 데모 버튼은 별도 후속 작업으로 둔다.
- 관리자 화면은 공개하지 않는다. 일반 회원의 조회 화면만 제공한다.
- 데모 상세 조회는 조회수를 올리지 않는다. 푸시 토큰 등록, 알림 읽음 저장, 학년 확인 저장도 수행하지 않는다.
- 로그아웃은 가능하며 로컬 토큰만 제거한다. 서버의 데모 로그아웃은 성공 응답만 반환하고 DB를 변경하지 않는다.
- 접근 로그 등 인프라 기록은 유지한다. “변경 금지”는 업무 데이터 및 계정 변경을 뜻한다.

## Global Constraints

- 기존 일반 사용자·관리자 권한과 동작은 유지한다.
- 새로운 인증 라이브러리나 인증 서비스는 도입하지 않는다.
- `MemberRole.DEMO`는 `USER`, `ADMIN`, `SUPER_ADMIN` 권한을 상속하지 않는다. 필요한 읽기 경로만 허용한다.
- 데모 설정은 기본 비활성화한다. 아이디·비밀번호는 환경 설정으로 주입하고 비밀번호는 BCrypt로 저장한다.
- 기존 `DataInitializer`는 `!prod`에서만 실행되며 기존 계정과 데이터를 함께 처리한다. 운영 데모 발급을 위해 해당 제한을 풀지 않는다.
- 기존 계정과 아이디가 충돌하면 덮어쓰지 않고 실패한다. 재시작 시 비밀번호를 매번 초기화하지 않는다.
- 운영은 `ddl-auto=validate`이므로 DB의 역할 컬럼이 실제로 ENUM인지 확인하고, 필요한 경우 DEMO 추가 DDL을 배포 전에 적용한다.
- 공개 전에 샘플 데이터가 있는 시연 환경을 우선 사용한다. 실제 운영 DB를 사용하려면 공개 가능한 본문·댓글·작성자·첨부파일 범위를 먼저 확인한다. 이 계획에는 인프라 복제나 전체 데이터 마스킹 구현은 포함하지 않는다.

## 확인한 현재 구조

- `config/SecurityConfig.java`: JWT 필터와 역할 계층, 공개 `/auth/**`, 인증 필요한 나머지 경로가 한곳에 있다.
- `config/JwtAuthenticationFilter.java`: JWT 인증 후 DB 회원의 실제 역할을 권한으로 설정한다. 클라이언트가 보낸 역할 값으로 판단하지 않는다.
- `domain/MemberRole.java`: 현재 `USER`, `ADMIN`, `SUPER_ADMIN`만 있다.
- `controller/MemberController.java`: `/auth/login`, `/auth/logout`, `/auth/fcm-token`, 공개 비밀번호 복구 경로가 있다.
- `service/MemberService.java`: 활성화 여부와 BCrypt 비밀번호를 확인하는 로그인이다.
- `service/NoticeService.java`, `service/CommunityService.java`: 상세 조회에서 조회수 증가 UPDATE를 실행한다.
- `frontend/lib/providers/auth_provider.dart`: 로그인 상태 확인 직후 FCM 토큰을 전송한다.
- `frontend/lib/providers/notification_provider.dart`: 읽음 처리는 PUT 요청이다.
- `frontend/lib/widgets/notice_grade_prompt.dart`: 학년 확인 안내가 별도 위젯에 있다.
- 현재 작업 트리의 변경은 없었다. 제품 코드와 테스트는 수정하거나 실행하지 않았다.

## Review Focus

1. JWT를 붙인 직접 변경 요청, multipart 업로드, 신규 API도 데모 정책에서 기본 거부되어야 한다.
2. 토큰 없이 공개 복구·가입 API에 데모 아이디를 넣어도 계정 상태나 비밀번호가 바뀌거나 메일이 발송되지 않아야 한다.
3. 상세 GET, 로그인·새로고침, 알림 이동에서 자동 저장이 발생하지 않아야 한다.
4. DEMO 조회 허용이 관리자 회원 목록·문의 이미지·기타 개인정보 조회 허용으로 확대되지 않아야 한다.
5. 공유 계정으로 여러 브라우저가 접속해도 로그아웃이 다른 방문자의 세션을 무효화하거나 푸시 토큰을 교체하지 않아야 한다.

## Task 1: 서버 권한 경계와 계정 수명주기

**Files (backend/src/main/java/com/ync/ysync 기준):**
- Modify: `domain/MemberRole.java`, `config/SecurityConfig.java`, `controller/MemberController.java`, `service/MemberSignupService.java`, `service/MemberService.java`
- Create: `config/DemoAccessPolicy.java`, `config/DemoReadOnlyFilter.java`, `config/DemoAccountInitializer.java`
- Modify: `backend/src/main/resources/application.properties`
- Create tests: `backend/src/test/java/com/ync/ysync/config/DemoAccessPolicyTest.java`, `DemoAccountInitializerTest.java`, `DemoAccessIntegrationTest.java`
- 필요 시 Create: `docs/deployment/demo-account.md` (발급·비활성화·역할 컬럼 확인 절차)

**Interfaces:**
- `DemoAccessPolicy.isDemo(Authentication authentication): boolean`: `ROLE_DEMO` 확인.
- `DemoAccessPolicy.isAllowed(String method, String servletPath): boolean`: 정확한 HTTP 메서드와 경로의 허용 목록. 읽기 GET/HEAD와 성공 응답만 반환하는 `/api/v1/auth/logout`만 포함하고 나머지는 거부한다.
- `DemoReadOnlyFilter extends OncePerRequestFilter`: JWT 인증 뒤 실행, 거부 시 HTTP 403 + JSON `{code: "DEMO_READ_ONLY", message: "데모 계정에서는 변경할 수 없습니다."}`. 로그인은 인증 성립 전 기존 경로를 사용한다.
- `DemoAccountInitializer implements CommandLineRunner`: `ysync.demo.enabled`, `ysync.demo.login-id`, `ysync.demo.password` 설정. 활성화 때 필수 값 누락·기존 일반 회원과 충돌하면 실패. 없는 데모 회원만 생성한다.
- DEMO 역할은 기존 JWT 생성 및 `/members/me`의 role 응답을 그대로 통해 프런트에 전달한다.

- [ ] 변경 메서드 POST/PUT/PATCH/DELETE, multipart, 알려지지 않은 GET, `/admin/**` 거부와 승인된 GET/HEAD, 로그아웃 허용 정책 테스트를 먼저 작성한다. GET/HEAD 패턴은 실제 컨트롤러 기준으로 명시하고 포괄적인 `/**` 허용은 사용하지 않는다.
- [ ] MockMvc로 데모 JWT 로그인 → 본인 조회·공지·커뮤니티·댓글·일정·시간표·스크랩·알림 조회 성공을 확인하는 테스트를 작성한다. 정상 회원 변경 성공, 관리자 권한 유지, 데모 변경 403도 확인한다.
- [ ] 공개 가입·복구 경로에서 데모 회원을 대상으로 한 요청은 기존 계정 존재 여부 보호 응답 규칙을 유지하면서 변경/메일 발송을 하지 않는 테스트를 작성한다. 단순 인증 필터만으로 보호되지 않는 경로다.
- [ ] 비활성 설정이면 생성 안 함, 활성화 시 BCrypt 검증, 활성화 회원 생성, 재실행 중복 생성 안 함, 기존 일반 회원 덮어쓰기 안 함을 테스트한다. 데모 서비스 로그인은 설정 비활성화 시 거부하고, 기존 JWT 요청도 정책에서 거부한다.
- [ ] 위 인터페이스와 역할을 구현한다. 필터는 Spring Security 체인에만 등록하여 서블릿 필터로 중복 실행되지 않도록 한다. 모든 `/api/v1/auth/**`를 데모 예외로 열지 않는다.
- [ ] 검증: `cd backend && ./gradlew test --tests '*DemoAccessPolicyTest' --tests '*DemoAccountInitializerTest' --tests '*DemoAccessIntegrationTest' --tests '*MemberEnumerationTest' --tests '*MemberAccountRecoveryTest' --tests '*MemberAdminSecurityTest'`. 신규 테스트를 구현 전에 실행하여 예상 실패, 구현 후 PASS를 확인한다.

## Task 2: 조회 과정의 자동 변경 제거

**Files (backend/src/main/java/com/ync/ysync 기준):**
- Modify: `controller/NoticeController.java`, `controller/CommunityController.java`, `service/NoticeService.java`, `service/CommunityService.java`, `service/NoticeGradeService.java`
- Modify: `controller/MemberController.java` (데모 로그아웃)
- Create tests: `backend/src/test/java/com/ync/ysync/service/DemoReadSideEffectsTest.java`

**Interfaces:**
- `NoticeService.getNotice(Long id, boolean increaseViewCount): Notice`, `CommunityService.getPost(Long id, boolean increaseViewCount): CommunityPost` 추가. 기존 단일 인자 메서드는 `true`로 위임하여 호출자와 기존 조회수 동작을 유지한다.
- 컨트롤러는 Task 1의 `isDemo`로 데모이면 `false`를 전달한다.
- `NoticeGradeService.confirmationRequired(Member member, int currentAcademicYear): boolean`: DEMO이면 false.
- `/auth/logout`: DEMO이면 회원 저장·FCM 제거·authVersion 변경 없이 기존 성공 응답.

- [ ] 데모 상세 조회 전후 DB 조회수 동일, 일반 사용자 조회는 증가, 없는 글의 기존 오류 동작 유지 테스트를 작성한다.
- [ ] DEMO 학년 확인 요구 false, 기존 일반 회원 요구 로직 유지 테스트를 작성한다.
- [ ] 서로 다른 두 데모 JWT 중 하나가 로그아웃해도 다른 JWT로 조회가 성공하고 회원 상태가 동일한 통합 테스트를 Task 1의 통합 테스트에 추가한다.
- [ ] 자동 UPDATE를 생략하는 분기와 로그아웃 성공 응답을 구현한다. 허용된 다른 GET도 서비스까지 따라가 쓰기 부작용이 있는지 확인하고 발견된 항목은 동일한 원칙으로 차단한다.
- [ ] 검증: `cd backend && ./gradlew test --tests '*DemoReadSideEffectsTest' --tests '*DemoAccessIntegrationTest' --tests '*ViewCountConcurrencyTest' --tests '*NoticeGradeServiceTest'` → PASS.

## Task 3: Flutter 읽기 전용 안내와 화면 동작

**Files:**
- Modify: `frontend/lib/models/member.dart`, `frontend/lib/providers/auth_provider.dart`, `frontend/lib/providers/notification_provider.dart`, `frontend/lib/widgets/notice_grade_prompt.dart`
- Create: `frontend/lib/providers/demo_access_provider.dart`, `frontend/test/demo_read_only_test.dart`
- Modify: `frontend/lib/screens/main_tab_screen.dart`, `community_list_screen.dart`, `community_detail_screen.dart`, `community_form_screen.dart`, `notice_detail_screen.dart`, `notice_form_screen.dart`, `profile_screen.dart`, `notification_settings_screen.dart`, `auth_settings_screen.dart`, `notification_center_screen.dart`, `timetable_view.dart`, `academic_calendar_view.dart`, `help_screen.dart` 중 실제 변경 액션이 있는 파일만.
- Modify: 변경 폼이 라우트로 직접 열리는 경우 해당 폼의 제출 경로. 나머지 화면은 동작 목록을 확인한 뒤 필요한 곳에만 적용한다.

**Interfaces:**
- `Member.isDemo: bool` getter는 `role == 'DEMO'`.
- `isDemoAccountProvider: Provider<bool>`은 현재 인증 회원의 `isDemo`를 제공한다. `dioProvider`가 `authProvider`를 역참조하지 않도록 한다.
- 안내 문구: `데모 계정입니다. 조회만 가능합니다.` / 변경 안내: `데모 계정에서는 변경할 수 없습니다.`

- [ ] DEMO 로그인 후 목록·검색·상세 이동 가능, 작성/수정/삭제/스크랩/신고/문의/설정 저장은 요청 없이 비활성 또는 안내, 일반 회원 동작 유지 위젯 테스트를 작성한다. 일부 변경 버튼이 숨겨지더라도 서버 검증은 유지한다.
- [ ] 인증 복원 및 로그인 직후 FCM 등록 요청이 없는지 테스트한다. 회원 파싱을 FCM 등록 전에 수행하여 역할을 판단한다.
- [ ] 알림 클릭은 대상 상세로 이동하지만 읽음 PUT은 보내지 않는지 테스트한다. 데모는 읽음 로컬 변경도 생략하여 서버 상태와 동일하게 유지한다.
- [ ] 학년 확인 팝업과 PIN 설정 등 저장 안내를 데모에서 생략하고, 로그아웃은 로컬 토큰·세션 캐시를 정리하는지 테스트한다.
- [ ] 모델 getter·provider와 UI 제한을 구현한다. 변경 폼 직접 진입도 차단한다. HTTP 403 `DEMO_READ_ONLY`는 세션 만료로 취급하지 않는다.
- [ ] 검증: `cd frontend && flutter test test/demo_read_only_test.dart test/auth_flow_design_test.dart test/session_cache_test.dart test/notice_grade_test.dart` → PASS, `flutter analyze` → 새 오류 없음.

## Task 4: 통합 확인 및 공개 준비

- [ ] API 허용 목록과 화면 동작 목록을 대조하여 놓친 변경 경로, 읽기 경로의 개인정보 및 부작용을 확인한다.
- [ ] 영향이 인증·중앙 필터까지 있으므로 최종에 `cd backend && ./gradlew test`, `cd frontend && flutter test`를 한 번씩 실행한다. 기존 실패는 구분하여 기록한다.
- [ ] 로컬 또는 시연 환경에서 로그인 → 검색 → 상세 → 알림 이동 → 새로고침 → 로그아웃을 수동 확인한다. 변경 요청 403과 DB 업무 데이터 불변을 확인한다.
- [ ] MySQL 역할 컬럼과 계정 충돌을 확인하고 필요한 DDL·환경 변수·데모 비활성화 절차를 배포 문서에 기록한다. 비밀번호는 코드/로그/문서에 실제 값으로 넣지 않는다.
- [ ] 공개할 데이터 범위와 배포 대상을 사용자와 확정한다. 샘플 환경 준비가 추가로 필요하면 그 범위와 작업량을 별도로 정한다.
- [ ] 구현 및 검증 결과를 검토받은 다음 실제 계정 발급·배포를 진행한다. 이 계획 작성 단계에서는 발급·배포하지 않는다.

## 완료 기준 및 예상 작업량

- 실제 데모 자격 증명으로 로그인·조회가 가능하고, 직접 API 요청을 포함한 모든 데모 변경이 차단된다.
- 자동 변경 부작용이 없으며 기존 회원·관리자 동작은 회귀 테스트를 통과한다.
- 공개 데이터와 데모 중단 방법이 확인되어 있다.
- 현재 확인한 코드 기준 최소 구현·검증은 **반나절~하루**를 작업 범위로 잡는다. 앞서 제시한 1~2시간은 중앙 차단과 UI 일부만 고려한 대략치였으며, 공개 복구 API·조회수·푸시·다수 변경 화면 검증을 포함하면 부족할 수 있다. 별도 시연 환경과 샘플 데이터 구축은 이 예상에 포함하지 않는다.

## 실행 결과 (2026-10-06)

- Task 1~3: 구현 및 회귀 검증 완료. 조회 부작용과 계정 초기화 검증은 `DemoAccessIntegrationTest`에 통합했다.
- Task 4: 백엔드 전체 테스트 155개, Flutter 전체 테스트 98개 통과. 정적 분석과 웹 배포 빌드 검증 완료 후 최종 결과를 보고한다.
- 코드 리뷰의 시드 아이디 충돌 문제를 회귀 테스트로 재현하고 코드에서 4개 예약 아이디를 거부하도록 수정했다.
- 기존 회원가입의 비밀번호/인증 증표 검증 순서를 보존했다. 시작 화면에서 데모 여부 조회가 실패하는 경우도 기존 인증 흐름을 유지한다.
- 운영 DB 역할 컬럼 확인, 공개 데이터 범위 확정, 실제 환경 계정 활성화 및 수동 로그인 확인은 배포 환경 선택 후 진행한다.
- 사용자가 운영 적용을 승인했으며 아이디 `0000000`, 이름 `임시`로 배포한다. 비밀번호는 production Secret으로 관리한다. 코드 커밋은 `169d85a`이며 배포 결과는 작업 이력에 기록한다.
