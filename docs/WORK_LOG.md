# Y-Sync 작업 이력

이 문서는 기능 개발, 버그 수정, 운영 설정 변경, 배포 및 장애 대응 이력을 육하원칙으로 기록하는 작업 원장입니다. 최신 작업을 위에 추가하며 비밀번호, 토큰, 개인키, 서비스 계정 원문과 개인정보는 기록하지 않습니다.

---

## 2026-09-21 - 학년별 공지 알림 필터 운영 전환

- 누가: 백엔드·운영 설정
- 무엇을: 운영의 `NOTICE_GRADE_FILTER_ENABLED`를 GitHub Repository Variable에서 배포 워크플로와 Docker Compose를 거쳐 백엔드 컨테이너로 전달하도록 연결하고 값을 `true`로 설정했습니다.
- 왜: 학생 대상 링크 배포 전부터 학년 선택 정책을 적용해야 출시 후 미설정 사용자의 수신 범위가 갑자기 바뀌는 전환 문제를 피할 수 있기 때문입니다.
- 어떻게:
  - Production Deploy가 Repository Variable을 SSH 배포 환경으로 전달합니다.
  - Docker Compose가 값을 백엔드 환경변수로 주입하며, 변수가 없으면 기존 안전 기본값 `false`를 사용합니다.
  - CI Configuration job이 `true`가 Compose 결과에 나타나는지, 배포 워크플로가 변수를 선언하고 전달하는지 검사합니다.
  - 전환 직전 운영 집계는 활성·공지 알림 대상 9명, 학년 미설정 8명, 3학년 선택 1명입니다. 미설정 회원은 전환 후 전체 공지만 받습니다.
- 언제·어디서: 2026-09-21, `chore/enable-notice-grade-filter` 브랜치, [PR #127](https://github.com/JinsuBae2/y-sync/pull/127).
- 검증: 연결 전 구성 검사가 의도대로 실패하는 것을 확인한 뒤, `unset`·`false`는 `false`, `true`는 `true`로 렌더링되는지와 정확한 GitHub Variable 원본·SSH 전달 목록을 CI로 고정했습니다. 변수 원본을 일부러 오타 내면 검사가 실패하는 것도 확인했습니다. 기준선에서 백엔드 전체 테스트, Flutter 78개 테스트와 Compose 구성이 통과했습니다.
- 롤백: Repository Variable을 `false`로 바꾸고 백엔드를 재배포하면 저장된 학년 선택을 유지한 채 기존 전체 대상 발송으로 복구됩니다.

---

## 2026-09-21 - MemberService 925줄을 다섯 갈래로 분할

- 누가: 백엔드
- 무엇을: 한 클래스가 들고 있던 가입·인증·명단 업로드·관리자 조작·로그인을 책임별로 나눴습니다. 동작은 바꾸지 않았습니다.
- 왜:
  - **길이보다 권한 경계가 문제였습니다.** 가입·로그인과 관리자 조작이 한 클래스에 있으니 `AdminMemberController`가 `signup()`을, `MemberProfileController`가 `suspendMember()`를 부를 수 있는 상태였습니다. 실수로 그렇게 써도 컴파일이 통과합니다.
  - 인증 상태(인메모리 맵 3개)가 회원 조회·비밀번호 로직과 섞여 있어, `compute`로 보장하는 원자성이 어디까지인지 읽어내기 어려웠습니다.
  - CSV·Excel 파싱 200여 줄은 회원 도메인과 무관한 코드인데 같은 파일에 있어 어느 쪽을 고치든 나머지를 함께 읽어야 했습니다.
- 어떻게:

| 클래스 | 책임 | 줄 수 |
|---|---|---|
| `MemberVerificationService` | 인증번호·가입 증표 발급과 검증 (인메모리 상태) | 273 |
| `MemberSpreadsheetImportService` | 학생 명단 CSV·Excel 일괄 등록 | 278 |
| `MemberSignupService` | 가입과 비밀번호 재설정 흐름 | 215 |
| `MemberAdminService` | 관리자 전용 회원 관리 | 210 |
| `MemberService` | 로그인·조회·개인 설정 | 92 |
| `MemberRolePolicy` | 권한 부여 규칙 (단건 등록과 명단 등록이 공유) | 21 |

  - 나누는 기준은 줄 수가 아니라 **누가 부르는가**였습니다. 컨트롤러 셋이 각각 필요한 것만 주입받습니다.
  - `MemberVerificationService`는 내부 값 타입(`VerificationInfo`·`VerifiedInfo`)을 밖으로 내보내지 않습니다. 호출자는 "인증된 이메일" 문자열만 돌려받습니다. 맵을 건드리는 코드가 한 파일 안에 모두 있습니다.
  - 권한 부여 규칙은 `MemberRolePolicy`로 뽑았습니다. 한 쪽에만 두면 다른 경로로 우회할 수 있고, 실제로 명단 업로드는 권한 열을 받으므로 여기서 막지 않으면 CSV 한 줄로 SUPER_ADMIN을 만들 수 있습니다.
  - 관리자 계정 초기화가 진행 중이던 인증을 지우던 부분은 `MemberVerificationService.clear()`로 옮겼습니다. 재발급 쿨다운까지 함께 지우는 동작은 그대로입니다.
  - 기존 단위 테스트 6개는 이제 각자 필요한 서비스만 만들어 씁니다. 인증 상태를 실제로 확인하는 테스트는 `MemberVerificationService` 실제 구현을 공유 인스턴스로 주입해, 모의 객체로는 볼 수 없는 "초기화가 인증을 지우는지"를 계속 검증합니다.
- 언제·어디서: 2026-09-21, `refactor/member-service` 브랜치.
- 검증: 백엔드 테스트 전체 통과, 컴파일 경고 0건. 순수 이동이라 새 회귀 테스트는 추가하지 않았고, 기존 테스트가 분할 후에도 같은 동작을 고정하는지로 확인했습니다. Spring 컨텍스트 기동(`@SpringBootTest`)으로 새 빈 배선도 함께 확인됩니다.
- 남은 일: 커스텀 예외 도입은 별도입니다. 지금은 모든 실패가 `IllegalArgumentException`이라 400과 404, 409를 구분하지 못합니다.

---

## 2026-09-21 - 공지 커서 기반 무한 스크롤

- 누가: 백엔드·프론트엔드 공통 작업
- 무엇을: 공지 목록을 커서 페이징 무한 스크롤로 바꾸고, 스크롤 도중 새 공지가 올라오면 알리는 칩을 붙였습니다.
- 왜:
  - `noticesProvider`가 `/notices`를 페이지 지정 없이 불러 Spring 기본값인 20건만 받았고, 화면에 더 보는 수단이 없었습니다. **21번째 공지부터는 DB에 있어도 학생이 도달할 수 없었습니다.** 운영 공지는 이미 20건을 넘긴 상태였습니다.
  - offset 페이징은 스크롤 도중 새 공지가 올라오면 목록이 한 칸씩 밀려 같은 글을 두 번 보거나 건너뜁니다.
- 어떻게:
  - `GET /notices/feed` — `(createdAt, id)` 복합 커서. `createdAt`은 UNIQUE가 아니라 같은 시각에 두 건이 등록되면 id 없이는 커서가 행을 건너뛰거나 중복시킵니다. 커서는 Base64URL로 감싸 불투명하게 내보냅니다.
  - **고정 공지는 커서에서 분리**해 첫 페이지에만 내려줍니다. 정렬이 `isPinned DESC, createdAt DESC`라 고정 공지는 날짜와 무관하게 위로 뜨는데, 커서 하나로 묶으면 고정/일반 경계에서 페이지가 어긋납니다. 분리하면 스크롤 도중 고정 공지가 목록 중간에 끼어들지도 않습니다.
  - `size + 1`을 조회해 `hasNext`를 판정합니다. 별도 COUNT 쿼리를 돌리지 않습니다. 기본 10건, 상한 30건.
  - **학년 필터를 서버로 옮겼습니다.** 클라이언트 필터는 무한 스크롤과 양립하지 않습니다 — 10건 받아 거르면 0건이 남을 수 있고, 그게 "끝"인지 "이 페이지에 없음"인지 구분할 수 없습니다. 의미는 기존과 같습니다(`targetGrade IN ('ALL', :grade)`).
  - `GET /notices/feed-updates` — 클라이언트가 들고 있는 `latestId` 이후 공지 수만 셉니다. 고정 여부는 따지지 않습니다. 스크롤 중 올라온 고정 공지도 사용자에겐 새 공지입니다. 상한 99.
  - 칩은 **새 공지가 있고 스크롤을 내려둔 상태**일 때만 띄웁니다. 최상단에서도 목록에 자동 삽입하지 않습니다. 읽는 중에 목록이 튀면 보던 자리를 잃습니다.
  - 기존 `GET /notices`(Page)와 `/notices/search`는 그대로 뒀습니다. 홈 화면이 쓰고 있고 캐시된 구버전 PWA도 있습니다.
- 작업 중 고친 것:
  - 스크롤 리스너에서 `setState`를 부르던 부분을 `ValueNotifier`로 바꿨습니다. 스크롤 한 틱마다 화면 전체가 다시 그려지고 있었습니다. 위젯 테스트가 멈춘 게 이 증상을 드러냈습니다.
  - 새 공지 폴링 주기를 위젯 파라미터로 뺐습니다. `Timer.periodic`이 살아 있으면 `pumpAndSettle`이 가상 시간을 진행하다 타이머를 깨우고, 상태가 바뀌어 다시 프레임이 잡히는 일이 반복돼 테스트가 안정되지 않습니다.
- 운영 DDL: 배포 전에 적용합니다.

```sql
ALTER TABLE notice ADD INDEX idx_notice_feed (is_pinned, created_at, id);
```

  **Hibernate `validate`는 인덱스를 검증하지 않습니다.** 적용하지 않아도 기동은 성공하고 커서 조회만 풀스캔이 됩니다. UNIQUE 제약 때와 달리 순서 사고로 배포가 실패하지는 않지만, 그래서 오히려 놓치기 쉽습니다.

- 언제·어디서: 2026-09-21, `feat/notice-cursor-feed` 브랜치. 계획서는 `docs/NOTICE_FEED_PLAN.md`.
- 검증: 백엔드 테스트 전체 통과(피드 9건 추가), Flutter 84개 통과(피드 6건 추가), 분석 경고 0건, 웹 릴리스 빌드 성공. 같은 `createdAt`을 가진 공지 5건을 강제로 만들어 커서가 행을 건너뛰지 않는지, 학년 필터가 기존 클라이언트 필터와 같은 결과를 내는지 확인했습니다.
- 남은 일: 검색(`keyword`)은 `LIKE %kw%`라 이 인덱스를 타지 못합니다. 공지 건수가 적어 지금은 수용하고, 커지면 전문 검색을 별도로 검토합니다. 커뮤니티 목록은 아직 전체를 한 번에 내려줍니다.

---

## 2026-09-21 - Flutter 3.41.4 → 3.47.5 업그레이드

- 누가: 프론트엔드
- 무엇을: Flutter SDK를 3.41.4(2026-03)에서 3.47.5(2026-09-18, 현재 최신 stable)로 올리고, 새 버전이 잡아낸 UI 결함 6건을 고쳤습니다.
- 왜: 반년 가까이 묵은 버전이라 `flutter_riverpod` 등 의존성 Dependabot PR이 최신 버전을 해석하지 못하고 계속 실패하고 있었습니다.
- 어떻게:
  - 로컬 SDK를 올리고, CI(`ci.yml`)와 배포(`deploy-production.yml`)의 `flutter-version` 핀을 `3.47.5`로 맞췄습니다. 두 곳 모두 바꿔야 로컬과 CI가 갈라지지 않습니다.
  - `pubspec.yaml`의 Dart SDK 제약을 `^3.11.1`에서 `^3.13.4`로 올렸습니다. `pubspec.lock`은 SDK가 고정하는 패키지들이 패치·마이너 단위로 7개 갱신됐습니다(major 변경 없음).
  - **Flutter 3.47이 새로 잡는 assertion 때문에 테스트 3건이 깨졌습니다.** 원인은 하나였습니다.
    > `ListTile background color or ink splashes may be invisible.`
    `ListTile`은 가장 가까운 `Material`에 배경과 잉크를 그리는데, 그 사이에 배경색을 가진 `DecoratedBox`(= `Container(decoration:)`)가 끼면 탭 잉크가 가려집니다. **실제 UI 결함이고**, 지금까지는 조용히 잘못 그려지고 있었습니다.
  - 해당 지점 6곳을 고쳤습니다. 배경을 `Container`가 아니라 `Material`이 그리도록 바꾸는 방식입니다.
    - 단순한 4곳(`academic_calendar_view`, `auth_settings_screen`, `notification_settings_screen`의 `_SettingGroup`, `help_screen`의 FAQ 묶음)은 `Card(elevation: 0, shape: RoundedRectangleBorder(...))`로 바꿨습니다. `admin_feedback_screen`과 `admin_post_management_screen`이 이미 쓰던 방식이라 저장소 관례를 따랐습니다.
    - 커스텀 그림자가 있는 2곳(`notice_form_screen`, `community_form_screen`의 `SwitchListTile`)은 `Card`로 옮기면 그림자 모양이 달라지므로, 그림자는 `Container`에 두고 배경색·테두리만 `Material`로 옮겼습니다. 겹치는 순서가 같아 보이는 결과는 동일합니다.
    - 모두 `clipBehavior: Clip.antiAlias`를 넣어 둥근 모서리 밖으로 잉크가 새지 않게 했습니다.
  - `flutter pub get`이 `analysis_options.yaml`에 `analyzer.exclude`(build·android·ios·web)를 자동 추가했습니다. 새 프로젝트 템플릿의 기본값이고, 해당 경로에는 서드파티 빌드 산출물 외에 우리 Dart 코드가 없어 그대로 뒀습니다.
- 언제·어디서: 2026-09-21, `chore/flutter-3-47-5` 브랜치.
- 검증:
  - `flutter analyze` 경고 0건, Flutter 테스트 78개 통과, JavaScript 테스트 6개 통과.
  - `flutter build web --release` 성공.
  - **CSP 재확인.** 빌드 산출물을 운영과 같은 CSP 헤더로 로컬 서빙해 브라우저로 직접 띄웠습니다. 앱이 정상 부팅하고 Firebase 초기화까지 통과했으며 **CSP 위반 0건**입니다(콘솔의 CORS 오류는 localhost에서 운영 API를 부른 탓이라 무관). `index.html`에 인라인 스크립트가 없고 외부 출처도 `www.gstatic.com` 하나라 기존 CSP로 충분합니다.
- 남은 일: 막혀 있던 의존성 Dependabot PR들이 이제 해석될 수 있습니다. `flutter pub outdated` 기준 30개가 제약 밖에 있는데, 이건 SDK 업그레이드와 분리해서 따로 봅니다.

---

## 2026-09-21 - `ddl-auto`를 validate로 전환

- 누가: 백엔드·운영 DB
- 무엇을: 운영 프로파일의 `spring.jpa.hibernate.ddl-auto`를 `update`에서 `validate`로 바꿨습니다.
- 왜: `update`는 Hibernate가 기동할 때마다 운영 스키마를 자동으로 바꾼다는 뜻입니다. 코드 한 줄이 배포와 함께 운영 DB 구조를 조용히 변경할 수 있었습니다. `docs/TROUBLESHOOTING.md` 4번의 `NoticeType` ENUM 장애가 이 계열의 사고입니다.
- 어떻게:
  - 운영 스키마를 `mysqldump --no-data --skip-comments --no-tablespaces`로 덤프해 로컬 MySQL 8.0 컨테이너(포트 3307)에 올렸습니다. 데이터는 넣지 않았고 운영 DB는 읽기만 했습니다.
  - 그 복제본을 향해 `SPRING_PROFILES_ACTIVE=prod`, `SPRING_JPA_HIBERNATE_DDL_AUTO=validate`로 기동했습니다.
  - **불일치 0건으로 정상 기동했습니다.** `update`로 오래 운영됐지만 엔티티와 어긋난 컬럼·타입·인덱스가 없었습니다. 수동 DDL이 필요 없었습니다.
  - 검증 장치 자체가 동작하는지 확인했습니다. 복제본에서 `member.withdrawn_at`을 일부러 지우고 다시 기동해 `SchemaManagementException: missing column [withdrawn_at] in table [member]`로 실패하는 것을 본 뒤, 컬럼을 복구하고 다시 정상 기동을 확인했습니다. 이 확인이 없으면 "그냥 떴다"가 "validate가 적용되지 않았다"와 구분되지 않습니다.
  - `application-prod.properties`의 주석을 전환 이후 기준으로 고쳤습니다. 이제 엔티티를 바꾸면 운영 DDL을 먼저 적용해야 하고, 순서가 뒤집히면 배포가 기동 실패로 끝난다는 점을 적었습니다.
  - `docs/DDL_AUTO_MIGRATION.md`는 "전환 절차"에서 "엔티티 변경 시 영향을 미리 확인하는 절차"로 용도를 바꿔 기록했습니다.
  - 복제 컨테이너는 확인 후 제거했습니다.
- 언제·어디서: 2026-09-21, `chore/ddl-auto-validate` 브랜치.
- 검증: 복제 환경에서 `validate` 정상 기동, 일부러 만든 불일치가 기동을 실패시키는 것까지 확인. 백엔드 테스트 전체 통과.
- 남은 일: 스키마 변경 수단이 없어졌으므로 **Flyway 또는 Liquibase 도입**을 검토합니다. 현재 스키마를 baseline으로 잡고 이후 변경만 마이그레이션으로 관리하는 방식이 전환 비용이 가장 낮습니다. 그전까지는 엔티티를 바꿀 때마다 `docs/DDL_AUTO_MIGRATION.md` 3~4단계로 영향을 먼저 확인합니다.

---

## 2026-09-21 - 스크랩·신고 중복행 차단 (UNIQUE 제약)

- 누가: 백엔드·운영 DB 공통 작업
- 무엇을: `scrap`과 `report`에 UNIQUE 제약을 추가하고, 중복키 위반이 500이 아닌 정상 응답으로 처리되게 했습니다.
- 왜:
  - 두 서비스 모두 "조회 후 INSERT" 구조라 같은 요청이 동시에 들어오면 애플리케이션 검사를 둘 다 통과해 중복행이 생깁니다.
  - 스크랩은 중복행이 한 번 생기면 `findByMemberIdAndTargetTypeAndTargetId`가 `IncorrectResultSizeDataAccessException`으로 깨져 **그 사용자는 해당 글의 스크랩 토글에서 영구히 500을 받습니다.**
  - 신고는 한 사람의 신고가 여러 건으로 세어져, 자동 블라인드 임계(5회)가 실제 5명보다 적은 인원으로 도달합니다.
  - 제약 추가 전에 운영 DB에 중복행이 있으면 DDL 자체가 실패하므로 확인이 선행 조건이었습니다.
- 어떻게:
  - 운영 MySQL에서 중복행을 먼저 조회했습니다. `scrap` 0건, `report` 0건이라 정리 없이 제약을 추가할 수 있었습니다.
  - `report`의 사용자 식별 컬럼은 `member_id`가 아니라 **`reporter_id`** 입니다. 확인 쿼리를 이 컬럼으로 실행했습니다.
  - 엔티티에 `@Table(uniqueConstraints = ...)`를 선언했습니다. `uq_scrap(member_id, target_type, target_id)`, `uq_report(reporter_id, target_type, target_id)`.
  - 스크랩 **해제**는 조건부 DELETE 한 문장으로 바꿨습니다. 엔티티를 조회해서 지우면 같은 해제 요청이 동시에 들어왔을 때(버튼 연타) 한쪽이 `ObjectOptimisticLockingFailureException`("expected row count 1 but was 0")으로 500을 받습니다. "0행 삭제"는 오류가 아니므로 이 방식은 경쟁에서 져도 실패하지 않습니다. 동시성 테스트를 CI에서 돌리다 실제로 발견해 함께 고쳤습니다.
  - 중복키 예외는 트랜잭션 경계 **밖**인 컨트롤러에서 잡습니다. 서비스 안에서 잡으면 이미 롤백 표시된 트랜잭션을 커밋하려다 `UnexpectedRollbackException`이 납니다.
    - 스크랩: 경쟁에서 진 요청도 "스크랩됨"이라는 결과는 달성됐으므로 200으로 응답합니다.
    - 신고: 사전 검사와 같은 "이미 신고한 대상입니다." 400으로 응답합니다.
  - `GlobalExceptionHandler`에 `DataIntegrityViolationException` 핸들러를 마지막 방어선으로 추가했습니다(409). 제약 위반은 서버 결함이 아니라 데이터 상태이므로 500으로 내보내지 않습니다.
- 운영 DDL: **2026-09-21 운영 DB에 적용 완료했습니다.** 배포보다 먼저 적용한 이유는, `ddl-auto=update`라 그냥 배포해도 Hibernate가 같은 인덱스를 만들지만 그 시점에 중복행이 있으면 **배포 중 앱이 기동에 실패**하기 때문입니다. 미리 적용하면 실패해도 SQL 오류 한 줄로 끝납니다. 적용 전 중복행 재확인은 둘 다 0건, `ALTER` 두 건 모두 `Query OK, 0 rows affected`였습니다. 서비스는 중단하지 않았습니다(MySQL 8은 보조 인덱스 추가를 INPLACE로 처리합니다).

```sql
-- 적용 직전 재확인 (둘 다 0행이어야 합니다)
SELECT member_id, target_type, target_id, COUNT(*) c
FROM scrap GROUP BY member_id, target_type, target_id HAVING c > 1;
SELECT reporter_id, target_type, target_id, COUNT(*) c
FROM report GROUP BY reporter_id, target_type, target_id HAVING c > 1;

ALTER TABLE scrap  ADD CONSTRAINT uq_scrap  UNIQUE (member_id, target_type, target_id);
ALTER TABLE report ADD CONSTRAINT uq_report UNIQUE (reporter_id, target_type, target_id);
```

- 언제·어디서: 2026-09-21, `fix/scrap-report-unique` 브랜치.
- 검증: 백엔드 테스트 통과. 동시성 테스트는 10회 반복 실행해 흔들리지 않는 것을 확인했습니다. 같은 회원·대상으로 두 번째 행을 저장하면 `DataIntegrityViolationException`이 나는지, 8개 스레드가 동시에 토글·신고해도 스크랩 행이 2건 이상으로 늘지 않고 신고가 정확히 1건만 적재되는지 실제 커밋으로 확인했습니다. 중복행이 있을 때만 나는 `IncorrectResultSizeDataAccessException`이 한 건도 발생하지 않는 것도 함께 고정했습니다.
- 남은 일: `ddl-auto`를 `validate`로 전환하는 작업은 별도입니다. 전환 시 이 두 제약이 스키마에 실제로 존재해야 기동에 실패하지 않습니다.

---

## 2026-09-21 - 댓글 달린 글이 삭제되지 않던 문제 (하드 삭제 FK)

- 누가: 백엔드
- 무엇을: 글을 하드 삭제하기 전에 딸린 댓글·신고·스크랩을 정리하도록 바꿨습니다.
- 왜:
  - 운영 DB의 외래키 제약 14개를 조회해 `comment.community_post_id`와 `comment.notice_id`에 FK가 실제로 존재하는 것을 확인했습니다.
  - `CommunityService.deletePost`와 `NoticeService.deleteNotice`는 딸린 댓글을 지우지 않고 글만 지우려 했습니다. **댓글이 하나라도 달린 글은 작성자든 관리자든 삭제할 수 없었고**, 제약 위반이 500으로 나갔습니다. 이미지는 엔티티 cascade가 처리하고 있어 댓글만 사각지대였습니다.
  - `scrap.target_id`와 `report.target_id`에는 FK가 없습니다. 삭제를 막지는 않지만 남으면 관리자 신고함에 "존재하지 않는 게시글" 항목이 계속 쌓이고 스크랩 목록에 빈 자리가 생깁니다.
- 어떻게:
  - 정리 책임을 `PostDeletionCleaner`로 분리했습니다. 커뮤니티 글과 공지가 같은 문제를 갖고 있어 두 서비스에 같은 코드를 넣지 않기 위해서입니다.
  - 댓글은 **대댓글을 먼저, 원 댓글을 나중에** 지웁니다. `comment.parent_id`가 comment 자신을 참조하기 때문입니다. `CommentService.validateReplyableParent`가 대댓글에 답글을 막고 있어 깊이는 2단계입니다.
  - 댓글을 가리키던 신고는 댓글 ID를 먼저 모아 한 번에 지웁니다.
  - 정리는 `@Transactional(propagation = MANDATORY)`로 호출한 삭제 트랜잭션 안에서만 실행됩니다. 정리만 커밋되고 글 삭제가 실패하면 댓글만 사라진 글이 남기 때문입니다.
  - 알림(`notification`)은 정리하지 않았습니다. 이미 발송된 수신 기록이라 지우면 사용자 이력이 사라집니다.
- 언제·어디서: 2026-09-21, `fix/hard-delete-orphans` 브랜치.
- 검증: 백엔드 테스트 전체 통과. 정리 호출을 일부러 주석 처리해 추가한 테스트 3건이 실제로 `ConstraintViolationException`으로 실패하는 것을 확인한 뒤 원복했습니다. 실제 DELETE가 DB까지 도달해야 FK 위반을 볼 수 있으므로 테스트 클래스에 `@Transactional`을 걸지 않았습니다.
- 남은 일: `MemberService.deleteMemberByAdmin`도 같은 계열의 문제를 갖고 있습니다. `member`를 참조하는 FK가 8개(admin_request, comment, community_post, notice, notification, personal_timetable_entry, report, scrap)라 글이나 댓글을 쓴 적 있는 회원은 삭제할 수 없습니다. 다만 해결 방향이 "딸린 글까지 함께 삭제"인지 "계정만 익명화"인지는 서비스 정책 판단이 필요해 이 브랜치에는 넣지 않았고, 같은 날 "계정만 익명화"로 정해 아래 항목에서 처리했습니다.

---

## 2026-09-21 - 관리자 회원 삭제를 계정 익명화로 전환

- 누가: 백엔드·프론트엔드 공통 작업
- 무엇을: `DELETE /admin/members/{id}`가 회원 행을 지우는 대신 계정을 익명화하도록 바꿨습니다.
- 왜:
  - 운영 DB 조회 결과 `member`를 참조하는 외래키가 8개였습니다(admin_request, comment, community_post, notice, notification, personal_timetable_entry, report, scrap).
  - 기존 구현은 회원 행을 그대로 지웠기 때문에 **글이나 댓글을 쓴 적 있는 회원은 관리자도 삭제할 수 없었고** 500이 났습니다.
  - 딸린 데이터까지 함께 지우는 방식은 택하지 않았습니다. 그 회원의 글에 달린 **다른 학생의 댓글까지 사라지고** 대화 맥락이 끊깁니다.
- 어떻게:
  - `Member.withdraw(...)`가 개인을 특정할 수 있는 값을 모두 지웁니다. 학번, 이메일, 이름, 소셜 ID, FCM 토큰, 알림 설정, 권한입니다.
  - `loginId`는 NOT NULL·UNIQUE라 비울 수 없어 `withdrawn-{id}`로 바꿉니다. 학번이 풀리므로 같은 학생을 다시 사전 등록할 수 있습니다.
  - 다시 로그인할 수 없도록 비밀번호를 어떤 입력과도 일치하지 않는 값으로 바꾸고, `isActivated=false`, `authVersion`을 올려 이미 발급된 JWT를 무효화합니다.
  - 본인만 보는 데이터는 함께 지웁니다. 수신 알림, 스크랩, 개인 시간표, 권한 신청 이력입니다.
  - 신고 이력은 남깁니다. 신고자 식별 정보가 이미 지워졌고, 지우면 누적 신고 수가 줄어 처리 중인 건의 판단이 바뀝니다.
  - 관리자 회원 목록은 사전 등록 명단을 겸하므로 탈퇴 계정을 제외합니다. 행 자체는 글·댓글의 작성자로 남습니다.
  - 정리와 익명화가 한 트랜잭션에서 함께 커밋되도록 `MemberWithdrawer`를 `@Transactional(propagation = MANDATORY)`로 두었습니다.
  - 관리자 화면의 확인 문구와 API 설명을 실제 동작에 맞게 고쳤습니다. "완전히 삭제"라고 안내하면서 익명화하면 관리자가 잘못 이해합니다.
  - 삭제 로그에서 학번을 뺐습니다. 지운 개인정보를 로그에 다시 적으면 익명화한 의미가 없습니다.
- 언제·어디서: 2026-09-21, `fix/member-anonymization` 브랜치.
- 검증: 백엔드 테스트 전체 통과, Flutter 78개 통과, 분석 경고 0건. 익명화를 기존 `memberRepository.delete(member)`로 되돌려 추가한 테스트 6건 중 5건이 실제로 실패하는 것을 확인한 뒤 원복했습니다.
- 남은 일: 익명화는 개인정보를 계정에서 지우지만 회원 행 자체는 남습니다. 완전 파기를 요구하는 기준이 따로 있다면 별도 판단이 필요합니다.

---

## 2026-09-21 - 분석 경고 정리, CI 게이트, 관리자 API 테스트, DB 기동 순서

- 누가: 프론트엔드·백엔드·인프라 공통 정리
- 무엇을: 코드 리뷰 P2 중 운영 위험이 없는 항목을 처리했습니다. 분석 경고를 0건으로 만들고 CI 게이트를 조였으며, 관리자 API에 권한 경계 테스트를 추가하고 DB 기동 순서를 보장했습니다.
- 왜:
  - CI가 `--no-fatal-warnings --no-fatal-infos`로 실행돼 경고와 정보를 모두 무시했고, 그 사이 26건이 쌓였습니다.
  - `AdminController`는 게시글·댓글 삭제와 복구, 신고 기각, 권한 승인처럼 되돌리기 어려운 작업을 모아두고 있는데 테스트가 하나도 없었습니다. `@PreAuthorize`는 어노테이션 한 줄이라 지우거나 범위를 넓혀도 컴파일 오류도 테스트 실패도 나지 않았습니다.
  - 컨테이너가 떴다는 것과 DB가 접속을 받을 준비가 됐다는 것이 달라, 백엔드가 먼저 붙으려다 재시작 루프를 돌 수 있었습니다.
- 어떻게:
  - `print` 14건을 `debugPrint`로, `withOpacity` 5건을 `withValues`로, 조건부 맵 항목 3건을 null-aware 문법으로 바꿨습니다. 폐기된 `RadioListTile`의 `groupValue`·`onChanged`는 `RadioGroup`으로 옮겼습니다.
  - `main.dart`의 미사용 import 2건을 지우고, 쓰이지 않던 `authState` 변수는 대입만 없앴습니다. `ref.watch` 구독 자체는 앱 시작 시 로그인 상태 확인을 시작시키므로 유지했습니다.
  - `csv_picker_web.dart`의 `dart:html` 관련 2건은 사유를 적어 파일 단위로 제외했습니다. 관리자 명단 일괄 등록의 파일 선택 경로라 단위 테스트로 검증할 수 없습니다.
  - 관리자 API 테스트 14건을 추가했습니다. 비로그인 차단, 일반 사용자 차단, ADMIN과 SUPER_ADMIN의 경계, 권한 통과 후 입력 검증을 고정합니다.
  - MySQL에 healthcheck를 추가하고 백엔드가 `service_healthy`를 기다리게 했습니다.
- 언제·어디서: 2026-09-21, `chore/ci-gate-and-healthcheck` 브랜치.
- 검증: 백엔드 119개, Flutter 78개, JavaScript 6개 테스트 통과. 분석 경고 0건. 승인 엔드포인트의 권한을 ADMIN까지 일부러 넓혀 테스트가 실제로 실패하는지 확인한 뒤 원복했습니다. `docker compose config`로 구성 유효성을 확인했습니다.
- 남은 일: `csv_picker_web.dart`의 `package:web` 이전은 관리자 계정으로 업로드를 확인할 수 있을 때 별도로 진행합니다.

---

## 2026-09-21 - 계정 열거 차단, 진단 종료, 페이징·조회수 정리

- 누가: 백엔드·프론트엔드 공통 작업
- 무엇을: 코드 리뷰의 P1-7·P1-5·P1-8과 미뤄 둔 진단 잔재 정리를 한 번에 처리했습니다.
- 왜:
  - 가입 흐름이 '명단에 없음'과 '이름 불일치'를 다르게 답해, 학번을 순서대로 넣어보면 '명단에 있지만 아직 가입하지 않은 학번' 목록을 만들 수 있었습니다.
  - 진단 기능은 껐지만 배선이 남아 죽은 파일이 배포에 실리고 라우트 이동마다 없는 객체를 호출했습니다.
  - 페이징 API가 이미 있는데 앱과 부하테스트가 레거시 전체 조회를 부르고 있었습니다.
  - 조회수가 동시 조회에서 유실됐습니다.
- 어떻게:
  - `verifyStudentForSignup`의 '등록되지 않은 학번'과 '이름 불일치'를 같은 응답으로 통일했습니다. '이미 가입 완료'는 로그인 안내를 위해 구분해 남겼습니다. 비밀번호 재설정이 이미 따르던 기준입니다.
  - `GET /auth/check-duplicate`를 제거했습니다. 유일한 호출처가 도달하지 않는 소셜 가입 화면이었고, 소셜 가입은 서버에서도 비활성이라 그 화면과 테스트도 함께 정리했습니다.
  - 진단 관련 JS·Dart 파일과 배선을 모두 제거하고, 남은 죽은 코드를 정리했습니다. 기록을 검증하던 JS 테스트는 실제 차단 결과를 검증하도록 바꿨습니다.
  - 공지 검색을 페이징 API로 보내고 `max-page-size=50`을 설정했습니다. 레거시 엔드포인트는 구버전 앱 호환을 위해 남겼습니다.
  - 조회수를 UPDATE 한 문장으로 올리고, 갱신 행 수로 존재 여부를 함께 판정합니다.
- 언제·어디서: 2026-09-21, `fix/enumeration-and-paging` 브랜치.
- 검증: 백엔드 105개, Flutter 78개, JavaScript 6개 테스트 통과. 실패 조합이 같은 문구를 주는지, 16개 동시 조회에서 조회수가 정확히 16 오르는지 실제 트랜잭션 커밋으로 확인했습니다.
- 남은 일: 레거시 `/notices/search`는 구버전 앱이 사라진 뒤 제거합니다.

---

## 2026-09-21 - 웹앱 보안 헤더 적용

- 누가: 프론트엔드 호스팅 설정
- 무엇을: Firebase Hosting 응답에 보안 헤더 5종을 추가하고, 그 과정에서 쓰지 않는 `google_sign_in` 의존성을 제거했습니다.
- 왜: API(nginx)에는 보안 헤더가 있었지만 정작 사용자가 접속하는 웹앱에는 하나도 없었습니다. 특히 클릭재킹 방어가 없었습니다.
- 어떻게:
  - `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, `Content-Security-Policy`를 모든 경로에 적용했습니다.
  - CSP는 추측으로 쓰지 않고, 빌드 산출물을 헤더와 함께 로컬에서 서빙해 브라우저로 직접 검증했습니다. 이 과정에서 세 가지가 잡혔습니다.
    - `index.html`의 인라인 스크립트가 차단됨 → 별도 파일로 분리했습니다. 해시는 공백 하나만 바뀌어도 깨지므로 파일 분리가 안전합니다.
    - Flutter가 폰트를 `fetch()`로 가져와 `font-src`만으로는 부족함 → `connect-src`에도 `fonts.gstatic.com`을 넣었습니다.
    - `google_sign_in`이 `accounts.google.com/gsi/client`를 주입함 → 코드에서 쓰지 않는 의존성이라 제거했습니다.
  - `script-src`에는 `'unsafe-inline'`이 필요합니다. Firebase 플러그인이 초기화 스크립트를 인라인으로 주입하며, 빼면 앱이 부팅하지 못하는 것을 확인했습니다. 인라인은 허용하되 외부 스크립트 출처는 `gstatic`으로 제한됩니다.
- 언제·어디서: 2026-09-21, `fix/web-security-headers` 브랜치.
- 검증: 헤더를 적용한 상태로 앱이 정상 부팅·렌더링하고 CSP 위반이 0건임을 브라우저 콘솔에서 확인했습니다. Flutter 81개, JavaScript 22개 테스트 통과. 호스팅 설정 테스트에 보안 헤더 회귀 검증을 추가했습니다.
- 남은 일: `web/swipe_diagnostics.v5.js`는 참조가 없는데도 배포에 포함됩니다. 관련 테스트 15개와 함께 별도로 정리해야 합니다.

---

## 2026-09-21 - 가입 인증 증표 도입

- 누가: 백엔드·프론트엔드 공통 작업
- 무엇을: 인증 코드 검증에 성공하면 증표를 발급하고, 가입 요청이 그 증표를 제시하도록 했습니다.
- 왜: 기존에는 인증 통과 기록이 학번만을 키로 저장되고 가입 요청이 증표를 요구하지 않아, 인증을 마친 주체와 가입을 완료하는 주체가 분리되지 않았습니다.
- 어떻게:
  - 인증 성공 시 256비트 난수를 URL 안전 형식으로 인코딩한 증표를 발급해 그 응답에만 실어 보냅니다.
  - 가입은 `ConcurrentHashMap.compute` 한 번으로 조회·검증·삭제를 묶어 증표를 소비합니다. 같은 증표로 동시에 들어와도 최대 한 번만 성공합니다.
  - 틀린 증표는 통과 기록을 지우지 않습니다. 제3자가 아무 값이나 보내서 정상 사용자의 인증 결과를 날리지 못하게 하기 위함입니다.
  - 증표 비교는 상수 시간으로 수행하고, 만료된 통과 기록은 발급 시점에 함께 정리합니다.
  - 프론트는 증표를 저장소에 남기지 않고 가입 화면 상태로만 보유합니다.
- 언제·어디서: 2026-09-21, `fix/signup-verification-grant` 브랜치.
- 검증: 백엔드 97개, Flutter 80개 테스트 통과. 증표 없음·추측값·재사용·동시 요청 8건 중 1건만 성공을 회귀 테스트로 고정했습니다. 웹 릴리스 빌드 성공.
- 남은 일: 없습니다. 비밀번호 재설정은 이미 통과 기록에 의존하지 않아 이번 범위에서 제외했습니다.

---

## 2026-09-18 - 공급망·자격증명 취급 정리

- 누가: 저장소 설정 정리
- 무엇을: 서비스 계정 키의 무시 범위를 넓히고, 의존성 자동 감시에 GitHub Actions·Docker·Flutter를 추가했으며, 시드 계정 비밀번호를 소스에서 설정으로 옮겼습니다.
- 왜: 세 가지 모두 "아직 사고가 나지 않았을 뿐" 인 상태였습니다.
  - 서비스 계정 키 무시 규칙이 `backend/.gitignore`에만 있어 `docker/` 하위에는 적용되지 않았습니다. 그 경로에 키 파일을 두고 `git add .` 하면 그대로 커밋됩니다.
  - 외부 action을 공급망 보안 목적으로 SHA 고정해 뒀는데 `github-actions` 감시가 없어, 취약점이 나와도 영원히 옛 버전에 머무릅니다.
  - 시드 계정 비밀번호가 소스에 평문으로 있어 깃 히스토리에 영구히 남습니다.
- 어떻게:
  - 루트 `.gitignore`에 `**/firebase-adminsdk*.json`과 서비스 계정 파일 패턴을 추가했습니다. `docker/` 경로에서 실제로 무시되는지 확인했습니다.
  - `dependabot.yml`에 `github-actions`(루트), `docker`, `pub`을 월간 단일 그룹으로 추가했습니다. 기존 `gradle` 설정과 같은 형식이라 PR 수가 늘지 않습니다.
  - `DataInitializer`의 비밀번호를 `ysync.seed.password` 설정으로 옮겼습니다. 값이 없으면 임의 기본값으로 계정을 만들지 않고 경고를 남긴 뒤 시드 생성을 건너뜁니다. 알려진 비밀번호를 가진 계정이 조용히 생기는 편이 더 위험하기 때문입니다.
  - 테스트는 `src/test/resources/application.properties`에서 전용 값을 받아 기존 동작을 유지합니다.
- 언제·어디서: 2026-09-18, `chore/supply-chain-hardening` 브랜치.
- 검증: 백엔드 88개 테스트 통과. 시드 비밀번호가 없거나 공백일 때 저장소를 전혀 건드리지 않는지 테스트로 고정했습니다. `git check-ignore`로 `docker/firebase-adminsdk.json`이 무시되는 것을 확인했습니다.
- 남은 일: 로컬에서 시드 계정이 필요하면 `YSYNC_SEED_PASSWORD` 환경 변수를 설정해야 합니다. 운영은 `@Profile("!prod")`이라 영향이 없습니다.

---

## 2026-09-18 - 관리자 회원 조회 항목 정리

- 누가: 백엔드·프론트엔드 공통 작업
- 무엇을: 관리자 회원 조회에 가입 시 인증한 학교 메일을 추가하고, 관리 목적이 없는 개인 알림 토글을 응답에서 뺐습니다. 가입 완료 로그에도 인증 메일을 남깁니다.
- 왜: 계정 관련 문의가 들어왔을 때 관리자가 어떤 메일 계정으로 가입했는지 확인할 방법이 없어 DB에 직접 접속해야 했습니다. 반대로 개인 알림 토글은 관리자가 쓸 일이 없는데 노출되고 있었습니다.
- 어떻게:
  - `AdminMemberResponse`에 `email`을 추가하고 `noticeEnabled`·`commentEnabled`를 제거했습니다. 관리자 회원 관리 화면의 표와 모바일 카드에 인증 메일을 표시하며, 복사할 수 있도록 선택 가능한 텍스트로 넣었습니다.
  - 본인 조회(`GET /members/me`)에는 메일을 넣지 않았습니다. 프론트 모델의 `email`은 nullable이라 본인 조회 응답에서는 null입니다.
  - 가입 완료 로그에 인증 메일을 함께 기록했습니다.
- 언제·어디서: 2026-09-18, `fix/signup-attribution` 브랜치.
- 검증: 백엔드 86개, Flutter 76개 테스트 통과. 관리자 DTO가 메일을 포함하고 개인 알림 설정은 노출하지 않는지, 본인 조회 응답에 메일이 없어도 앱이 동작하는지 테스트로 고정했습니다.
- 남은 일: 없음.

---

## 2026-09-18 - 학년 선택 현황 집계 추가

- 누가: 백엔드·프론트엔드 공통 작업
- 무엇을: 관리자가 학년별 알림 전환 시점을 판단할 수 있도록 선택 현황 집계를 추가했습니다.
- 왜: 학년 기능은 배포했지만 전환 여부를 정할 근거가 없었습니다. 회원별 상태는 볼 수 있었으나 미설정 인원이 몇 명인지 셀 방법이 없었습니다. 전환하면 미설정 회원은 학년 공지 알림을 받지 못하므로 그 인원을 먼저 알아야 합니다.
- 어떻게:
  - `GET /api/v1/admin/members/notice-grade-stats`를 추가했습니다. 회원 전체를 메모리로 읽지 않고 DB에서 집계합니다.
  - 모수는 '공지 알림을 받을 수 있는 회원'(활성 + 공지 알림 동의)입니다. 공지 알림을 꺼 둔 회원은 전환과 무관하므로 제외합니다.
  - 미설정은 DB에 값이 없어 집계 행으로 돌아오지 않으므로, 전체 수에서 선택 인원을 빼서 셉니다.
  - 관리자 회원 관리 상단에 현황 카드를 넣었습니다. 선택 완료 비율과 미설정 인원, 전환 시 영향을 함께 보여줍니다. 집계 조회가 실패해도 회원 관리 사용을 막지 않습니다.
- 언제·어디서: 2026-09-18, `chore/docs-cleanup-and-grade-stats` 브랜치.
- 검증: 백엔드 84개, Flutter 75개, JavaScript 22개 테스트 통과. `flutter analyze` 오류 없음.
- 남은 일: 이 숫자를 보고 `NOTICE_GRADE_FILTER_ENABLED=true` 전환 시점을 정합니다.

---

## 2026-09-18 - 학년 선택과 공지 알림 대상 구현

- 누가: 백엔드·프론트엔드 공통 작업
- 무엇을: `docs/GRADE_NOTIFICATION_PRODUCT_PLAN.md`의 1단계(선택·갱신)와 2단계(학년별 알림)를 구현했습니다.
- 왜: 학생이 자기 학년을 직접 고르고 전체 공지와 해당 학년 공지만 알림으로 받도록 하기 위함입니다. 학번으로 학년을 추정하거나 자동 진급시키지 않습니다.
- 어떻게:
  - 회원에 `noticeGradePreference`(nullable, 미설정은 null)와 `gradeConfirmedYear`를 추가했습니다. 공지의 `Grade.ALL`과 회원의 `GENERAL_ONLY`는 다른 개념이라 별도 enum으로 분리했습니다.
  - 학년도는 서버가 계산합니다(3월 1일 00:00 Asia/Seoul 기준, 설정으로 조정 가능). 단말기 시각에 의존하지 않습니다.
  - 가입 시 선택값 수신(선택 항목), 본인 수정 `PUT /api/v1/members/me/notice-grade`, 관리자 예외 수정을 추가했습니다. 선택값과 확인 학년도는 한 트랜잭션에서 함께 저장합니다.
  - 앱에 첫 설정·재확인 안내를 추가했습니다. 같은 세션에서 반복하지 않되 학년도가 바뀌면 다시 안내하며, '나중에'를 골라도 앱 사용을 막지 않습니다.
  - 공지 수신자를 한 번만 선정해 앱 알림함과 푸시가 같은 목록을 쓰도록 바꿨습니다. 푸시 토큰이 없어도 알림함에는 저장되고, 푸시 실패가 알림함 저장을 되돌리지 않습니다.
- 언제·어디서: 2026-09-18, `fix/notice-grade-notifications` 브랜치.
- 검증: 백엔드 80개, Flutter 73개, JavaScript 22개 테스트 통과. `flutter analyze` 오류 없음(기존 경고 3개·정보 27개). 웹 릴리스 빌드 성공.
- 남은 일: **2단계 전환은 `NOTICE_GRADE_FILTER_ENABLED=true`로 켜야 적용됩니다.** 기본값은 false이며, 이 상태에서는 기존 발송 범위가 그대로 유지됩니다. 실제 푸시 도착은 기기 권한·토큰·FCM 상태에 따라 달라지므로 배포 후 확인이 필요합니다.

---

## 2026-09-18 - 문서 구조 정리 및 통합

- 누가: 문서 정리 작업
- 무엇을: `docs/` 아래 문서를 목적별로 통합하고 목차를 추가했습니다. 문서 4개를 삭제하고 내용은 남는 문서로 옮겼습니다.
- 왜: 같은 내용이 여러 파일에 나뉘어 있어 어디를 봐야 하는지 알기 어려웠고, 조사가 끝난 임시 문서가 그대로 남아 있었습니다.
- 어떻게:
  - `CONTEXT.md`(서비스 개요·사용자·기능 흐름) → `ARCHITECTURE.md`. 서비스 설명이 기술 명세보다 앞에 오도록 문서를 재배치하고 머리말을 고쳤습니다.
  - `MAC_MIGRATION_GUIDE.md`(개발 환경·검증 절차·자격 증명·서버 점검) → `DEVELOPMENT.md`.
  - `HELP_FEEDBACK.md`(도움말·의견 사용 흐름과 API) → `API_SPECIFICATION.md`.
  - `IOS_PWA_SWIPE_BACK_INVESTIGATION.md`(조사가 끝난 임시 기록) → `TROUBLESHOOTING.md` 10절.
  - `docs/README.md`를 추가해 어떤 상황에 어떤 문서를 볼지와 문서별 성격(상시 기준 / 기록 / 절차)을 구분했습니다.
  - 삭제된 문서를 가리키던 `README.md`와 작업 이력의 링크를 새 위치로 바꿨습니다.
- 언제·어디서: 2026-09-18, `docs/consolidate-project-docs` 브랜치.
- 검증: 저장소의 모든 마크다운 상대 링크(`.md`, `.png`, `.json`)를 검사해 끊긴 링크가 없음을 확인했습니다.
- 남은 일: 없음. 새 문서를 만들기 전에 기존 문서에 들어갈 자리가 있는지 먼저 확인하는 기준을 `docs/README.md`에 적었습니다.

---

## 2026-09-18 - 임시 PWA 진단 버튼 비활성화

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(정상 동작 확인·진단 버튼 제거 요청) |
| **When** | 2026-09-18, Asia/Seoul |
| **Where** | `fix/disable-pwa-swipe-diagnostics`, 웹 진입점·운영 빌드 |
| **Status** | 로컬 검증 완료, [PR #106](https://github.com/JinsuBae2/y-sync/pull/106), 미배포 |

### 작업 개요(What·Why)

- 사용자가 로딩 표시 적용 후 정상 동작을 확인하여 임시 진단 버튼을 비활성화합니다.

### 구현(How)

- index.html에서 진단 스크립트를 제외하고 진단 sessionStorage 키 2개만 정리합니다. 운영 빌드의 SWIPE_DIAGNOSTICS=true도 제거합니다.
- 기존 로딩 표시·제스처·캐시 수정은 유지합니다. 진단 소스와 테스트는 남기지만 운영 페이지에서 로드하지 않습니다.

### 검증 및 추적(Verification·Tracking)

- Flutter 62개·JavaScript 22개 통과, 분석 오류 없음(기존 경고 3개·정보 27개).
- 진단 플래그 없는 운영 웹 릴리스 빌드 성공. Node VM으로 진단 키만 정리하고 저장소 접근 실패도 처리함을 확인했습니다.
- 백엔드 test bootJar 성공(8개 작업 UP-TO-DATE). 코드·운영 설정·문서는 별도 한글 커밋으로 분리했습니다.

### 후속 작업(Risks / Follow-up)

- 새 페이지 로드 후 진단 버튼이 사라집니다. 이미 열린 페이지에는 다음 로드까지 남을 수 있습니다.
- 임시 진단 기록은 삭제되며, 인증 정보나 다른 저장값은 변경하지 않습니다.

---

## 2026-09-18 - PWA 복귀 로딩 표시와 캐시 보완

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(요청·검토) |
| **When** | 2026-09-18, Asia/Seoul |
| **Where** | `fix/pwa-back-loading-cache`, 웹 로딩 UI·Firebase Hosting |
| **Status** | 로컬 구현·검증 완료, [PR #105](https://github.com/JinsuBae2/y-sync/pull/105), 미배포 |

### 작업 개요(What·Why)

- 회색 화면을 로딩 표시로 대체할 수 있는지 실기기에서 확인하기 위해 HTML 로딩 UI를 추가했습니다.
- 배포 후에도 이전 20px JS가 사용된 기록에 대응해 물리적 파일명과 캐시 정책을 변경했습니다.

### 구현(How)

- 설치형 iOS PWA의 popstate에서 로딩을 표시하고 Flutter 전환 완료·프레임 후 해제합니다. 루트 뒤로가기 처리도 프레임 후 해제합니다.
- 완료 신호 누락 시 2초 자동 해제, pagehide 정리, 토큰으로 이전 완료 신호 무시. 로딩은 터치를 가로채지 않습니다.
- 보조 JS를 버전 파일명으로 참조하고 no-cache, no-store, must-revalidate를 설정합니다. 진단에 back_loading 이벤트를 추가했습니다.

### 검증 및 추적(Verification·Tracking)

- 코드 `e8b31e8`, 설정 `4de779d`. 문서는 별도 커밋입니다.
- Flutter 62개·JavaScript 22개 테스트 통과. 표시·완료·시간 제한·연속 이동·페이지 이탈 및 일반 브라우저 제외 확인.
- 분석 오류 없음(기존 경고 3개·정보 27개), 진단 활성 웹 빌드 성공. 빌드 출력의 새 파일과 부트스트랩 이전 로딩·캐시 규칙 확인.
- 백엔드 test bootJar 성공(8개 작업 UP-TO-DATE). 기존 로컬 iOS·Gradle 변경은 제외했습니다.

### 후속 작업(Risks / Follow-up)

- WebKit 자체 전환 화면이나 popstate 이전의 회색 구간은 HTML 로딩으로 가리지 못할 수 있습니다. 배포 후 실기기 표시 확인 필요.
- 새 index.html이 로드돼야 새 파일명을 사용합니다. 이미 실행 중인 앱을 강제로 갱신하지는 않습니다.
- 진단에서 diag_v5 / guard_v4 및 back_loading shown/frame_ready/timeout을 확인합니다. 서버 전송은 없습니다.

---

## 2026-09-17 - PWA 뒤로가기 경계 32px 조정

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(요청·검토) |
| **When** | 2026-09-17, Asia/Seoul |
| **Where** | `fix/pwa-back-gesture-edge-width`, 설치형 iOS PWA 공통 상세 이동 |
| **Status** | 로컬 구현·검증 완료, [PR #104](https://github.com/JinsuBae2/y-sync/pull/104), 미배포 |

### 작업 개요(What·Why)

- 일곱 번째 진단에서 왼쪽 21·22px 스와이프가 기존 20px 차단 밖이라 브라우저 복귀로 이어졌습니다.

### 구현(How)

- 브라우저 차단과 Flutter 공통 상세의 인식 폭을 32px로 확장했습니다. PWA 전용 Cupertino 라우트에서 감지기 padding만 조정하고 본문 MediaQuery는 복원합니다.
- 기존 애니메이션·취소 조건과 다른 플랫폼 라우트는 유지합니다. 진단은 활성 폭을 사용하고 guard_v4 / flutter_v3 / diag_v4로 구분합니다.

### 검증 및 추적(Verification·Tracking)

- 코드 커밋 `45480a6`. 코드와 문서를 별도 한글 Conventional Commits로 기록합니다.
- 수정 전 21·22·31px 복귀 테스트 실패 확인. 수정 후 Flutter 전체 61개·JavaScript 19개 통과.
- 짧은 드래그 취소, 중앙 드래그·세로 스크롤, 본문 여백 유지 확인.
- 분석 오류 없음(기존 경고 3개·정보 27개), 진단 활성 웹 빌드 성공. 백엔드 test bootJar 성공(8개 작업 UP-TO-DATE).
- 기존 로컬 변경은 제외했습니다. 앞서 승인된 main 대상 운영 수정 PR 흐름을 유지합니다.

### 후속 작업(Risks / Follow-up)

- 실제 iPhone에서 복귀·취소·목록 탭 이동·가로 화면을 확인해야 합니다. 32px가 모든 기기의 브라우저 제스처 범위를 포괄한다고 보장하지 않습니다.
- Flutter 3.41의 감지 폭 계산에 의존하므로 SDK 업데이트 시 경계 테스트 재확인 필요. 직접 MaterialPageRoute로 여는 다른 상세 진입 경로 통일은 후속 범위입니다.

---

## 2026-09-17 - 스와이프 시작 위치·방향 진단

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(요청·검토) |
| **When** | 2026-09-17, Asia/Seoul |
| **Where** | `fix/pwa-swipe-position-diagnostics`, PWA 기기 내 진단 |
| **Status** | 로컬 검증 완료, [PR #103](https://github.com/JinsuBae2/y-sync/pull/103), 미배포 |

### 작업 개요(What·Why)

- 여섯 번째 기록의 outside_edge → history_pop이 어느 위치·방향의 터치인지 구분하기 위해 진단을 추가했습니다.

### 구현(How)

- 단일 터치 시작 좌표·화면 폭과 종료 시 변위·방향을 기록합니다. 최종 좌표가 없으면 last_observed로 구분합니다.
- 다중 터치·진단 종료 시 추적을 초기화하고, 이동 중에는 마지막 위치만 메모리에 유지합니다. 차단 영역·앱 동작은 변경하지 않습니다.

### 검증 및 추적(Verification·Tracking)

- 코드 커밋 `cce940e`. JavaScript 18개·Flutter 57개 테스트 통과, 분석 오류 없음(기존 경고 3개·정보 27개).
- 진단 활성 웹 릴리스 빌드 성공. 백엔드 test bootJar 성공(8개 작업 UP-TO-DATE).
- 기존 로컬 변경은 제외하고 한글 코드·문서 커밋을 분리했습니다.

### 후속 작업(Risks / Follow-up)

- 기존 진단 저장 버튼 사용. diag_v3 표식과 시작 위치·방향을 확인합니다.
- 브라우저가 터치 전달을 끊으면 관찰된 방향과 실제 최종 동작이 다를 수 있습니다. 이번 PR은 해결 패치가 아닌 진단 보완입니다.

---

## 2026-09-17 - PWA 차단 실행 진단 보완

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(요청·검토) |
| **When** | 2026-09-17, Asia/Seoul |
| **Where** | `fix/pwa-gesture-diagnostics`, 설치형 iOS PWA |
| **Status** | 로컬 구현·검증 완료, [PR #102](https://github.com/JinsuBae2/y-sync/pull/102), 미배포 |

### 작업 개요(What·Why)

- PR #101 배포 후에도 브라우저 history_pop이 발생했으나 차단 코드 실행 여부를 구분할 수 없었습니다. 차단 범위와 화면 동작을 유지하며 진단만 보완했습니다.

### 구현(How)

- 터치 차단 호출 결과와 미호출 이유를 고정 분류로 기록합니다.
- 각 이벤트에 진단·차단·Flutter 진단 구현 세대와 차단 활성 여부를 기록합니다. 실행 표식이 없는 구버전은 unknown/null로 구분합니다.
- 기존 150개 기기 내 기록·서버 미전송·진단 저장 버튼을 유지합니다. 진단 오류가 터치 처리를 중단하지 않도록 보호합니다.

### 검증 및 추적(Verification·Tracking)

- 코드 커밋: `0e7d7bf`. 문서는 별도 한글 Conventional Commit으로 분리했습니다.
- JavaScript 13개·Flutter 57개 테스트 통과. 새 실행 결과·버전 누락 테스트의 수정 전 실패를 확인했습니다.
- Flutter 분석 오류 없음(기존 경고 3개·정보 27개), `SWIPE_DIAGNOSTICS=true` 웹 릴리스 빌드 성공.
- `bash ./gradlew test bootJar`: 성공(8개 작업 UP-TO-DATE).
- 기존 로컬 iOS·Gradle 변경과 보안 검토 문서는 제외했습니다.

### 후속 작업(Risks / Follow-up)

- 배포 후 재현 직후 기존 진단 저장 버튼으로 기록을 확인합니다. 이번 변경은 회색 화면 해결이 아니라 원인 구분용입니다.
- prevented는 defaultPrevented 확인 결과일 뿐 WebKit 화면 전환 차단의 보장이 아닙니다. 버전은 진단 구현 세대이며 전체 앱 빌드 번호가 아닙니다.

---

## 2026-09-17 - 목록 스와이프 및 루트 복귀 안전망

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(요청·검토) |
| **When** | 2026-09-17, Asia/Seoul |
| **Where** | `fix/pwa-root-back-navigation`, 설치형 iOS PWA |
| **Status** | 로컬 구현·검증 완료, [PR #101](https://github.com/JinsuBae2/y-sync/pull/101), 미배포 |

### 작업 개요(What·Why)

- 상세 복귀 후 목록에서 가장자리 스와이프 시 브라우저 history_pop이 발생한 진단 결과에 대응합니다. 단계별 배포 계획 중 PR 1만 구현했습니다.

### 구현(How)

- 설치형 iOS PWA 전체 화면의 왼쪽 20px 단일 터치에서 브라우저 기본 동작을 차단합니다. Flutter 이벤트 전파와 목록 탭 이동은 유지합니다.
- 메인 탭을 PopScope로 감싸 Flutter로 전달된 루트 뒤로가기 요청을 처리합니다. 상세 전용 observer·라우트 표식은 제거했습니다.
- 진단 기준도 20px로 통일하고 JavaScript 테스트를 CI에 추가했습니다. 캐시된 이전 Flutter 번들의 JS 호출은 호환 유지합니다.

### 검증 및 추적(Verification·Tracking)

- 코드: `628e97c`, CI: `9c99541`. 프론트·CI·작업 문서를 별도 한글 Conventional Commits로 기록했습니다.
- `flutter test`: 57개 통과. 루트 종료 요청 방지, 탭 이동, 상세 스와이프 및 시스템 뒤로가기 복귀 확인.
- `node --test test/web/*.cjs`: 9개 통과. 목록 차단·진단 경계·루트 안전망 테스트의 수정 전 실패를 확인했습니다.
- `flutter analyze --no-fatal-warnings --no-fatal-infos`: 오류 없음, 기존 경고 3개·정보 27개.
- `flutter build web --release --dart-define=SWIPE_DIAGNOSTICS=true`: 성공.
- 백엔드 `bash ./gradlew test bootJar`: 성공(8개 작업 UP-TO-DATE).
- 기존 iOS·Gradle 로컬 변경 및 보안 검토 문서는 제외했습니다. develop이 main보다 뒤처진 상태여서 사용자가 이번 PR의 main 대상을 명시적으로 승인했습니다.

### 후속 작업(Risks / Follow-up)

- 실제 iPhone PWA의 회색 화면 해결 여부는 배포 후 확인해야 합니다. PopScope는 Flutter에 전달된 요청만 처리하며 브라우저 전환 자체를 차단한다고 보장하지 않습니다.
- 좌표 없는 other → touch_cancel → history_pop 기록만으로 터치 방향과 정확한 시작 위치를 확정하지 않습니다.
- 로딩 팝업 제거·진입 경로 통일은 PR 2, 불필요한 목록 재요청 검토는 PR 3으로 분리합니다.

---

## 2026-09-17 - iOS PWA 게시글 뒤로가기 제스처 수정 후보

- 실기기 진단에서 브라우저 history 복귀와 Flutter 스와이프 복귀 경로를 확인했습니다. 회색 화면의 직접 원인은 아직 확정하지 않았습니다.
- 설치형 iOS PWA의 공지·커뮤니티 상세에서만 왼쪽 20px 터치의 브라우저 기본 동작을 차단합니다. Flutter 이벤트 전파는 유지하며 목록·다이얼로그에서는 해제합니다.
- 검증: Flutter 테스트 56개, JavaScript 테스트 8개 통과. 진단 활성 웹 릴리스 빌드 성공. 분석 오류 없음(기존 경고 3개·정보 27개).
- 실기기 해결 여부는 배포 후 확인해야 합니다. 진단 기능은 비교를 위해 유지했습니다.

---

#
## 2026-09-16 - PWA 진단 버튼 배포 활성화 누락 수정

- Production Deploy의 Flutter 빌드에 `SWIPE_DIAGNOSTICS=true`를 추가했습니다.
- 진단 기능은 배포됐지만 기본 비활성이라 버튼이 나오지 않았던 누락을 수정합니다.
- 이번 진단 기간에는 모든 사용자에게 버튼이 표시됩니다. 서버 전송은 없고 종료 버튼으로 기기 기록을 지울 수 있습니다. 조사 종료 후 플래그를 제거합니다.
- 검증: 기존 진단 플래그 웹 빌드 성공 기록, 배포 명령 확인, CI에서 전체 테스트·빌드 수행.

---
# 2026-09-16 - iPhone PWA 스와이프 복귀 진단 모드

- 회색 화면의 원인은 아직 미확정입니다. 동작 수정 대신 페이지 재시작·브라우저 이벤트·Flutter 라우트·목록 요청을 구분하는 선택적 진단 모드를 추가했습니다.
- 기본 비활성, 최근 150개 이벤트만 기기 sessionStorage에 보관합니다. 서버 전송·토큰·본문·검색어 기록은 없습니다.
- `SWIPE_DIAGNOSTICS=true` 빌드 또는 `swipeDebug=1` 쿼리로 활성화하고 진단 저장 버튼으로 JSON을 저장합니다. 일반 배포에서는 진단 빌드 플래그를 사용하지 않습니다.
- 검증: Flutter 전체 55개, JavaScript 진단 테스트 6개 통과. 진단 웹 릴리스 빌드 성공, 분석 오류 없음(기존 경고 3건·정보 27건).
- 후속: 실제 iPhone PWA에서 기록 수집 필요. 회색 화면 해결이나 실기기 재현 완료를 의미하지 않습니다.
- 상세: [문제 해결 기록의 iPhone PWA 항목](TROUBLESHOOTING.md#10-iphone-설치형-pwa-스와이프-복귀-중-회색-화면).

---

## 2026-09-16 - 프론트 공통 API provider 분리

- 공지 provider에 있던 Dio·토큰 저장소·인터셉터를 `api_client_provider.dart`로 이동했습니다.
- 관련 provider·화면·테스트의 import를 변경하고, 댓글 수 갱신에 필요한 공지 의존성은 유지했습니다.
- 기존 인증·401 처리 동작을 유지하는 리팩터링입니다. 401 처리 개선과 스와이프 문제 해결은 별도입니다.
- 검증: 관련 테스트 4개 및 전체 Flutter 테스트 53개 통과, 웹 릴리스 빌드 성공. 분석 오류 없음(기존 경고 3건·정보 27건).
- 브랜치: `refactor/frontend-api-client-swipe-diagnostics`. 기존 iOS·Gradle 로컬 변경과 보안 검토 문서는 제외했습니다.

---

## 2026-09-16 - 인증 API 요청 수 제한, Tomcat 패치, ddl-auto 전환 준비

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(코드 점검 요청·검토) |
| **When** | 2026-09-16, Asia/Seoul |
| **Where** | `fix/ops-hardening` 브랜치, Nginx 설정, Gradle 의존성, 운영 프로파일 |
| **Status** | 로컬 구현·검증 완료, PR #97 |

### **작업 개요**

**변경 내용**

- Nginx에 인증 API 요청 수 제한을 엔드포인트 성격별로 추가하고, HSTS 헤더와 현실적인 타임아웃을 적용했습니다. 미사용 WebSocket 설정을 제거했습니다.
- `tomcat-embed-core`를 11.0.24에서 11.0.25로 올렸습니다.
- 운영 프로파일의 `ddl-auto` 주석이 실제 값과 달랐던 문제를 정정하고, 전환 절차 문서를 추가했습니다. **값 자체는 이번에 바꾸지 않았습니다.**

**목적**

- 인증 API에 엣지 단 요청 수 제한이 전혀 없어, 애플리케이션 단 방어(시도 5회 제한, 재발송 쿨다운)와 짝을 이룰 방어선이 없었습니다. 메일 발송 할당량 소모와 서버 자원 점유도 함께 막습니다.
- Tomcat 11.0.24에 알려진 취약점이 있었습니다.
- 운영 프로파일 주석은 `validate`라고 선언하는데 실제 값은 `update`였습니다. 설정을 읽는 사람이 자동 스키마 변경이 꺼져 있다고 오해할 수 있었습니다.

### **구현**

**Nginx 요청 수 제한**

- 교내 Wi-Fi·실습실은 공인 IP를 공유하므로 여러 학생의 요청이 하나의 제한을 소비합니다. 따라서 IP 기준 제한은 넉넉하게 두고, 계정 단위의 정밀한 제한은 애플리케이션이 담당하도록 역할을 나눴습니다.
- 성격별로 구역을 나눴습니다. 메일 발송(20r/m)은 외부 할당량을 소모하므로 가장 엄격하게, 인증번호 검증(60r/m)과 로그인(60r/m)은 공유 IP에서 다수가 동시에 시도할 수 있어 여유를 두었으며, 그 외 인증 API는 120r/m입니다. 초과 시 429를 반환합니다.
- 프록시 공통 설정은 `server` 단에 두고 `location`이 상속받도록 했습니다. `location`마다 중복 선언하면 한쪽만 수정되어 설정이 어긋납니다.

**타임아웃과 WebSocket**

- `proxy_read_timeout`이 86400초(24시간)였고 WebSocket Upgrade 설정이 열려 있었습니다. 백엔드와 프론트엔드 모두 WebSocket을 사용하지 않는 것을 확인하고 제거했습니다.
- 읽기·전송 타임아웃은 120초로 두었습니다. 관리자 Excel·CSV 일괄 등록이 오래 걸릴 수 있어 60초보다 여유를 둔 값입니다.

**Tomcat**

- `ext['tomcat.version'] = '11.0.25'`로 고정했습니다. Spring Boot 패치 버전이 11.0.25 이상을 관리하게 되면 이 고정은 제거합니다.

**ddl-auto**

- 주석만 정정하고 값은 `update`로 유지했습니다. `update`로 운영돼 온 스키마는 엔티티와 어긋나 있을 수 있고, `validate`는 불일치 시 기동을 실패시키므로 값만 바꿔 배포하면 운영 장애가 됩니다.
- 전환 절차를 `docs/DDL_AUTO_MIGRATION.md`에 정리했습니다. 운영 스키마를 복제 환경에 올린 뒤 `SPRING_JPA_HIBERNATE_DDL_AUTO=validate` 환경변수로 기동을 시도해, 코드 수정 없이 불일치를 먼저 확인하는 방식입니다.

### **검증 및 추적**

**검증**

- `./gradlew clean test bootJar`: 전체 테스트 통과, JAR 빌드 성공
- Tomcat 해석 결과 `11.0.24 -> 11.0.25` 확인
- 의존성 취약점 재조회: 260개 중 **0개** (변경 전 1개)
- `docker compose -f docker/docker-compose.yml config --quiet`: 통과
- CI의 MySQL 포트 미공개 검사 재현: 통과
- Nginx 설정 문법 검사(`nginx -t`): 통과. `docker compose config`는 nginx 문법을 검증하지 않으므로 실제 nginx로 확인했습니다. 컨테이너 이미지 pull이 로컬 Docker 자격증명 문제로 막혀 있어, 인증서 경로와 upstream 호스트명만 임시 값으로 치환한 복사본을 로컬 nginx로 검사했습니다(지시어는 원본 그대로).
- `git diff --check`: 통과

**추적**

- 브랜치: `fix/ops-hardening`
- 관련 PR: #97

### **후속 작업 및 제한사항**

- **`ddl-auto` 전환은 완료되지 않았습니다.** `docs/DDL_AUTO_MIGRATION.md`에 따라 운영 스키마를 확인한 뒤 별도 작업으로 값을 바꿔야 합니다.
- 요청 수 제한 값은 추정치입니다. 운영 반영 후 정상 사용자가 429를 받는 사례가 있는지 확인하고 조정합니다. 특히 신입생 가입이 몰리는 시기에 메일 발송 구역을 확인합니다.
- Nginx 설정 변경은 컨테이너 재시작이 필요합니다. 배포 후 인증·로그인 흐름을 직접 확인합니다.

---

## 2026-09-16 - 이메일 인증번호 시도 제한 및 원자적 검증

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(코드 점검 요청·검토) |
| **When** | 2026-09-16, Asia/Seoul |
| **Where** | `fix/verification-code-hardening` 브랜치, Spring `MemberService` 인증번호 처리 |
| **Status** | 로컬 구현·검증 완료, PR #96 |

### **작업 개요**

**변경 내용**

- 인증번호 challenge당 시도 횟수를 5회로 제한하고, 5번째 실패에서 challenge를 폐기합니다.
- `verifyCode`를 `ConcurrentHashMap.compute` 기반으로 재작성해 조회·검증·시도 증가·삭제를 하나의 원자적 연산으로 묶었습니다.
- 인증번호 재발급에 60초 쿨다운을 적용했습니다.
- `verifyCode`가 소비한 challenge를 반환하도록 바꿔, 비밀번호 재설정이 중간 저장소(`verifiedStudents`)를 거치지 않습니다.

**목적**

- 기존 구현은 코드 불일치 시 challenge를 폐기하지 않아, 6자리 인증번호(10^6)를 유효기간 5분 동안 무제한 대입할 수 있었습니다. 비밀번호 재설정 경로가 이 검증을 사용하므로 활성 계정도 대상이었습니다.
- `get → 검증 → remove` 구조라 같은 코드로 거의 동시에 들어온 두 요청이 모두 통과할 수 있었고, 비밀번호 재설정에서는 서로 다른 비밀번호가 경쟁할 수 있었습니다.

### **구현**

- **계정 잠금은 도입하지 않았습니다.** 학번 기준 잠금은 공격자가 타인 학번으로 일부러 실패시켜 그 계정을 잠그는 수단이 되므로, 실패의 책임을 계정이 아니라 challenge에 지웁니다. 폐기 대상은 challenge이며 계정 상태는 변경하지 않습니다.
- **재발급 쿨다운을 별도 맵에 보관합니다.** challenge와 함께 지우면 "5회 소진 → 즉시 재발급 → 5회 더"로 시도 제한을 그대로 우회할 수 있습니다. 키가 학번이라 크기는 회원 수로 제한됩니다.
- **`compute` 안에서는 예외를 던지지 않습니다.** remapping function에서 예외가 발생하면 매핑 갱신이 취소되어 시도 횟수 증가가 사라집니다. 판정 결과만 돌려받고 예외는 `compute` 종료 후 바깥에서 던집니다. 같은 이유로 `VerificationInfo`는 불변으로 두고 실패 시 새 인스턴스를 반환합니다.
- 목적(purpose) 불일치는 사용자의 추측이 아니라 호출 오류이므로 시도 횟수를 소모하지 않습니다.
- 관리자 계정 재등록 초기화 시 쿨다운도 함께 해제해 사용자가 바로 재인증할 수 있도록 했습니다.

### **검증 및 추적**

**검증**

- `./gradlew clean test bootJar`: 전체 테스트 통과, JAR 빌드 성공
- 신규 테스트가 실제로 회귀를 잡는지 확인: 시도 제한 상수를 무력화한 상태에서 해당 테스트 실패를 확인한 뒤 복원했습니다.
- 동시성 검증: 같은 인증번호로 두 스레드가 동시에 검증할 때 최대 1건만 성공하는지 확인했습니다.
- 비밀번호 재설정 회귀: `MemberAccountRecoveryTest` 통과(중간 저장소 제거 영향 확인)
- `git diff --check`: 통과

**추적**

- 브랜치: `fix/verification-code-hardening`
- 관련 PR: #96

### **후속 작업 및 제한사항**

- **가입 흐름의 인증 결과 바인딩은 이 작업 범위가 아닙니다.** 가입은 인증과 최종 제출이 분리돼 있어 여전히 `verifiedStudents`를 사용하며, 학번과 이름을 아는 제3자가 그 인증 결과로 가입을 완료할 수 있는 문제가 남아 있습니다. 후속 작업에서 1회용 인증 증표(grant)로 대체합니다. 이번 변경에서 `verifyCode`가 소비한 challenge를 반환하도록 해 두어 해당 지점만 교체하면 됩니다.
- 인증 상태는 인메모리이므로 **단일 인스턴스를 전제**합니다. 다중 인스턴스로 확장하면 공유 저장소로 옮겨야 합니다.
- 만료된 challenge와 쿨다운 항목을 정리하는 주기적 작업은 아직 없습니다. 키가 학번이라 크기는 회원 수로 제한되지만, 후속 작업에서 함께 검토합니다.
- 엣지 단 요청 수 제한(nginx)은 별도 작업으로 진행합니다. 애플리케이션 방어와 짝을 이루어야 합니다.

---

## 2026-09-16 - 회원가입 비밀번호 정책 적용

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(코드 점검 요청·검토) |
| **When** | 2026-09-16, Asia/Seoul |
| **Where** | `fix/signup-password-policy` 브랜치, Spring `MemberService`, Flutter 회원가입 화면 |
| **Status** | 로컬 구현·검증 완료, PR 준비 |

### **작업 개요**

**변경 내용**

- `MemberService.signup()`이 기존 비밀번호 정책 검사(`validatePassword`)를 호출하도록 했습니다.
- Flutter 회원가입 화면의 클라이언트 검증을 서버 정책과 동일한 기준으로 맞췄습니다.
- 정책 적용과 검사 순서를 고정하는 회귀 테스트 `MemberSignupPasswordPolicyTest`를 추가했습니다.

**목적**

- 정책 자체는 구현되어 있었으나 비밀번호 재설정 경로에서만 호출되고 회원가입에서는 호출되지 않았습니다. 그 결과 신규 가입자가 한 글자 비밀번호를 설정할 수 있었습니다.
- 클라이언트는 최소 4자만 확인하고 있어 서버 정책(8~64자, 영문·숫자·특수문자 포함)과 어긋났습니다. 서버에만 적용하면 사용자가 입력을 마친 뒤에야 오류를 보게 되므로 함께 맞췄습니다.

### **구현**

- `validatePassword(password)`를 `signup()` 진입부, 즉 **이메일 인증 상태를 확인하기 전에** 호출합니다. 정책 위반 같은 단순 입력 오류로 인증 결과가 소모되지 않아야 사용자가 같은 인증으로 다시 시도할 수 있기 때문입니다.
- 클라이언트 검증은 길이(8~64)와 문자 구성(영문·숫자·특수문자)을 나눠 각각 다른 안내 문구를 표시합니다.
- 기존 회원의 비밀번호는 재검증하지 않으므로 로그인에 영향이 없습니다.

### **검증 및 추적**

**검증**

- 백엔드 `./gradlew test bootJar`: 전체 42개 테스트 통과, JAR 빌드 성공
- 신규 테스트가 실제로 회귀를 잡는지 확인: `validatePassword` 호출을 제거한 상태에서 3개 테스트 실패를 확인한 뒤 복원했습니다.
- Flutter `flutter analyze lib/screens/signup_screen.dart`: 문제 없음
- Flutter `flutter test`: 전체 53개 통과
- `flutter build web --release`: 성공
- `git diff --check`: 통과

**추적**

- 브랜치: `fix/signup-password-policy`
- 관련 PR: #95

### **후속 작업**

- 정책 도입 이전에 가입해 정책에 미달하는 비밀번호를 가진 기존 계정이 있을 수 있습니다. 다음 로그인 시 변경을 유도할지는 별도 항목으로 검토합니다.
- 비밀번호 재설정 화면은 클라이언트 검증 없이 서버 정책에만 의존합니다. 동일한 사전 안내가 필요한지 확인합니다.

---

## 2026-09-16 - 공지 댓글 비로그인 공개 범위 축소

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(코드 점검 요청·검토) |
| **When** | 2026-09-16, Asia/Seoul |
| **Where** | `fix/public-notice-comment-access` 브랜치, `SecurityConfig` 인가 설정 |
| **Status** | 로컬 구현·검증 완료, PR 준비 |

### **작업 개요**

**변경 내용**

- 공지 API의 비로그인 공개 매처를 `GET /api/v1/notices/**`에서 `GET /api/v1/notices/*`로 축소했습니다.
- `GET /api/v1/notices/{id}/comments`가 인증을 요구하도록 바뀌었습니다. 목록·검색·상세는 기존대로 공개입니다.
- 공개 범위를 고정하는 회귀 테스트 `NoticePublicAccessSecurityTest`를 추가했습니다.

**목적**

- 기존 `/**` 패턴이 하위 경로를 모두 포함해 공지 댓글 조회까지 비로그인 공개 상태였습니다. 댓글 응답에는 작성자 실명과 회원 ID가 포함되므로, 인증 없이 학생 개인정보를 조회할 수 있었습니다.
- 공개가 필요한 것은 공지 본문이지 댓글 작성자 정보가 아니므로 범위를 의도에 맞게 좁혔습니다.

### **구현**

- 단일 세그먼트 패턴 `/*`는 `/api/v1/notices/search`와 `/api/v1/notices/{id}`를 포함하지만 두 세그먼트인 `/api/v1/notices/{id}/comments`는 포함하지 않습니다. 매처 한 곳만 변경해 의도한 경계가 만들어집니다.
- 쓰기 API는 기존 매처가 `HttpMethod.GET` 한정이라 이번 변경 이전에도 공개된 적이 없으며, `@PreAuthorize`와 `anyRequest().authenticated()`로 계속 보호됩니다.
- 회귀 테스트는 실제 시큐리티 필터체인을 통과시키는 `@SpringBootTest` + MockMvc 방식으로 작성해 설정 변경을 직접 검증합니다. 비로그인 목록·검색 200, 비로그인 상세 비차단, 비로그인 댓글 401, 로그인 사용자 댓글 비차단 네 가지를 고정합니다.

### **검증 및 추적**

**검증**

- `./gradlew test bootJar`: 전체 42개 테스트 통과, JAR 빌드 성공
- 신규 테스트가 실제로 회귀를 잡는지 확인: 매처를 `/**`로 되돌린 상태에서 `공지_댓글은_비로그인_조회가_차단된다` 실패를 확인한 뒤 복원했습니다.
- 백엔드 테스트 커버리지: 라인 35.0% → 36.7%, 브랜치 23.5% → 24.2%
- 영향 범위 확인: FCM 발송 경로는 서버 내부 이벤트라 인가 설정과 무관하고, 토큰 등록 API는 `/api/v1/auth/**` 매처에 속해 변경되지 않습니다. 푸시 딥링크가 사용하는 공지 상세 조회는 공개를 유지했습니다. k6 부하테스트가 호출하는 세 경로도 모두 공개 범위에 남습니다.

**추적**

- 브랜치: `fix/public-notice-comment-access` (`origin/main` 기준 분기)
- 관련 PR: 생성 후 기록

### **후속 작업**

- 비로그인 또는 토큰 만료 상태에서 공지 상세로 진입했을 때 댓글 로딩 401이 Dio 인터셉터의 로그인 화면 이동으로 처리되는지 실기기에서 확인합니다.
- 공지 상세 공개를 유지했으므로 비로그인 조회마다 조회수 UPDATE가 계속 발생합니다. 조회수 증가 방식은 별도 항목으로 검토합니다.

---

## 2026-09-16 - 운영 공개 조회 부하테스트 준비 및 실행 안전장치

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(운영 수용성 1차 측정 준비·검토) |
| **When** | 2026-09-16, Asia/Seoul |
| **Where** | `fix/qa-ui-improvements` 브랜치, k6 GitHub Actions workflow, 부하테스트 문서 |
| **Status** | PR #92 병합 완료, 실제 운영 부하테스트는 미실행 |

### **작업 개요**

- Oracle Cloud 1GB Free Tier 운영 서버의 기본 조회 처리 성능과 안정성을 확인할 수 있도록 수동 실행형 k6 환경을 구성했습니다.
- 인증 없이 허용된 `GET /api/v1/notices`, `GET /api/v1/notices/search`, `GET /api/v1/hello`만 대상으로 하며, 쓰기 API·인증 우회·공지 상세 조회는 제외했습니다.
- 부하는 `5 → 10 → 20 → 30 → 50 VU` 단계로 제한하고, HTTP 실패율 1% 미만 및 p95 1000ms 미만 threshold와 단계별 RPS·평균·p95·p99·timeout summary를 추가했습니다.

### **구현 및 안전장치**

- `.github/workflows/k6-load-test.yml`을 `workflow_dispatch` 전용으로 구성하고 운영 URL을 입력값으로 주입합니다.
- 동일 실행 직렬화, 15분 timeout, 빈 값·비HTTPS·localhost·loopback 대상 차단, `contents: read` 최소 권한을 적용했습니다.
- Prometheus/Grafana는 도입하지 않고 `docker stats`, `free -m`, `top`, `vmstat` 기반 서버 리소스 기록 절차를 `docs/LOAD_TEST.md`에 정리했습니다.

### **검증 및 추적**

- workflow YAML 정적 검증 통과
- k6 JavaScript `node --check` 통과
- `git diff --check` 통과
- PR #92: `fix/qa-ui-improvements` → `main`
- `main` 병합 커밋 `2142c3c`

### **후속 작업 및 제한사항**

- Actions에서 `k6 Public Read Load Test`를 운영 URL로 수동 실행하고, SSH 세션에서 단계별 CPU·RAM·컨테이너 메모리·OOM·재시작 여부를 함께 기록합니다.
- 1차 50 VU 결과가 안정적인 경우에만 75/100 VU를 별도 테스트로 검토합니다.
- 부하테스트는 조회 API만 사용하지만 운영 서버 대상이므로 사전 공지·실행 시간·중단 기준을 확인한 뒤 수행합니다.

---

## 2026-09-09 - 도움말·의견 작성·관리자 의견함 가독성 개선

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(배포 화면 검토 및 디자인 개선 요청) |
| **When** | 2026-09-09, Asia/Seoul |
| **Where** | `style/help-feedback-readability` 브랜치, Flutter 도움말·의견 작성·관리자 의견 화면 |
| **Status** | PR #88·#89 병합 및 프론트엔드 운영 배포 완료 |

### **작업 개요**

- 배포된 도움말과 의견 화면에서 정보 구분이 약하고 폼의 입력 순서가 한눈에 보이지 않는 문제를 개선했습니다.
- 도움말 진입부에 `💡` 포인트와 네이비 안내 카드를 추가하고, FAQ를 카테고리 아이콘·질문 번호·답변 배경으로 구분했습니다.
- 의견 작성은 유형, 내용, 이미지의 3단계 카드로 나누고 유형별 선택 컨트롤, 오류 유형에 맞는 안내, 비공개 안내와 실행 환경 안내를 분리했습니다.
- 관리자 의견함은 제목·설명, 미확인/확인/전체 필터, 총 건수, 상태·유형·날짜 배지, 본문·관련 화면·실행 환경, 첨부 및 확인 액션의 시각적 위계를 정리했습니다.

### **검증 및 추적**

- 변경 파일 `flutter analyze`: 문제 없음
- 관련 Flutter 테스트 10개 통과
- Flutter 전체 테스트 48개 통과
- `flutter build web --release`: 성공
- 전체 `flutter analyze --no-fatal-infos`: 변경 범위 밖 기존 warning 3건과 info 27건 유지
- `git diff --check`: 통과
- PR #88·#89: `style/help-feedback-readability` → `main`
- `main` 병합 커밋 `a021487`, `3a8aeb8`
- Production Deploy 실행 `34316972554`, `34319238496` 성공

### **후속 작업**

- 관리자 의견이 많이 쌓인 경우의 화면 밀도는 운영 데이터 증가 시 계속 확인합니다.
- API·DB·권한·제출 동작에는 변경이 없어 프론트엔드 이전 버전으로 즉시 복구할 수 있습니다.

---

## 2026-09-09 - 도움말 및 비공개 사용자 의견 기능 추가

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(기능 제안·검토) |
| **When** | 2026-09-09, Asia/Seoul |
| **Where** | `feat/help-feedback` 브랜치, Flutter 내정보·관리자 화면, Spring Boot 의견 API |
| **Status** | PR #87 병합 및 백엔드·프론트엔드 운영 배포 완료 |

### **작업 개요**

- 내정보에 `도움말 및 의견 보내기`를 추가해 시간표, 알림·스크랩, 계정 사용법을 FAQ로 제공합니다.
- 사용자는 오류 신고, 개선 제안, 기타 의견을 비공개로 제출할 수 있습니다. 사용자용 처리 상태 조회와 공개 Q&A는 제공하지 않습니다.
- 관리자는 관리자 콘솔의 의견 탭에서 미확인·확인·전체 목록을 보고 내부 확인 처리할 수 있습니다.

### **구현**

- 의견 제목·본문·관련 화면과 앱 버전·실행 환경을 저장하며 이름·학번·연락처는 응답과 화면에 노출하지 않습니다.
- PNG/JPG 이미지를 최대 3장, 장당 2MB로 제한하고 파일 시그니처를 검사합니다. 이미지는 공개 업로드 URL 대신 DB에 저장하고 관리자 인증 API에서만 `no-store`로 제공합니다.
- 일반 사용자의 관리자 목록·이미지·확인 API 접근을 차단했습니다. 제출 실패 시 입력을 유지하고 계정이 바뀐 경우 전송을 중단합니다.
- 운영 및 유지보수 기준은 [API 명세의 도움말 및 사용자 의견 항목](API_SPECIFICATION.md#도움말-및-사용자-의견)에 정리했습니다.

### **검증 및 추적**

- 백엔드 `./gradlew test bootJar`: 전체 38개 테스트와 JAR 빌드 통과
- Flutter 변경 파일 `flutter analyze`: 문제 없음
- Flutter `flutter test`: 전체 48개 통과
- `flutter build web --release`: 성공
- `git diff --check`: 통과
- PR #87: `feat/help-feedback` → `main`
- `main` 병합 커밋 `a6e3fe0`
- Production Deploy 실행 `34314739206` 성공

### **후속 작업**

- 이미지가 제보당 최대 6MB이므로 제보량 증가 시 DB·백업 용량과 보관·삭제 정책을 검토합니다.
- FAQ는 앱 기능 변경 시 함께 갱신해야 합니다.

---

## 2026-09-08 - 계정 전환 캐시 경계 및 시간표 그리드 UI 개선

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(계정 전환 잔존 캐시 및 시간표 UI 개선 요청·검토), Codex(구현·검증) |
| **When** | 2026-09-08, Asia/Seoul |
| **Where** | `fix/timetable-cache-and-grid-ui` 브랜치, Flutter 인증·개인 데이터 Provider와 시간표 화면 |
| **Why** | 로그아웃이 일부 Provider만 무효화하고 개인 시간표가 회원 ID에 종속되지 않아 계정 전환 시 이전 사용자의 데이터가 재사용될 수 있었으며, 시간표 상단 컨트롤과 격자·수업 카드가 실제 시간표보다 무겁고 모바일 정보 밀도가 낮았기 때문입니다. |
| **How** | 현재 회원 ID를 나타내는 세션 Provider를 계정 전용 데이터의 캐시 키로 사용하고, 인증 전환 전에 즉시 비운 뒤 회원 확인 후 활성화했습니다. 시간표는 얇은 탭·필터, 안정적 과목 색상 해시, 옅은 단색 격자, 가로 스크롤 가능한 열, 간결한 모바일 목록으로 재구성했습니다. |
| **Status** | PR #86 병합 및 프론트엔드 운영 배포 완료 |

### **원인 및 변경 내용**

- 운영 DB의 개인 시간표 소유권은 변경하지 않았습니다. 확인된 데이터는 각 기존 회원 소유로 그대로 유지합니다.
- 로그아웃, 일반 로그인 시작, 소셜 로그인, 소셜 회원가입 직후 로그인, 초기 토큰 확인 실패와 Dio 401 처리에서 개인 캐시보다 먼저 세션 회원 ID를 제거합니다. 따라서 이전 데이터가 새 인증 화면에 남아 있을 수 있는 프레임을 차단합니다.
- 개인 시간표, 알림·미읽음 수, 스크랩, 내정보·내 게시글·내 댓글 Provider는 세션 회원 ID를 관찰합니다. 새 회원 ID가 확정되면 해당 Provider만 새로 생성되어 API를 다시 호출합니다.
- 공지, 커뮤니티 목록, 학사일정, 학과 시간표처럼 공용인 Provider는 세션 키에 연결하지 않고 로그아웃 시 무효화하지 않아 불필요한 중복 호출을 막았습니다.
- 시간표 상단의 학과·개인 선택은 큰 채움 박스 대신 하단 인디케이터 탭으로, 학년·반은 작은 배경의 필터로 축소했습니다. 요일별·주간 전환과 요일 선택도 세로 공간을 줄였습니다.
- 주간표는 24시간제를 유지하면서 모바일 열 너비를 104px로 확보해 6열 압축 대신 가로 스크롤을 사용합니다. 넓은 화면에서는 가용 폭에 따라 104~180px 범위로 확장합니다.
- 과목명 기반 FNV-1a 해시와 저채도 6색 팔레트로 같은 과목의 색을 실행마다 안정적으로 유지합니다. 수업명 우선 위계, 강의실·교수명 단계 노출, 현재 수업의 얇은 파란 테두리를 적용했습니다.
- 모바일 요일별 목록은 큰 시간 배지와 그림자를 제거하고 시간·과목·장소·교수 순으로 밀도를 높였으며, 기존 116px 하단 안전 여백을 유지했습니다.

### **검증 및 추적**

- 변경 파일 `flutter analyze --no-fatal-infos`: 오류·경고 없음, 기존 info lint 6건 유지
- 계정 전환 및 관련 화면 테스트 8개 통과
- Flutter 전체 테스트 45개 통과
- `flutter build web --release` 성공
- `git diff --check` 통과
- PR #86: `fix/timetable-cache-and-grid-ui` → `main`
- `main` 병합 커밋 `a9c6fc4`
- Production Deploy 실행 `34185387908` 성공
- 계정 전환 테스트에서 A 회원 개인 시간표 조회 후 세션 제거 시 개인 시간표·알림·스크랩이 빈 상태가 되고, B 회원 활성화 후 각 API가 다시 호출되는 것을 확인했습니다. 같은 과정에서 공용 학과 시간표 API 호출 횟수는 1회로 유지했습니다.

### **위험 요소 및 복구 방법**

- 실제 기기별 글꼴 렌더링과 터치 감각은 최종 화면 확인이 필요합니다. 자동 테스트는 작은 모바일과 데스크톱의 overflow 및 주요 전환 동작을 확인합니다.
- 문제 발생 시 세션 Provider 의존성 변경과 시간표 화면 커밋을 각각 되돌릴 수 있습니다. DB·API 계약·환경변수 변경은 없어 별도 데이터 복구나 마이그레이션이 필요하지 않습니다.
- 계정 전환 시 개인 데이터 캐시 격리와 시간표 화면은 운영 반영됐으며, 실제 기기별 글꼴 렌더링과 터치 감각을 계속 확인합니다.

---

## 2026-09-08 - 모바일 일정·시간표 가독성 및 개인 수업 일괄 선택 개선

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(모바일 시간표 가독성·다중 수업 선택 개선 요청 및 검토) |
| **When** | 2026-09-07~08, Asia/Seoul |
| **Where** | `feat/mobile-timetable-planning` 브랜치, Flutter 시간표 화면, Spring Boot 개인 시간표 API |
| **Status** | PR #83·#84 병합 및 백엔드·프론트엔드 운영 배포 완료 |

### **작업 개요**

- 390px 모바일 화면에 월~토 6개 열과 시간축을 함께 표시하며 과목명·강의실이 잘리는 문제를 개선했습니다.
- 모바일에서는 요일별 수업 카드 목록을 기본으로 보여주고, 필요한 경우 `주간` 격자로 전환하도록 구성했습니다.
- 요일별 카드에 수업 시간, 과목명, 정식 강의실명, 교수명을 줄임 없이 표시하고 현재 수업을 `진행 중` 배지로 구분했습니다.
- 주간 격자의 시간축은 `am/pm` 대신 24시간제로 표시하고, 모바일 열 너비를 확보해 수평 스크롤로 확인하도록 했습니다.
- 요일별·주간 전환, 학년·반·요일 선택을 동일한 전체 너비 세그먼트 형태로 정돈하고 수업 카드를 시간·과목·강의실·교수 정보가 명확히 구분되도록 재설계했습니다.
- 모바일 학사 일정은 달력과 일정 목록 사이의 높이 분할을 제거하고, Safari의 좁은 화면에서도 페이지 전체를 한 번에 세로 스크롤하도록 변경했습니다.
- 모바일 일정 목록은 하단 내비게이션과 관리자 추가 버튼에 가리지 않도록 충분한 하단 여백을 유지합니다.
- 학과 수업 선택창의 `+`를 다중 선택 토글로 변경하고, 선택한 수업 개수를 하단 버튼에서 확인한 후 한 번에 추가하도록 했습니다.
- `POST /api/v1/timetable/personal/bulk` API가 기존 개인 시간표와 선택 목록 내부의 교시 겹침을 모두 검증하고, 오류 시 일부만 저장되지 않도록 하나의 트랜잭션으로 처리합니다.

### **검증 및 추적**

- 백엔드 `./gradlew test bootJar` 성공
- Flutter 수정 파일 정적 분석 통과
- Flutter `flutter analyze --no-fatal-warnings --no-fatal-infos` 종료 코드 0, 기존 warning/info 30건 유지
- Flutter 전체 테스트 44개 통과
- `flutter build web --release` 성공
- 코드 커밋 `a2e3847`
- 후속 모바일 일정·시간표 UI 커밋 `4fe4b3b`
- 모바일 일정·시간표 후속 관련 테스트 5개 통과
- PR #83: `feat/mobile-timetable-planning` → `main`
- 후속 PR #84: `feat/mobile-timetable-planning` → `main`
- `main` 병합 커밋 `27d1854`, `148837f`
- Production Deploy 실행 `34096336598`, `34175127934` 성공
- 원격 `develop`이 `main`보다 44커밋 뒤처져 있어 `develop` 대상 PR은 과거 배포 변경 46개 파일을 함께 표시합니다. 범위 오염을 피하기 위해 최신 `main`에서 분기한 피처 브랜치를 `main`으로 보내는 예외 경로를 사용합니다.

### **후속 작업 및 제한사항**

- 다중 등록 중 하나라도 기존 수업과 겹치면 전체 요청을 거부하며, 사용자가 선택을 조정해 다시 저장해야 합니다.
- 주간 격자는 6일치 정보를 유지하므로 모바일에서 수평 스크롤이 필요하며, 기본 요일별 목록이 주요 사용 경로입니다.
- 모바일 달력과 일정 목록은 하나의 스크롤 영역이므로 기존 모바일 높이 조절 분할선은 제공하지 않습니다. 데스크톱 가로 분할 조절은 유지합니다.

---

## 2026-09-07 - 학생 명단·일정 색상·학년별 시간표 운영 반영

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(관리자 명단 등록·일정 색상·시간표 사용성 개선 요청 및 검토) |
| **When** | 2026-09-07, Asia/Seoul |
| **Where** | 관리자 회원 관리, Flutter 홈·일정·시간표, Spring Boot 시간표 API |
| **Status** | PR #80·#81·#82 병합 및 백엔드·프론트엔드 운영 배포 완료 |

### **작업 개요**

- 학교 Excel·CSV 학생 명단의 헤더를 자동 매핑해 관리자가 회원을 일괄 등록하고, 신규·중복·오류 결과와 행별 사유를 확인하도록 개선했습니다.
- 일정에 저장된 색상을 홈 수업 카드, 달력 표시점과 일정 목록 강조색에 동일하게 반영했습니다.
- 학년별 반 시간표 조회와 여러 학과 수업의 개인 시간표 선택 경로를 추가했습니다.

### **검증 및 추적**

- 학생 명단 업로드 관련 백엔드 테스트 8개 통과
- PR #80·#81·#82가 `main`에 병합됨
- `main` 병합 커밋 `94b5a17`, `aac5797`, `76dc202`
- Production Deploy 실행 `34083446625`, `34088654429`, `34090950390` 성공

### **후속 작업 및 제한사항**

- 명단 양식과 시간표 데이터 구조가 변경되면 헤더 매핑·중복 검증·학년·반 선택 회귀 테스트를 함께 갱신합니다.
- 일정 색상은 저장된 색상 값을 기준으로 모든 표시 위치가 같은 팔레트를 사용하도록 유지합니다.

---

## 2026-09-04 - PWA 서버 점검 화면 및 자동 재연결 운영 반영

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(서버 재시작·장애 안내 화면 요청 및 검토) |
| **When** | 2026-09-04, Asia/Seoul |
| **Where** | Flutter Web/PWA 전역 앱 셸, Dio 인터셉터, 서버 상태 확인 API, Firebase Hosting |
| **Status** | PR #78 병합 및 프론트엔드 운영 배포 완료 |

### **작업 개요**

- 로그인 화면과 동일한 네이비 그라데이션·글라스 카드·정식 천마 로고를 사용한 전역 서버 점검 화면을 추가했습니다.
- API 연결 타임아웃·연결 오류와 HTTP `502`, `503`, `504`를 감지하면 기존 화면 상태를 유지한 채 점검 화면을 최상단에 표시합니다.
- 점검 화면이 열린 동안 10초마다 `/api/v1/hello`를 확인하고, 사용자가 PWA로 복귀할 때도 즉시 상태를 다시 확인합니다. 서버가 정상 응답하면 자동으로 기존 화면으로 돌아갑니다.
- 수동 `지금 다시 확인` 버튼과 마지막 확인 시각을 제공하며, 서버 장애와 사용자 네트워크 단절을 구분하기 어려운 경우를 고려해 인터넷 연결 확인 문구를 함께 표시합니다.

### **검증 및 추적**

- 로컬 Flutter 전체 테스트 41개 통과
- `flutter analyze --no-fatal-warnings --no-fatal-infos` 종료 코드 0, 기존 warning/info 30건 유지
- `flutter build web --release` 성공
- PR #78의 Backend·Frontend·Configuration·Gate 통과
- `main` 병합 커밋 `7f80868`
- Production Deploy 실행 `33849911993` 성공 및 Firebase Hosting 배포 완료
- 운영 PWA HTTP `200`, 운영 `/api/v1/hello` 정상 응답 확인

### **후속 작업 및 제한사항**

- PWA가 백그라운드에 있으면 브라우저가 타이머를 지연할 수 있으므로 복귀 이벤트에서 즉시 재확인합니다.
- PWA 프로세스가 완전히 종료되면 자동 재시도도 중단되지만, 다음 실행 시 초기 상태 확인을 수행합니다.
- 현재 화면은 장애를 감지해 안내하는 기능입니다. 계획 점검의 종료 예정 시각과 운영자 입력 문구가 필요하면 별도의 점검 상태 API를 추가합니다.

---

## 2026-09-03 - gstack /cso 회원·인증·공급망 보안 강화

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(보안 점검 결과 제공·검토) |
| **When** | 2026-09-03, Asia/Seoul |
| **Where** | `fix/security-hardening` 브랜치, Spring Boot 회원 관리·JWT, GitHub Actions, Gradle wrapper, Docker Compose |
| **Status** | PR #53·릴리스 PR #55 병합 및 운영 배포 완료 |

### **작업 개요**

- 일반 ADMIN의 `SUPER_ADMIN` 생성·승격 및 기존 `SUPER_ADMIN` 변경을 서비스 계층에서 차단했습니다.
- 회원 관리 응답을 DTO로 제한하고 비밀번호 직렬화를 방어적으로 차단했습니다.
- 역할 변경 시 `authVersion`을 올리고 JWT 인증 권한을 데이터베이스의 현재 역할로 구성했습니다.
- JWT 고정 기본 키를 제거하고, 외부 action 전체 SHA 고정, Gradle 배포본 체크섬, CODEOWNERS와 월간 Gradle Dependabot을 추가했습니다.
- 백엔드 컨테이너를 비root 사용자로 전환하고 운영 배포 사용자의 UID/GID와 바인드 마운트 권한을 맞췄습니다.

### **검증 및 추적**

- 보안 근접 회귀 테스트와 백엔드 전체 테스트 27개 통과
- Flutter 전체 테스트 38개 통과
- `flutter analyze --no-fatal-warnings --no-fatal-infos` 종료 코드 0, 기존 warning/info 30건 유지
- `JWT_SECRET` 제거 상태에서 `PlaceholderResolutionException`으로 기동 실패 확인
- Docker 이미지 빌드 성공, 기본 사용자 `ysync`와 UID/GID `1000:1000`, `/app/uploads` 쓰기 확인
- Docker Compose 설정 검사 및 `git diff --check` 통과
- Dependency Review는 저장소 Dependency Graph 비활성 상태에서 지원되지 않아 제거하고 Dependabot 정기 점검으로 전환
- 코드 커밋 `44d30a0`
- 문서 커밋 `ccaec60`, PR #53
- GitHub Actions 실행 `33725169117`의 Backend, Frontend, Configuration, Gate 통과
- PR #53 `develop` 병합 커밋 `483427f`
- 릴리스 PR #55 `main` 병합 커밋 `12e4394`
- Production Deploy 실행 `33727365754` 성공

### **후속 작업**

- 운영 환경의 JWT 설정과 서버 업로드 디렉터리 권한은 릴리스 후에도 정기 점검합니다.

---

## 2026-09-01 - iOS 가장자리 스와이프 복귀 및 홈 하단 잘림 수정

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(iPhone 스와이프 복귀 지연·조회수 미반영·홈 하단 잘림 제보) |
| **When** | 2026-09-01, Asia/Seoul |
| **Where** | `fix/adaptive-swipe-navigation` 브랜치, Flutter 플랫폼별 상세 라우트·목록 갱신·홈 화면 |
| **Status** | 로컬 구현·검증 완료, 사용자 확인 대기 |

### **작업 개요**

- iOS에서는 `CupertinoPageRoute`를 사용해 화면 왼쪽 가장자리의 interactive pop gesture를 지원하고, Android와 그 외 플랫폼은 기존 `MaterialPageRoute`를 유지했습니다.
- 스와이프 중에는 기존 목록을 그대로 유지하고 제스처가 완료된 뒤에만 Provider를 무효화해 조회수 증가 결과를 비차단 방식으로 반영합니다.
- 공지·커뮤니티 목록과 홈의 상세 복귀가 단순 열람인지 수정인지와 관계없이, 상세 진입으로 증가한 조회수를 복귀 후 목록에 동기화하도록 변경했습니다.
- 모바일 홈 목록 하단 여백을 116px로 늘려 76px 하단 내비게이션 바 뒤에 마지막 인기글이 가려지지 않도록 했으며, 데스크톱은 기존 36px 여백을 유지했습니다.

### **검증 및 추적**

- iOS `CupertinoPageRoute`와 Android·Fuchsia·Linux·macOS·Windows의 `MaterialPageRoute` 선택 테스트를 추가했습니다.
- iOS 화면 왼쪽 5px에서 오른쪽으로 드래그하는 위젯 테스트로 상세 복귀와 복귀 후 목록 갱신을 확인했습니다.
- 모바일 홈 `ListView`의 116px 하단 여백 회귀 테스트를 추가했습니다.
- 변경 파일 대상 `flutter analyze --no-pub`: 이슈 없음
- `flutter test --no-pub`: 38개 통과
- `flutter build web --release --no-pub`: 성공
- `git diff --check`: 이상 없음

### **후속 작업**

- 운영 반영 후 iPhone PWA 실기기에서 가장자리 스와이프 프레임과 조회수 표시를 확인합니다.
- Android 시스템 뒤로가기·예측형 뒤로가기와 Web 브라우저 뒤로가기는 기존 Material 라우트 동작이 유지되는지 운영 환경에서 확인합니다.

---

## 2026-09-01 - 상세 화면 복귀와 목록 갱신 체감 속도 개선

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(뒤로가기 체감 속도와 로딩 피드백 개선 요청) |
| **When** | 2026-09-01, Asia/Seoul |
| **Where** | `fix/navigation-return-refresh` 브랜치, Flutter 공지·커뮤니티·홈·내 게시글·스크랩 화면 |
| **Status** | 로컬 구현·검증 완료, 사용자 확인 대기 |

### **작업 개요**

- 목록에서 게시글을 열 때 알림·딥링크용 중간 라우트를 교체하던 흐름을 제거하고, 단건 API 조회 중 로딩 오버레이를 표시한 뒤 상세 화면을 직접 열도록 변경했습니다.
- 상세 GET의 최신 데이터 조회와 조회수 증가 계약은 유지하면서 상세에서 목록으로 돌아올 때 불필요한 재조회만 제거했습니다.
- 공지·커뮤니티 목록은 상세를 읽기만 하고 돌아온 경우 Provider를 무효화하지 않아 기존 목록과 스크롤 위치를 즉시 다시 표시합니다.
- 게시글 작성·수정·삭제처럼 실제 데이터가 바뀐 경우에는 기존 Provider 갱신 흐름을 유지했습니다.
- 목록 데이터가 갱신 중일 때 화면 전체를 가리지 않고 기존 목록 위에 상단 진행 애니메이션을 표시하도록 했습니다.
- 스크랩 목록도 단순 열람 후에는 다시 조회하지 않고 상세에서 변경이 발생한 경우에만 갱신합니다.

### **검증 및 추적**

- 공지·커뮤니티 상세를 읽고 복귀할 때 목록 Provider 요청 횟수가 증가하지 않는 위젯 회귀 테스트 2개를 추가했습니다.
- 변경 파일 대상 `flutter analyze --no-pub`: 이슈 없음
- `flutter test --no-pub`: 32개 통과
- `flutter build web --release --no-pub`: 성공
- `git diff --check`: 이상 없음

### **후속 작업**

- 모바일 뒤로가기 제스처와 Web 브라우저 뒤로가기에서 목록 위치가 유지되는지 실제 환경에서 확인합니다.
- 알림·딥링크처럼 게시글 ID만 전달되는 경로는 단건 조회가 필요하므로 기존 중간 로딩 화면을 유지합니다.

---

## 2026-08-30 - 데스크톱 PWA 천마 아이콘 캐시 갱신

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(데스크톱 아이콘 적용 요청) |
| **When** | 2026-08-30, Asia/Seoul |
| **Where** | Flutter Web PWA manifest·favicon·apple-touch-icon |
| **Status** | 로컬 구현·검증 완료, 배포 대기 |

### **작업 개요**

- Chrome으로 설치한 데스크톱 PWA가 기존 아이콘 URL을 캐시하는 문제를 해소하기 위해 천마 아이콘 파일명을 `cheonma-v2`로 버전 갱신했습니다.
- `manifest.json`, favicon, apple-touch-icon 참조를 모두 새 URL로 변경했습니다.
- 네이티브 macOS·Windows·Linux 프로젝트는 추가하지 않았습니다.

### **후속 작업**

- 배포 후 기존 PWA를 완전히 종료하고 재실행해 manifest 아이콘 갱신을 확인합니다. OS 바로가기 캐시가 남아 있으면 PWA를 한 번 제거한 뒤 재설치합니다.

### **검증**

- `flutter test --no-pub test/firebase_hosting_config_test.dart`: 2개 통과
- `flutter build web --release --no-pub`: 성공
- `git diff --check`: 이상 없음

---

## 2026-08-30 - 비밀번호 재설정과 계정 재등록 초기화 분리

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(계정 복구 로직 보완 요청) |
| **When** | 2026-08-30, Asia/Seoul |
| **Where** | `feat/account-recovery-separation` 브랜치, Spring Boot 인증 API·Flutter 로그인 및 관리자 회원 관리 |
| **Status** | 로컬 구현·검증 완료, 사용자 확인 대기 |

### **작업 개요**

- 회원가입 시 인증한 학교 이메일을 계정에 저장하고, 등록 이메일 인증을 통한 본인 비밀번호 재설정 API와 화면을 추가했습니다.
- 관리자 기능을 `비밀번호 재설정 안내` 및 `계정 재등록 초기화`로 분리했습니다.
- 비밀번호 변경 또는 재등록 초기화 시 인증 버전을 증가시켜 기존 JWT를 무효화하고 FCM 토큰을 제거합니다.
- 양쪽 초기화 모두 계정 권한, 게시글, 댓글과 정지 상태를 보존합니다.

### **검증 및 추적**

- `./gradlew test bootJar`: 전체 테스트 및 배포 JAR 빌드 성공
- `flutter test --no-pub`: 29개 통과
- `flutter build web --release --no-pub`: 성공
- `flutter analyze --no-pub`: 신규 경고 없음, 기존 경고 30건 유지
- `git diff --check`: 이상 없음

### **후속 작업**

- 기존 회원은 인증 이메일이 저장되어 있지 않으므로 최초 1회에 한해 관리자가 재등록 초기화를 수행해야 합니다.

---

## 2026-08-30 - 천마 브랜드 로고 및 앱 아이콘 적용

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(천마 상징 확인·디자인 선택·적용 요청) |
| **When** | 2026-08-30, Asia/Seoul |
| **Where** | `feat/cheonma-brand-logo` 브랜치, Flutter 로그인 화면과 Android·iOS·Web 아이콘 |
| **Status** | 로컬 구현·검증 완료, 사용자 확인 대기 |

### **작업 개요**

**변경 내용**

- 학교의 천마 상징을 현대적으로 단순화한 심벌을 공통 브랜드 자산으로 추가했습니다.
- Android, iOS, Web 앱 아이콘을 연한 푸른 배경의 천마 아이콘으로 교체했습니다.
- 로그인 화면 상단을 작은 천마 배지와 절제된 `Y-Sync` 워드마크 조합으로 변경하고 접근성 라벨을 추가했습니다.
- 홈, 스플래시, 데스크톱 사이드바, 관리자 콘솔에 남아 있던 브랜드용 기본 아이콘을 공통 천마 배지로 통일했습니다.

**목적**

- 학교 상징성을 유지하면서 기존 로고의 장식적이고 캐릭터 같은 인상을 줄이고, 현재 글래스 UI와 일관된 브랜드 경험을 제공하기 위해서입니다.

### **구현**

- 투명 배경의 천마 심벌 원본을 Flutter asset으로 등록했습니다.
- 앱 아이콘은 `#F3F7FF` 배경에 남색·파란색 심벌을 사용하고, 로그인 화면에서는 같은 색상의 심벌을 76px 연한 배지 안에 배치해 어두운 글래스 배경과 대비시켰습니다.
- 기존 큰 텍스트 제목은 작은 워드마크로 조정하고 UI 테스트는 천마 로고의 접근성 라벨도 확인하도록 변경했습니다.

### **검증 및 추적**

**검증**

- `flutter test --no-pub`: 28개 통과
- `flutter build web --release --no-pub`: 성공
- `flutter analyze --no-pub`: 신규 경고 없음, 기존 경고 30건 유지
- iOS 1024px 아이콘 RGB·알파 없음 및 Android·Web 대표 크기 확인
- `git diff --check`: 이상 없음

**추적**

- 브랜치: `feat/cheonma-brand-logo`
- 관련 PR: 생성 후 기록

### **후속 작업**

- 모바일 실기기와 브라우저에서 홈 화면 아이콘의 마스킹 여백 및 로그인 카드 내 심벌 크기를 확인합니다.

---

## 2026-08-30 - TLS 인증서 갱신 후 Nginx 자동 반영

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(운영 인증서 장애 확인·보완 요청) |
| **When** | 2026-08-30, Asia/Seoul |
| **Where** | `fix/certbot-nginx-reload` 브랜치, Docker Compose 인증서 갱신 구성 |
| **Status** | 로컬 구성 검증 완료, 운영 반영 대기 |

### **작업 개요**

**변경 내용**

- Certbot이 인증서를 실제로 갱신한 경우 Nginx master process에 HUP 신호를 보내 새 인증서를 자동으로 다시 읽도록 구성했습니다.

**목적**

- 인증서 파일은 갱신됐지만 Nginx가 이전 인증서를 계속 제공해 수동 reload가 필요했던 운영 장애의 재발을 방지하기 위해서입니다.

### **구현**

- Certbot 컨테이너가 Nginx 컨테이너의 PID namespace를 공유하도록 설정했습니다.
- `certbot renew`의 deploy hook에서만 Nginx reload 신호를 보내 갱신이 없는 주기에는 불필요한 reload가 발생하지 않도록 했습니다.

### **검증 및 추적**

**검증**

- `docker compose -f docker/docker-compose.yml config --quiet`: 성공
- `git diff --check`: 이상 없음

**추적**

- 브랜치: `fix/certbot-nginx-reload`
- 관련 PR: 생성 후 기록

### **후속 작업**

- 운영 반영 후 Certbot 갱신 로그와 외부에서 제공되는 인증서의 일련번호·만료일이 자동으로 변경되는지 확인합니다.

---

## 2026-08-30 - 커뮤니티·공지 범용 첨부파일 지원

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(범용 첨부파일 지원 요청·검토) |
| **When** | 2026-08-30, Asia/Seoul |
| **Where** | `feat/general-attachments` 브랜치, Spring 첨부 API·Flutter 커뮤니티·공지 화면 |
| **Status** | 로컬 구현·검증 완료, 사용자 확인 대기 |

### **작업 개요**

**변경 내용**

- 커뮤니티와 공지에서 이미지·PDF·HWP/HWPX·Office 문서·TXT·ZIP을 동일한 첨부파일 흐름으로 선택하고 조회할 수 있게 했습니다.
- 이미지 전용 문구를 `첨부 파일`로 통일하고 이미지에는 미리보기, 문서에는 파일명·크기·다운로드 버튼을 표시합니다.
- 기존 `imageUrls` 응답과 구버전 `images` 업로드 파트를 유지하면서 범용 `attachments` 응답과 `files` 업로드 파트를 추가했습니다.

**목적**

- 학과에서 자주 공유하는 PDF와 HWP 문서를 서버 디스크 부담 없이 S3에 보관하고 커뮤니티·공지에서 일관되게 제공하기 위해 구현했습니다.

### **구현**

- 첨부 레코드에 원본 파일명·MIME 타입·크기를 저장하고 일반 파일 다운로드 시 원본 파일명이 적용된 Presigned URL을 발급합니다.
- 실행 파일 형식을 차단하고 파일당 20MB, 게시물당 10개·총 50MB 제한을 프런트와 백엔드에 함께 적용했습니다.
- 기존 이미지 데이터는 메타데이터가 없어도 확장자로 판별해 계속 미리보기로 노출합니다.

### **검증 및 추적**

**검증**

- `./gradlew test bootJar`: 성공
- 첨부 형식·크기 검증과 Presigned 다운로드 단위 테스트: 통과
- `flutter analyze --no-pub`: 신규 경고 없음
- `flutter test --no-pub`: 28개 통과
- `flutter build web --release --no-pub`: 성공
- `git diff --check`: 이상 없음

**추적**

- 기능 커밋: `746d15c` (`feat: 커뮤니티와 공지에 범용 첨부파일 지원`)
- 관련 PR: 생성 후 기록

### **후속 작업**

- 운영 반영 후 이미지, PDF, HWP 파일을 각각 업로드하고 이미지 미리보기와 원본 파일명 다운로드를 확인합니다.

---

## 2026-08-28 - AWS S3 파일 저장소 연동

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(S3 도입 결정·AWS 리소스 구성·검토) |
| **When** | 2026-08-28, Asia/Seoul |
| **Where** | `feat/aws-s3-storage` 브랜치, Spring 파일 저장소·운영 배포 설정 |
| **Status** | 로컬 구현·검증 완료, PR 준비 |

### **작업 개요**

**변경 내용**

- 신규 업로드 파일을 비공개 S3 버킷에 저장하고, 애플리케이션 경유 Presigned URL로 조회하도록 파일 저장소를 확장했습니다.
- 기존 로컬 `/uploads` 파일은 유지하면서 신규 S3 파일에는 `/s3-uploads` 경로를 사용하도록 단계적으로 분리했습니다.
- 운영 배포 워크플로와 Docker Compose에 S3 저장소 설정을 전달하도록 구성했습니다.

**목적**

- 이미지와 향후 문서 첨부파일이 애플리케이션 서버 디스크를 점유하지 않도록 저장소를 분리하고, 서버 교체·재배포 시에도 파일을 보존하기 위해 진행했습니다.

### **구현**

- `STORAGE_PROVIDER` 값에 따라 로컬 또는 S3 구현체가 선택되도록 조건부 빈을 구성했습니다.
- S3 객체 키는 `uploads/{UUID}.{확장자}` 형식으로 생성하고, 다운로드 요청은 5분 유효 Presigned URL로 리다이렉트합니다.
- 운영 환경의 버킷명·리전은 GitHub Variables에서, AWS 자격 증명은 Secrets에서 주입합니다.

### **검증 및 추적**

**검증**

- S3 서비스·컨트롤러 단위 테스트 통과
- `./gradlew test bootJar` 성공
- S3 모드 `docker compose config --quiet` 성공
- `git diff --check` 이상 없음

**추적**

- 기능 커밋: `df90726` (`feat: AWS S3 파일 저장소 연동`)
- 관련 PR: 생성 후 기록

### **후속 작업**

- 운영 배포 후 앱에서 파일을 업로드하고 S3 `uploads/` 객체 생성 및 조회 리다이렉트를 확인합니다.
- 현재 단계는 기존 이미지 업로드 경로 연동이며 PDF·HWP 등 일반 첨부파일의 데이터 모델·API·UI는 별도 기능으로 구현합니다.

---

## 작성 템플릿

```markdown
## YYYY-MM-DD - 작업 제목

| 항목 | 내용 |
|---|---|
| **Who** | 요청·검토자 등 실제 사람의 이름과 역할 |
| **When** | 작업 및 검증 일시, 시간대 |
| **Where** | 대상 환경, 브랜치, 주요 모듈 |
| **Status** | 로컬 완료 / PR 진행 / 병합 / 운영 배포 / 롤백 |

### **작업 개요**

**변경 내용**

- 변경한 기능, 코드, 설정, 문서

**목적**

- 문제 증상, 요구사항, 변경 목적

### **구현**

- 핵심 구현 방식과 작업 순서

### **검증 및 추적**

**검증**

- 실행한 테스트·빌드와 결과

**추적**

- 관련 커밋, PR, Actions 실행 링크

### **후속 작업**

- 남은 위험과 다음 점검 항목
```

### 작성 규칙

1. 논리적 작업 단위 하나당 항목 하나를 작성합니다.
2. 추측 대신 확인된 사실과 실행 결과를 기록합니다.
3. 코드 커밋 후 해당 해시를 기록하고 별도 문서 커밋으로 남깁니다.
4. PR 병합, 운영 승인, 배포 또는 롤백이 발생하면 기존 항목의 상태를 갱신합니다.
5. 실패한 검증이나 미해결 위험도 삭제하지 않고 현재 상태로 남깁니다.
6. `Who`에는 실제 사람 이름만 기록하며 AI·에이전트·도구 이름은 기록하지 않습니다.

---

## 2026-08-28 - 메인 화면 글래스 UI 및 삭제 댓글 활동 내역 개선

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(디자인 변경·댓글 정책 요청 및 검토) |
| **When** | 2026-08-28, Asia/Seoul |
| **Where** | `feat/community-light-glass` 브랜치, Flutter 메인 화면·댓글 활동 내역, 회원 댓글 API |
| **Status** | 로컬 구현·검증 완료, `main` 대상 PR 준비 |

### **작업 개요**

**변경 내용**

- 커뮤니티·공지 필터를 개별 반투명 글래스 버튼으로 변경하고 모바일 하단 내비게이션과 작성 버튼의 겹침을 해소했습니다.
- 댓글 생성·삭제 후 내정보 데이터를 즉시 갱신하고, 본인이 삭제한 댓글은 활동 내역에서 제외하되 관리자 삭제 댓글은 사유 확인을 위해 유지했습니다.

**목적**

- 메인 화면의 시각적 통일성을 높이고, 삭제된 댓글이 내 활동 목록에 오래 남거나 갱신되지 않는 문제를 해결하기 위해 진행했습니다.

### **구현**

- 공용 필터 위젯에 개별 블러·투명 배경·테두리를 적용하고 커뮤니티와 공지 화면에서 동일하게 사용했습니다.
- 모바일 하단 내비게이션을 반투명 처리하고 커뮤니티·공지·일정·시간표 작성 버튼에 하단 여백을 적용했습니다.
- 댓글 변경 시 `myPageProvider`를 무효화하고 내 댓글 화면이 최신 상태를 직접 구독하도록 변경했습니다.
- 회원 댓글 API와 프런트 양쪽에서 작성자 삭제 댓글을 제외하고 관리자 삭제 댓글을 유지하도록 필터링했습니다.

### **검증 및 추적**

**검증**

- `flutter analyze --no-pub` 관련 파일 분석: 이상 없음
- `flutter test --no-pub test/main_sections_design_test.dart`: 3개 통과
- `flutter test --no-pub test/activity_settings_design_test.dart`: 5개 통과
- `./gradlew test --tests com.ync.ysync.controller.BooleanJsonContractTest`: 성공
- `git diff --check`: 이상 없음

**추적**

- 기능 커밋: `140bf9c` (`feat: 메인 화면에 글래스 UI 적용`)
- 버그 수정 커밋: `2eee461` (`fix: 삭제 댓글 활동 내역 즉시 반영`)
- 관련 PR: 생성 후 기록

### **후속 작업**

- 운영 반영 시 프런트와 백엔드를 함께 배포하고, 작성자 삭제 댓글 제외 및 관리자 삭제 사유 노출을 확인합니다.
- 실제 모바일 화면에서 하단 내비게이션과 작성 버튼의 안전 영역을 최종 확인합니다.

---

## 2026-08-27 - GitHub PR·Issue 템플릿 추가

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(협업 템플릿 추가 요청·검토) |
| **When** | 2026-08-27, Asia/Seoul |
| **Where** | `docs/work-log-template` 브랜치, GitHub PR·Issue 작성 화면 |
| **Status** | PR #29·릴리스 PR #30 병합, GitHub 기본 브랜치 반영 완료 |

### **작업 개요**

**변경 내용**

- 변경 목적·검증·영향·배포 정보를 받는 PR 템플릿과 버그 신고·기능 요청 Issue Form을 추가했습니다.

**목적**

- 학회원이 작업 배경과 완료 조건을 빠뜨리지 않고 공유하고, 리뷰·운영에 필요한 정보를 일관된 형식으로 남기기 위해 추가했습니다.

### **구현**

- PR 템플릿에는 변경 유형, 검증, 영향 범위, 배포·복구, 보안 체크리스트를 구성했습니다.
- 버그 양식에는 발생 환경·재현 방법·기대/실제 결과를, 기능 양식에는 문제·제안·완료 조건·제외 범위·정책 영향을 필수 또는 선택 항목으로 구성했습니다.

### **검증 및 추적**

**검증**

- YAML 문법 검사, 필수 필드와 민감정보 경고 확인, `git diff --check`를 수행했습니다.

**추적**

- 브랜치 `docs/work-log-template`, 문서 커밋 `925bdad`·`c3184ce`, 통합 커밋 `0a7b1a0`, PR #29, 릴리스 PR #30, `main` 병합 커밋 `eaa031b`

### **후속 작업**

- 기본 브랜치의 템플릿 파일 반영을 확인했습니다. 새 PR과 Issue 생성 시 실제 입력 화면을 사용자 관점에서 한 번 확인합니다.

---

## 2026-08-27 - WORK_LOG 구조화 템플릿 개편

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(템플릿 개편 요청·검토) |
| **When** | 2026-08-27, Asia/Seoul |
| **Where** | `docs/work-log-template` 브랜치, `README.md`, `docs/WORK_LOG.md`, `docs/DEVELOPMENT.md` |
| **Status** | PR #29·릴리스 PR #30 병합, `docs` 경로 운영 기준 반영 완료 |

### **작업 개요**

**변경 내용**

- 기본 정보는 표로 요약하고 육하원칙과 검증·추적 항목은 관련 내용끼리 묶는 작업 기록 템플릿으로 개편했습니다.
- 기존 작업 기록의 `Who` 항목에서 AI·에이전트 이름을 제거했습니다.
- 프로젝트 문서 디렉터리 이름을 `ai_prompt`에서 `docs`로 변경하고 내부 링크를 갱신했습니다.

**목적**

- 긴 한 줄 형식보다 항목별 내용을 빠르게 찾을 수 있게 하고, 작업 책임 표기에는 실제 사람만 남기기 위해 변경했습니다.
- 문서가 AI 전용 프롬프트가 아니라 개발자 모두가 사용하는 프로젝트 자료임을 디렉터리 이름에 명확히 나타내기 위해 변경했습니다.

### **구현**

- `Who`, `When`, `Where`, `Status`는 표로 요약하고 육하원칙 본문은 작업 개요·구현·검증 및 추적·후속 작업으로 묶어 작성 규칙을 동기화했습니다.
- Git으로 문서 디렉터리를 이동한 뒤 README와 문서 내부의 기존 경로를 `docs`로 변경했습니다.

### **검증 및 추적**

**검증**

- 문서 구조와 기존 `Who` 항목을 확인하고, 구 경로 참조가 남아 있지 않은지 검사한 뒤 `git diff --check`를 통과했습니다.

**추적**

- 브랜치 `docs/work-log-template`, 문서 커밋 `925bdad`·`c3184ce`, 통합 커밋 `0a7b1a0`, PR #29, 릴리스 PR #30, `main` 병합 커밋 `eaa031b`

### **후속 작업**

- 전체 기존 기록을 새 혼합형 템플릿으로 변환했으며, 이후 기록도 동일한 구조를 유지해야 합니다.

---

## 2026-08-27 - 댓글 소프트 삭제 및 삭제 주체별 표시 구현

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(초기 백엔드 구현·완성 요청·검토) |
| **When** | 2026-08-27, Asia/Seoul |
| **Where** | `fix/comment-soft-delete` 브랜치, Flutter 댓글 모델·댓글 UI와 Spring 댓글 도메인·서비스 |
| **Status** | PR #28·릴리스 PR #30 병합, 운영 배포와 기본 헬스 체크 완료 |

### **작업 개요**

**변경 내용**

- 작성자 댓글 삭제를 원문 보존형 소프트 삭제로 전환하고 일반 응답에서 원문·작성자 정보를 마스킹했습니다. Flutter는 `deletedBy`를 파싱해 작성자 삭제와 관리자 삭제 안내 문구·색상을 구분하며 구형 응답도 호환합니다.

**목적**

- 소프트 삭제된 댓글의 삭제 주체를 사용자 화면에서 구분하고 비방·신고 처리에 필요한 원문을 보존하기 위해 변경했습니다.

### **구현**

- 댓글 엔티티는 삭제 상태·주체·사유만 변경하고 댓글 원문과 관계를 유지합니다. 서비스는 최초 삭제에서만 댓글 수를 감소시키며 관리자 삭제는 사유가 필요한 전용 API로 제한했습니다. 일반 DTO는 삭제된 원문과 작성자를 마스킹하고 Flutter UI는 삭제 주체별 문구를 표시합니다.

### **검증 및 추적**

**검증**

- 백엔드 `./gradlew compileJava` 성공, 변경한 Dart 파일 2개의 포맷 확인 및 정적 분석 통과, `git diff --check` 통과, PR #28·#30의 Backend·Frontend·Configuration·Gate 통과, 운영 API 정상 응답과 PWA HTTP 200·캐시 헤더 확인

**추적**

- 코드 커밋 `89a4cf2`, 문서 커밋 `4f0249f`, PR #28, `develop` 병합 커밋 `e65b444`, 릴리스 PR #30, `main` 병합 커밋 `eaa031b`, 릴리스 CI `33041269931`, Production Deploy `33041406555`

### **후속 작업**

- 자동 배포와 헬스 체크는 통과했습니다. 작성자 삭제·관리자 삭제·중복 삭제·관리자 복구 흐름은 운영 계정으로 직접 확인해야 합니다.

---

## 2026-08-26 - 댓글 소프트 삭제 구현 골격 작성

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(직접 구현 방식 요청·검토) |
| **When** | 2026-08-26, Asia/Seoul |
| **Where** | `fix/comment-soft-delete` 브랜치, 댓글 도메인·서비스·응답 DTO·Flutter 댓글 UI |
| **Status** | 후속 구현 및 PR #28 `develop` 병합 완료 |

### **작업 개요**

**변경 내용**

- 작성자 댓글 삭제를 증거 보존형 소프트 삭제로 전환하기 위한 구현 위치와 요구 조건을 한국어 `TODO` 주석으로 표시했습니다.

**목적**

- 관리자 삭제와 달리 작성자 본인 삭제가 DB 물리 삭제였으므로 후속 구현 범위를 명확히 하기 위해 작성했습니다.

### **구현**

- 기존 동작은 변경하지 않고 상태 변경, 중복 댓글 수 감소 방지, 공개 응답 원문 마스킹, 삭제 주체별 UI 문구 위치를 지정했습니다.

### **검증 및 추적**

**검증**

- 코드 동작 변경이 없는 주석 골격이므로 테스트는 생략하고 `git diff --check`를 확인했습니다.

**추적**

- `fix/comment-soft-delete` 브랜치의 구현 준비 기록, 후속 코드 커밋 `89a4cf2`

### **후속 작업**

- TODO 범위는 후속 구현으로 완료됐으며 운영 배포 후 실제 삭제·복구 흐름을 확인해야 합니다.

---

## 2026-08-26 - 공지·커뮤니티 조회수 집계 경로 정합성 개선

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(기능 점검·개선 요청) |
| **When** | 2026-08-26, Asia/Seoul |
| **Where** | `fix/content-filter-flicker` 브랜치, Spring Boot 공지·커뮤니티 서비스와 Flutter 목록·홈·내 글 화면 |
| **Status** | 로컬 구현·최소 검증·코드 커밋 완료 |

### **작업 개요**

**변경 내용**

- 공지사항과 커뮤니티 게시글의 상세 화면 진입 시 조회수가 증가하도록 주요 진입 경로를 상세 조회 API로 통일하고, 수정·삭제 처리에서는 조회수가 증가하지 않도록 분리했습니다.

**목적**

- 목록·홈·내 글에서 이미 받은 게시글 객체를 상세 화면에 바로 전달해 실제 열람에도 조회수가 증가하지 않았고, 반대로 일부 수정·삭제 작업은 상세 조회 메서드를 재사용해 조회수가 증가했기 때문입니다.

### **구현**

- 사용자 상세 진입은 기존 상세 로딩 화면을 거쳐 GET 상세 API를 한 번 호출하고, 백엔드 수정·삭제는 조회수 증가가 없는 저장소 조회 메서드를 사용하도록 변경했습니다.

### **검증 및 추적**

**검증**

- 백엔드 `./gradlew compileJava` 성공, 변경 Flutter 화면 대상 `flutter analyze` 오류·경고 없음, `git diff --check` 통과

**추적**

- 브랜치 `fix/content-filter-flicker`, 코드 커밋 `28f7d41`, PR #26

### **후속 작업**

- 현재 정책은 같은 사용자가 같은 글을 다시 열어도 매번 1회 증가합니다. 사용자·일자별 중복 제거가 필요하면 별도 저장 구조와 정책 설계가 필요합니다.

---

## 2026-08-26 - 커뮤니티 자기 글 수정 및 macOS Java 환경 점검

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(기능 추가·환경 점검 요청) |
| **When** | 2026-08-26, Asia/Seoul |
| **Where** | `fix/content-filter-flicker` 브랜치, 커뮤니티 API·Flutter 작성/상세 화면·Android Gradle 설정·macOS 셸 환경 |
| **Status** | 로컬 구현·최소 컴파일 검증·코드 커밋 완료 |

### **작업 개요**

**변경 내용**

- 작성자 본인에게만 커뮤니티 게시글 수정 버튼과 수정 API를 제공하고 제목·내용·카테고리·학년·익명 여부·이미지 교체를 지원했습니다. 댓글은 비방 내용의 사후 변경을 막기 위해 수정 기능을 추가하지 않기로 했습니다. 프로젝트의 Windows 전용 Android Java 경로 고정값을 제거했습니다.

**목적**

- 커뮤니티 글은 삭제만 가능하고 수정할 수 없었으며, Windows 절대경로가 macOS Android 빌드 설정에 남아 있었기 때문입니다.

### **구현**

- 기존 작성 화면을 수정 화면으로 재사용하고 백엔드에서 로그인 회원과 작성자 ID를 비교합니다. 새 이미지를 선택하지 않으면 기존 이미지를 유지합니다. Gradle은 저장소에 개인 경로를 기록하지 않고 셸 `JAVA_HOME`을 사용하게 했습니다.

### **검증 및 추적**

**검증**

- 실제 JDK 21 경로를 지정한 `./gradlew compileJava`가 통과했고 변경 Flutter 파일 정적 분석에서 오류·경고 없이 기존 `http_parser` 직접 의존성 정보 1건만 확인했습니다. Android는 JDK 20과 Java/Kotlin 17 타깃으로 디버그 APK 빌드가 통과했습니다.

**추적**

- 브랜치 `fix/content-filter-flicker`, 코드 커밋 `bd4a152`, PR·배포 전

### **후속 작업**

- `~/.zprofile`에 `JavaVirtualMachine` 단수 경로 오타가 남아 있어 `JavaVirtualMachines`로 수정해야 합니다. IntelliJ IDEA 2023.2.8의 Android Gradle JVM은 설치된 JDK 20으로 지정해야 합니다. 본인 댓글은 현재 물리 삭제되므로 신고 증거 보존을 위해 추후 소프트 삭제 전환이 필요합니다.

---

## 2026-08-26 - 콘텐츠 필터 선택 깜빡임 수정

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(운영 화면 증상 제보) |
| **When** | 2026-08-26, Asia/Seoul |
| **Where** | `fix/content-filter-flicker` 브랜치, Flutter 공용 콘텐츠 필터 위젯 |
| **Status** | 로컬 수정·코드 커밋 완료 |

### **작업 개요**

**변경 내용**

- 필터 선택 변경 시 이전 항목과 새 항목이 동시에 깜빡이는 시각 현상을 제거했습니다.

**목적**

- 선택 상태가 바뀔 때 두 항목의 배경 전환 애니메이션과 터치 리플이 함께 표시됐기 때문입니다.

### **구현**

- 선택 배경을 즉시 갱신하는 일반 컨테이너로 바꾸고 필터의 스플래시·하이라이트 효과를 비활성화했습니다.

### **검증 및 추적**

**검증**

- Dart 포맷과 `git diff --check`를 확인했습니다. 단순 시각 효과 수정이며 사용자 요청에 따라 별도 테스트는 실행하지 않았습니다.

**추적**

- 브랜치 `fix/content-filter-flicker`, 코드 커밋 `bd4a152`, PR·배포 전

### **후속 작업**

- 운영 반영 후 실제 PWA에서 선택 상태가 즉시 전환되는지 확인합니다.

---

## 2026-08-25 - 프로젝트 대표 README 작성

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(문서 작성 요청) |
| **When** | 2026-08-25, Asia/Seoul |
| **Where** | `fix/content-filter-usability` 브랜치, 저장소 루트 `README.md` |
| **Status** | 로컬 문서 작성 완료 |

### **작업 개요**

**변경 내용**

- 서비스 소개, 주요 기능, 기술 스택, 시스템 구성, 로컬 실행·검증 방법, 브랜치·배포 절차와 상세 문서 링크를 포함한 프로젝트 대표 README를 작성했습니다.

**목적**

- 저장소 첫 화면에서 Y-Sync의 목적과 개발·운영 구조를 빠르게 이해할 수 있는 안내 문서가 없었기 때문입니다.

### **구현**

- 실제 Gradle·Flutter·Docker·GitHub Actions 설정과 `docs` 명세를 기준으로 내용을 구성하고 비밀값은 예시 자리표시자로만 안내했습니다.

### **검증 및 추적**

**검증**

- Markdown 구조, 저장소 상대 링크, 명령 경로와 `git diff --check`를 확인했습니다. 문서 작업이므로 애플리케이션 테스트는 실행하지 않았습니다.

**추적**

- 브랜치 `fix/content-filter-usability`, 커밋·PR 전

### **후속 작업**

- 기능·실행 환경이 변경되면 README의 기능 목록과 요구 버전을 함께 갱신해야 합니다.

---

## 2026-08-25 - 공지·커뮤니티 필터 사용성 보완

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(UI 개편 요청) |
| **When** | 2026-08-25, Asia/Seoul |
| **Where** | `fix/content-filter-usability` 브랜치, Flutter 공용 콘텐츠 필터 위젯 |
| **Status** | 로컬 구현·정적 분석·코드 커밋 완료 |

### **작업 개요**

**변경 내용**

- 공지사항과 커뮤니티의 학년·카테고리 필터를 가로 스크롤형 버튼에서 전체 선택지가 한 화면에 보이는 4분할 선택 컨트롤로 변경하고 높이를 44px로 확대했습니다.

**목적**

- 기존 필터는 선택지가 화면 밖에 숨을 수 있고 터치 영역이 작아 모바일에서 탐색성과 조작성이 떨어졌기 때문입니다.

### **구현**

- `ContentFilterBar`의 공개 인터페이스는 유지하고 내부 레이아웃만 균등 분할 구조로 교체해 두 목록에 함께 반영했습니다. 선택 상태는 옅은 브랜드 배경과 파란 글자로 구분했습니다.

### **검증 및 추적**

**검증**

- 변경 위젯과 공지·커뮤니티 목록을 대상으로 `flutter analyze`를 실행해 이슈가 없음을 확인했습니다. 사용자 요청에 따라 별도 위젯·전체 테스트는 실행하지 않았습니다.

**추적**

- 브랜치 `fix/content-filter-usability`, 코드 커밋 `4c9ca22`, PR·배포 전

### **후속 작업**

- 매우 좁은 화면에서는 긴 필터 문구가 말줄임될 수 있어 운영 배포 전 실제 모바일 화면에서 한 차례 시각 확인합니다.

---

## 2026-08-25 - 공지·커뮤니티 필터 디자인 개편

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(디자인 개선 요청·운영 확인) |
| **When** | 2026-08-25, Asia/Seoul |
| **Where** | `fix/content-filter-design` 브랜치, Flutter 공지·커뮤니티 목록 |
| **Status** | 로컬 구현·코드 커밋 완료 |

### **작업 개요**

**변경 내용**

- 학년·카테고리의 큰 사각 선택 버튼을 공통 pill 필터로 교체했습니다.

**목적**

- 기존 버튼이 크고 무거워 보이며 커뮤니티의 카테고리·학년 구분도 직관적이지 않았기 때문입니다.

### **구현**

- 파란 선택 상태, 얇은 테두리의 미선택 상태와 짧은 전환 애니메이션을 적용하고 커뮤니티 필터를 `분류`와 `학년` 두 줄로 분리했습니다.

### **검증 및 추적**

**검증**

- 사용자 요청에 따라 테스트는 생략하고 Dart 포맷과 `git diff --check`를 확인했습니다.

**추적**

- 코드 커밋 `7a01628`, PR·배포 정보는 완료 후 갱신 예정

### **후속 작업**

- 작은 모바일 화면에서 가로 스크롤과 터치 영역을 운영 배포 후 직접 확인합니다.

---

## 2026-08-25 - 소셜 로그인 준비 안내 및 공지사항 탭 복구

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(기능 범위 결정·운영 확인 예정) |
| **When** | 2026-08-25, Asia/Seoul |
| **Where** | `fix/login-notice-navigation` 브랜치, Flutter 로그인 화면·홈 화면·메인 내비게이션 |
| **Status** | PR #19·릴리스 PR #20 병합, Firebase Hosting 운영 배포와 번들 검증 완료 |

### **작업 개요**

**변경 내용**

- Google 로그인 버튼은 유지하되 비활성화된 인증 API 대신 추후 지원 안내창을 표시하도록 변경하고, 메인 내비게이션에 독립된 공지사항 탭을 복구했습니다.

**목적**

- 백엔드에서 비활성화된 소셜 로그인 호출이 사용자에게 실패로 노출됐고, 메인 탭 개편 후 공지사항이 홈의 전체 보기 경로에만 남아 직접 접근 메뉴가 사라졌기 때문입니다.

### **구현**

- Google 버튼 동작을 안내 다이얼로그로 교체하고, 모바일 하단 메뉴를 `홈·공지·커뮤니티·일정·내정보`로 구성했습니다. 데스크톱 사이드바에도 공지사항을 추가하고 홈의 최근 공지 전체 보기는 새 공지 탭을 선택하도록 연결했습니다.

### **검증 및 추적**

**검증**

- 소셜 로그인 안내 대상 위젯 테스트 5개와 수정 파일 정적 분석이 통과했습니다. 사용자 요청에 따라 작은 공지 탭 UI 변경의 추가 로컬 전체 테스트·Web 빌드는 생략했으며, PR #19·#20의 Backend·Frontend·Configuration·Gate가 모두 통과했습니다. 운영 Hosting HTTP 200, 핵심 파일 재검증 헤더와 배포 번들의 `공지`, `공지사항`, `커뮤니티`, `소셜 로그인 준비 중` 식별자를 확인했습니다.

**추적**

- 코드 커밋 `6c36a6f`, 최초 문서 커밋 `ac7b5af`, PR #19, `develop` 병합 커밋 `3cd5a62`, 기능 CI `32815524061`, 릴리스 PR #20, `main` 병합 커밋 `80544e4`, 릴리스 CI `32815740372`, Production Deploy `32815922305`

### **후속 작업**

- 모바일 하단 메뉴 5개의 작은 화면 레이블·터치 영역과 Google 안내창은 사용자가 설치형 PWA에서 직접 확인합니다. 실제 소셜 로그인은 향후 별도 기능으로 구현합니다.

---

## 2026-08-25 - Firebase Hosting PWA 캐시 갱신 정책 보완

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(운영 PWA 구버전 화면 제보) |
| **When** | 2026-08-25, Asia/Seoul |
| **Where** | `fix/pwa-cache-update` 브랜치, Firebase Hosting 설정과 Flutter 설정 회귀 테스트 |
| **Status** | PR #16 및 릴리스 PR #17 병합, Firebase Hosting 운영 배포 및 헤더 검증 완료 |

### **작업 개요**

**변경 내용**

- Flutter PWA 핵심 파일이 배포 직후 새 버전을 재검증하도록 Firebase `Cache-Control` 헤더를 추가했습니다.

**목적**

- 운영 `main.dart.js`에는 새 커뮤니티 카드 코드가 포함됐지만 앱 셸과 서비스 워커가 `max-age=3600`으로 캐시돼 설치형 PWA에는 이전 화면이 남았기 때문입니다.

### **구현**

- 앱 셸과 서비스 워커는 `no-store`까지 적용하고, 대용량 JavaScript는 ETag 조건부 재검증이 가능한 `no-cache`를 적용했습니다. JSON 설정을 직접 파싱하는 회귀 테스트로 핵심 경로의 헤더를 검증합니다.

### **검증 및 추적**

**검증**

- 운영 번들에서 새 커뮤니티 카드 식별자를 확인했고 기존 Hosting 응답의 1시간 캐시 헤더를 재현했습니다. Firebase JSON 파싱, 캐시 헤더 회귀 테스트, PR #16·#17 CI와 프론트엔드 Production Deploy가 통과했습니다. 운영의 `/`, `index.html`, 서비스 워커는 `no-cache, no-store`, 나머지 핵심 PWA 파일은 `no-cache` 응답을 확인했습니다.

**추적**

- 기능 커밋 `e0ec432`, 문서 커밋 `dc5684d`, PR #16, `develop` 병합 커밋 `571ebf1`, 릴리스 PR #17, `main` 병합 커밋 `064c349`, Actions 실행 `32812490437`

### **후속 작업**

- 이미 실행 중인 구형 서비스 워커는 최초 1회 앱 종료와 Safari 새로고침이 필요할 수 있습니다. 이후 배포부터는 핵심 파일이 즉시 재검증됩니다.

---

## 2026-08-25 - 커뮤니티 게시글 카드 구분 및 즐겨찾기 정렬 개선

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(화면 문제 제보·검토) |
| **When** | 2026-08-25, Asia/Seoul |
| **Where** | `fix/community-card-layout` 브랜치, Flutter 커뮤니티 목록 화면과 메인 섹션 위젯 테스트 |
| **Status** | PR #13 및 릴리스 PR #14 병합, Firebase Hosting 운영 배포 완료 |

### **작업 개요**

**변경 내용**

- 게시글을 독립된 흰색 카드와 테두리·간격으로 구분하고, 이미지 미리보기가 있는 게시글에서도 즐겨찾기 버튼이 일반 게시글과 같은 우측 위치에 표시되도록 재배치했습니다.

**목적**

- 기존 목록은 구분선 대비가 약해 게시글 경계가 모호했고, 즐겨찾기가 본문 열 안에 있어 썸네일이 추가되면 아이콘이 왼쪽으로 밀렸기 때문입니다.

### **구현**

- 카드 상단은 본문과 썸네일, 하단은 조회·댓글 정보와 우측 고정 즐겨찾기로 분리했습니다. 카드에 8px 모서리, 테두리와 10px 항목 간격을 적용하고 이미지·일반 카드의 즐겨찾기 좌표와 카드 간 간격을 위젯 테스트로 검증했습니다.

### **검증 및 추적**

**검증**

- 수정 파일 대상 Flutter 분석에서 이슈가 없었고, 메인 섹션 위젯 테스트 3개와 Flutter 전체 테스트 25개가 통과했습니다. Flutter Web 릴리스 빌드와 PR #13·#14 CI가 성공했습니다. Production Deploy에서 백엔드는 건너뛰고 프론트엔드만 배포했으며, 운영 Hosting의 배포 완료 시각 갱신과 HTTP `200` 응답을 확인했습니다.

**추적**

- 기능 커밋 `633ff06`, 문서 커밋 `7ab06b5`, PR #13, `develop` 병합 커밋 `5cb83fc`, 릴리스 PR #14, `main` 병합 커밋 `0fcd04a`, Actions 실행 `32810572003`

### **후속 작업**

- 실제 운영 이미지의 종횡비와 긴 제목 조합은 배포 후 모바일 실기기에서 한 차례 시각 점검합니다.

---

## 2026-08-25 - 알림 계약 및 개인 시간표 운영 배포

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(운영 배포 승인) |
| **When** | 2026-08-25, Asia/Seoul |
| **Where** | GitHub `develop`·`main`, GitHub Actions `production` 환경, Oracle Cloud 운영 VM·MySQL, Firebase Hosting |
| **Status** | 백엔드·프론트엔드 운영 배포 및 스모크 테스트 완료 |

### **작업 개요**

**변경 내용**

- boolean JSON 계약 수정과 모바일 달력·개인 시간표 기능을 백엔드와 프론트엔드 운영 환경에 함께 배포했습니다.

**목적**

- 기능 PR #9와 #10에서 검증된 알림 상태 계약 및 일정 사용성 개선을 실제 사용자 환경에 반영하기 위해서입니다.

### **구현**

- 운영 MySQL 사전 백업과 압축 무결성을 확인하고 `develop`에서 `main`으로 릴리스 PR을 생성했습니다. 릴리스 CI 통과 후 `main`에 병합하고 GitHub `production` Environment를 승인해 Oracle VM과 Firebase Hosting 자동 배포를 실행했습니다.

### **검증 및 추적**

**검증**

- 릴리스 PR의 Backend·Frontend·Configuration·Gate와 Production Deploy 전체 단계가 통과했습니다. 운영 Spring Boot가 89.5초에 기동되고 Firebase 초기화 성공, HTTPS API와 Hosting `200`, 새 개인 시간표 테이블 생성을 확인했습니다. 테스트 사용자로 개인 수업 생성·수정·조회·삭제를 검증했으며 종료 후 임시 데이터는 0건입니다.

**추적**

- PR #10 병합 커밋 `7914c12`, 릴리스 PR #11, `main` 병합 커밋 `809cdf6`, Actions 실행 `32808434514`

### **후속 작업**

- 사전 백업은 운영 서버에 보관 중입니다. 동일 사용자가 완전히 동시에 중복 수업을 생성하는 경쟁 조건은 DB 제약 또는 잠금으로 보강할 수 있습니다.

---

## 2026-08-25 - 모바일 학사 달력 및 개인 시간표 기능 개선

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(요구사항 확인·검토) |
| **When** | 2026-08-25, Asia/Seoul |
| **Where** | `feat/schedule-personal-timetable` 브랜치, Flutter 일정 화면, Spring Boot 시간표 API, MySQL/H2 시간표 도메인 |
| **Status** | PR #10 및 릴리스 PR #11 병합, 백엔드·프론트엔드 운영 배포 완료 |

### **작업 개요**

**변경 내용**

- 모바일 학사 달력의 마지막 주 날짜 잘림을 수정하고, 기존 `과 시간표` 화면을 `학과 시간표`와 `개인 시간표`로 분리했습니다. 학생이 자신의 수업을 추가·수정·삭제할 수 있는 회원별 개인 시간표 API와 UI를 추가했습니다.

**목적**

- 고정 높이 비율 때문에 월간 달력 하단이 가려졌고, 학과 공용 시간표만으로는 학생 개별 수강 구성을 반영할 수 없었기 때문입니다.

### **구현**

- 모바일 달력을 6주 고정 높이의 비스크롤 카드로 배치하고 일정 목록만 남은 공간을 사용하게 했습니다. 백엔드에는 `PersonalTimetableEntry` 엔티티와 회원 소유권·교시 중복 검증 CRUD를 만들고, Flutter에는 학과/개인 모드 전환과 개인 수업 편집 다이얼로그를 연결했습니다.

### **검증 및 추적**

**검증**

- 최종 변경 후 `PersonalTimetableServiceIntegrationTest`와 `main_sections_design_test.dart` 3개 테스트가 통과했습니다. 구현 완료 시점의 백엔드 전체 테스트·`bootJar`, Flutter 전체 25개 테스트·Web 릴리스 빌드가 통과했고, Flutter 분석은 기존 경고/정보 32건만 남았습니다. 운영에서 새 테이블과 개인 시간표 CRUD를 확인하고 임시 데이터를 삭제했습니다.

**추적**

- 기능 커밋 `3d024ab`, 문서 커밋 `126ca96`, PR #10, `develop` 병합 커밋 `7914c12`, 릴리스 PR #11, `main` 병합 커밋 `809cdf6`

### **후속 작업**

- 동일 사용자가 완전히 동시에 중복 수업을 생성하는 경쟁 조건은 DB 제약 또는 잠금 보강을 후속 검토합니다.

---

## 2026-08-25 - 운영 일반 테스트 계정 생성

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(계정 규격 지정) |
| **When** | 2026-08-25, Asia/Seoul |
| **Where** | Oracle Cloud 운영 MySQL, 운영 API, macOS Keychain |
| **Status** | 운영 생성 및 로그인 검증 완료 |

### **작업 개요**

**변경 내용**

- 관리자 권한이 없는 활성 테스트 계정 `9999999`를 `USER` 권한으로 생성했습니다.

**목적**

- 관리자 기능과 분리된 실제 학생 관점의 화면 및 API 동작을 운영 환경에서 점검하기 위해서입니다.

### **구현**

- 비밀번호는 BCrypt 해시만 DB에 저장하고 원문은 Keychain 서비스 `y-sync-production-test-user`에 보관했습니다. 최초 SQL 전달은 원격 셸 따옴표 오류로 DB 변경 없이 중단됐으며, 표준입력 방식으로 다시 적용했습니다. 먼저 만든 임시 학번 `9900001`은 `9999999`로 변경해 중복 테스트 계정을 남기지 않았습니다.

### **검증 및 추적**

**검증**

- DB에서 `USER`, 활성화, 미차단 상태를 확인하고 운영 로그인 API와 `/api/v1/members/me` 응답의 학번·권한을 검증했습니다.

**추적**

- 운영 작업, 브랜치 `fix/boolean-json-contracts`, PR #9 문서 기록

### **후속 작업**

- 공용 테스트 비밀번호이므로 실제 개인정보나 민감한 게시물을 작성하지 않으며, 외부 공개 테스트가 끝나면 비밀번호 회전 또는 계정 삭제가 필요합니다.

---

## 2026-08-25 - 육하원칙 작업 기록 체계 도입

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(요청·검토) |
| **When** | 2026-08-25, Asia/Seoul |
| **Where** | `fix/boolean-json-contracts` 브랜치, `docs/DEVELOPMENT.md`, `docs/WORK_LOG.md` |
| **Status** | PR #9 및 릴리스 PR #11 병합, 운영 배포 완료 |

### **작업 개요**

**변경 내용**

- 모든 개발·운영 작업을 육하원칙과 검증·배포 상태로 기록하는 공통 템플릿과 강제 규칙을 추가했습니다.

**목적**

- 작업 배경, 구현 방식, 검증 결과와 실제 배포 여부가 대화에만 남아 이후 유지보수 시 누락되는 문제를 방지하기 위해서입니다.

### **구현**

- 최신순 작업 원장을 만들고 개발 표준에 기록 시점, 필수 항목, 후속 상태 갱신, 비밀값 제외 원칙을 연결했습니다.

### **검증 및 추적**

**검증**

- Markdown 구조, 저장소 상대 링크, `git diff --check`를 확인합니다.

**추적**

- 브랜치 `fix/boolean-json-contracts`, PR #9, `develop` 병합 커밋 `15f6187`

### **후속 작업**

- 이후 작업도 동일한 육하원칙과 검증·추적 규칙으로 기록합니다.

---

## 2026-08-25 - boolean JSON 상태 필드 계약 통일

| 항목 | 내용 |
|---|---|
| **Who** | 배진수(문제 확인·검토) |
| **When** | 2026-08-25, Asia/Seoul |
| **Where** | `fix/boolean-json-contracts` 브랜치, Spring Boot 응답 DTO와 Flutter API 모델 |
| **Status** | PR #9 및 릴리스 PR #11 병합, 운영 배포 완료 |

### **작업 개요**

**변경 내용**

- `isPinned`, `isDeleted`, `isAuthorSuspended` JSON 키를 명시적으로 고정하고 Flutter에 구형 축약 키 fallback을 추가했습니다. API·아키텍처·개발·운영·문제 해결 문서도 현재 구성에 맞게 갱신했습니다.

**목적**

- Lombok/Jackson이 `isX` 필드를 `x`로 직렬화해 DB 상태가 정상이어도 Flutter 화면에서 고정·삭제·정지 상태가 `false`로 보일 수 있었기 때문입니다.

### **구현**

- 백엔드에 `@JsonProperty`와 요청용 `@JsonAlias`를 적용하고, Flutter는 공식 `isX` 키를 우선 파싱하도록 수정했습니다. 양쪽에 계약 회귀 테스트를 추가했습니다.

### **검증 및 추적**

**검증**

- 백엔드 `./gradlew test bootJar` 통과, Flutter 전체 테스트 25개 및 Web 릴리스 빌드 통과, GitHub CI Backend·Frontend·Configuration·Gate 통과

**추적**

- 코드 커밋 `4c2263f`, 문서 커밋 `71aa825`, PR #9, `develop` 병합 커밋 `15f6187`, 릴리스 PR #11, `main` 병합 커밋 `809cdf6`

### **후속 작업**

- 단계적 배포 호환을 위한 구형 키 fallback은 모든 지원 클라이언트가 신형 계약으로 전환된 후 제거 여부를 검토합니다.
