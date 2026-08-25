# Y-Sync 작업 이력

이 문서는 기능 개발, 버그 수정, 운영 설정 변경, 배포 및 장애 대응 이력을 육하원칙으로 기록하는 작업 원장입니다. 최신 작업을 위에 추가하며 비밀번호, 토큰, 개인키, 서비스 계정 원문과 개인정보는 기록하지 않습니다.

---

## 작성 템플릿

```markdown
## YYYY-MM-DD - 작업 제목

- **누가(Who)**: 요청·검토자와 작업 수행자
- **언제(When)**: 작업 및 검증 일시, 시간대
- **어디서(Where)**: 대상 환경, 브랜치, 주요 모듈
- **무엇을(What)**: 변경한 기능, 코드, 설정, 문서
- **왜(Why)**: 문제 증상, 요구사항, 변경 목적
- **어떻게(How)**: 핵심 구현 방식과 작업 순서
- **검증(Verification)**: 실행한 테스트·빌드와 결과
- **추적(Tracking)**: 관련 커밋, PR, Actions 실행 링크
- **상태(Status)**: 로컬 완료 / PR 진행 / 병합 / 운영 배포 / 롤백
- **위험 및 후속 작업(Risks/Follow-up)**: 남은 위험과 다음 점검 항목
```

### 작성 규칙

1. 논리적 작업 단위 하나당 항목 하나를 작성합니다.
2. 추측 대신 확인된 사실과 실행 결과를 기록합니다.
3. 코드 커밋 후 해당 해시를 기록하고 별도 문서 커밋으로 남깁니다.
4. PR 병합, 운영 승인, 배포 또는 롤백이 발생하면 기존 항목의 상태를 갱신합니다.
5. 실패한 검증이나 미해결 위험도 삭제하지 않고 현재 상태로 남깁니다.

---

## 2026-08-25 - 모바일 학사 달력 및 개인 시간표 기능 개선

- **누가(Who)**: 배진수(요구사항 확인·검토), Codex(설계·구현·검증·문서화)
- **언제(When)**: 2026-08-25, Asia/Seoul
- **어디서(Where)**: `feat/schedule-personal-timetable` 브랜치, Flutter 일정 화면, Spring Boot 시간표 API, MySQL/H2 시간표 도메인
- **무엇을(What)**: 모바일 학사 달력의 마지막 주 날짜 잘림을 수정하고, 기존 `과 시간표` 화면을 `학과 시간표`와 `개인 시간표`로 분리했습니다. 학생이 자신의 수업을 추가·수정·삭제할 수 있는 회원별 개인 시간표 API와 UI를 추가했습니다.
- **왜(Why)**: 고정 높이 비율 때문에 월간 달력 하단이 가려졌고, 학과 공용 시간표만으로는 학생 개별 수강 구성을 반영할 수 없었기 때문입니다.
- **어떻게(How)**: 모바일 달력을 6주 고정 높이의 비스크롤 카드로 배치하고 일정 목록만 남은 공간을 사용하게 했습니다. 백엔드에는 `PersonalTimetableEntry` 엔티티와 회원 소유권·교시 중복 검증 CRUD를 만들고, Flutter에는 학과/개인 모드 전환과 개인 수업 편집 다이얼로그를 연결했습니다.
- **검증(Verification)**: 최종 변경 후 `PersonalTimetableServiceIntegrationTest`와 `main_sections_design_test.dart` 3개 테스트가 통과했습니다. 구현 완료 시점의 백엔드 전체 테스트·`bootJar`, Flutter 전체 25개 테스트·Web 릴리스 빌드가 통과했고, Flutter 분석은 기존 경고/정보 32건만 남았습니다.
- **추적(Tracking)**: 기능 커밋 `3d024ab`, 브랜치 `feat/schedule-personal-timetable`, PR 생성 전
- **상태(Status)**: 로컬 구현·검증 완료, 원격 push 및 PR 진행 전, 운영 미배포
- **위험 및 후속 작업(Risks/Follow-up)**: 운영 배포 시 JPA `ddl-auto=update`가 새 개인 시간표 테이블을 생성하므로 배포 전 DB 백업과 생성 결과를 확인해야 합니다. 동시 요청에 대한 완전한 중복 방지는 DB 제약 또는 잠금 보강을 후속 검토합니다.

---

## 2026-08-25 - 운영 일반 테스트 계정 생성

- **누가(Who)**: 배진수(계정 규격 지정), Codex(운영 반영 및 검증)
- **언제(When)**: 2026-08-25, Asia/Seoul
- **어디서(Where)**: Oracle Cloud 운영 MySQL, 운영 API, macOS Keychain
- **무엇을(What)**: 관리자 권한이 없는 활성 테스트 계정 `9999999`를 `USER` 권한으로 생성했습니다.
- **왜(Why)**: 관리자 기능과 분리된 실제 학생 관점의 화면 및 API 동작을 운영 환경에서 점검하기 위해서입니다.
- **어떻게(How)**: 비밀번호는 BCrypt 해시만 DB에 저장하고 원문은 Keychain 서비스 `y-sync-production-test-user`에 보관했습니다. 최초 SQL 전달은 원격 셸 따옴표 오류로 DB 변경 없이 중단됐으며, 표준입력 방식으로 다시 적용했습니다. 먼저 만든 임시 학번 `9900001`은 `9999999`로 변경해 중복 테스트 계정을 남기지 않았습니다.
- **검증(Verification)**: DB에서 `USER`, 활성화, 미차단 상태를 확인하고 운영 로그인 API와 `/api/v1/members/me` 응답의 학번·권한을 검증했습니다.
- **추적(Tracking)**: 운영 작업, 브랜치 `fix/boolean-json-contracts`, PR #9 문서 기록
- **상태(Status)**: 운영 생성 및 로그인 검증 완료
- **위험 및 후속 작업(Risks/Follow-up)**: 공용 테스트 비밀번호이므로 실제 개인정보나 민감한 게시물을 작성하지 않으며, 외부 공개 테스트가 끝나면 비밀번호 회전 또는 계정 삭제가 필요합니다.

---

## 2026-08-25 - 육하원칙 작업 기록 체계 도입

- **누가(Who)**: 배진수(요청·검토), Codex(문서 구성 및 반영)
- **언제(When)**: 2026-08-25, Asia/Seoul
- **어디서(Where)**: `fix/boolean-json-contracts` 브랜치, `ai_prompt/DEVELOPMENT.md`, `ai_prompt/WORK_LOG.md`
- **무엇을(What)**: 모든 개발·운영 작업을 육하원칙과 검증·배포 상태로 기록하는 공통 템플릿과 강제 규칙을 추가했습니다.
- **왜(Why)**: 작업 배경, 구현 방식, 검증 결과와 실제 배포 여부가 대화에만 남아 이후 유지보수 시 누락되는 문제를 방지하기 위해서입니다.
- **어떻게(How)**: 최신순 작업 원장을 만들고 개발 표준에 기록 시점, 필수 항목, 후속 상태 갱신, 비밀값 제외 원칙을 연결했습니다.
- **검증(Verification)**: Markdown 구조, 저장소 상대 링크, `git diff --check`를 확인합니다.
- **추적(Tracking)**: 브랜치 `fix/boolean-json-contracts`, PR #9
- **상태(Status)**: PR 반영 중, 운영 미배포
- **위험 및 후속 작업(Risks/Follow-up)**: PR 병합 및 운영 배포가 완료되면 이 항목의 상태와 추적 정보를 갱신해야 합니다.

---

## 2026-08-25 - boolean JSON 상태 필드 계약 통일

- **누가(Who)**: 배진수(문제 확인·검토), Codex(원인 분석·구현·검증)
- **언제(When)**: 2026-08-25, Asia/Seoul
- **어디서(Where)**: `fix/boolean-json-contracts` 브랜치, Spring Boot 응답 DTO와 Flutter API 모델
- **무엇을(What)**: `isPinned`, `isDeleted`, `isAuthorSuspended` JSON 키를 명시적으로 고정하고 Flutter에 구형 축약 키 fallback을 추가했습니다. API·아키텍처·개발·운영·문제 해결 문서도 현재 구성에 맞게 갱신했습니다.
- **왜(Why)**: Lombok/Jackson이 `isX` 필드를 `x`로 직렬화해 DB 상태가 정상이어도 Flutter 화면에서 고정·삭제·정지 상태가 `false`로 보일 수 있었기 때문입니다.
- **어떻게(How)**: 백엔드에 `@JsonProperty`와 요청용 `@JsonAlias`를 적용하고, Flutter는 공식 `isX` 키를 우선 파싱하도록 수정했습니다. 양쪽에 계약 회귀 테스트를 추가했습니다.
- **검증(Verification)**: 백엔드 `./gradlew test bootJar` 통과, Flutter 전체 테스트 25개 및 Web 릴리스 빌드 통과, GitHub CI Backend·Frontend·Configuration·Gate 통과
- **추적(Tracking)**: 코드 커밋 `4c2263f`, 문서 커밋 `71aa825`, PR #9, `develop` 병합 커밋 `15f6187`
- **상태(Status)**: PR #9 CI 통과 및 `develop` 병합 완료, 운영 미배포
- **위험 및 후속 작업(Risks/Follow-up)**: 단계적 배포 호환을 위한 구형 키 fallback은 모든 지원 클라이언트가 신형 계약으로 전환된 후 제거 여부를 검토합니다.
