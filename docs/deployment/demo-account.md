# 포트폴리오 읽기 전용 데모 계정

## 제공 범위

운영 PWA의 기존 로그인 화면에서 아이디 `0000000`으로 로그인한다. 표시 이름은 `임시`이며 비밀번호는 production Environment Secret으로 관리한다. 공지·커뮤니티·댓글·일정·시간표·본인 스크랩·알림 조회와 검색은 가능하다. 작성·수정·삭제·업로드·신고·문의·스크랩 토글·설정 저장·관리자 화면 접근은 차단한다.

데모에서는 상세 조회수가 증가하지 않고 푸시 토큰, 알림 읽음, 학년 확인을 저장하지 않는다. 여러 방문자가 공유해도 로그아웃은 다른 세션을 무효화하지 않는다. 데모의 개인 시간표·알림·스크랩은 초기 데이터가 없다면 빈 화면이다. 시연용 데이터를 별도로 넣을 수 있다.

## 계정 생성 및 활성화

1. 샘플 데이터가 있는 시연 서버를 우선 사용한다. 운영 서버를 사용하려면 공지·게시글·댓글·작성자 이름·첨부파일이 공개 가능한지 먼저 검토한다. DEMO 역할은 데이터를 자동으로 익명화하지 않는다.
2. 배포 전 MySQL에서 `SHOW COLUMNS FROM member LIKE 'role';`로 역할 컬럼을 확인한다. ENUM이면 기존 값을 그대로 보존하면서 `DEMO`를 추가하는 DDL을 적용한다. 아래 예시는 현재 enum 값이 정확히 일치할 때만 사용한다.

   ```sql
   ALTER TABLE member MODIFY role ENUM('ADMIN','SUPER_ADMIN','USER','DEMO') NOT NULL;
   ```

   운영은 `spring.jpa.hibernate.ddl-auto=validate`이며 이 변경을 자동으로 수행하지 않는다.
3. GitHub `production` Environment Variables에 `YSYNC_DEMO_ENABLED=true`, `YSYNC_DEMO_LOGIN_ID=0000000`을 설정하고, `YSYNC_DEMO_PASSWORD`는 Environment Secret으로 등록한다. 배포 워크플로가 Compose를 통해 서버에 전달한다. 실제 비밀번호는 소스나 문서에 넣지 않는다.

   ```text
   YSYNC_DEMO_ENABLED=true
   YSYNC_DEMO_LOGIN_ID=0000000
   YSYNC_DEMO_PASSWORD=<선택한 데모 비밀번호>
   ```

4. 서버 재시작 시 활성화된 DEMO 회원이 없으면 생성한다. DB에는 BCrypt 해시를 저장한다. 기존 일반 회원과 같은 아이디면 서버 시작을 실패시켜 덮어쓰기를 방지한다. 기존 개발 시드 학번(2305009, 2300001, 2300002, 2505034)은 코드에서도 거부한다.
5. 프런트 변경도 함께 배포하고 실제 데모 계정으로 로그인·검색·상세·알림 이동·새로고침·로그아웃을 확인한다. 직접 변경 API는 `403`과 `DEMO_READ_ONLY`를 반환해야 한다.
6. 확인 후 포트폴리오에 앱 링크·데모 아이디·비밀번호와 “조회만 가능한 시연 계정” 안내를 게시한다. 관리자·실사용자 자격 증명은 사용하지 않는다.

기존 DEMO 회원의 비밀번호는 서버 재시작으로 덮어쓰지 않는다. 환경 변수만 변경해도 이미 생성된 계정 비밀번호가 바뀌지 않는다. 비밀번호 교체가 필요하면 운영자 절차로 BCrypt 해시를 갱신하고 `auth_version`을 증가시켜 기존 JWT를 무효화한다.

## 중단

`YSYNC_DEMO_ENABLED=false`로 변경하고 서버를 재시작한다. 데모 로그인과 이미 발급된 데모 JWT 요청을 모두 차단한다. 기본값은 false이며 운영 DB를 임의로 수정하거나 공개하지 않는다.

## 검증 명령

```sh
cd backend
./gradlew test
```

```sh
cd frontend
flutter test
flutter analyze
```

## 수정된 파일 목록

### 백엔드

- `backend/src/main/java/com/ync/ysync/config/DemoAccessPolicy.java`
- `backend/src/main/java/com/ync/ysync/config/DemoAccountInitializer.java`
- `backend/src/main/java/com/ync/ysync/config/DemoReadOnlyFilter.java`
- `backend/src/main/java/com/ync/ysync/config/SecurityConfig.java`
- `backend/src/main/java/com/ync/ysync/controller/CommunityController.java`
- `backend/src/main/java/com/ync/ysync/controller/MemberController.java`
- `backend/src/main/java/com/ync/ysync/controller/NoticeController.java`
- `backend/src/main/java/com/ync/ysync/domain/MemberRole.java`
- `backend/src/main/java/com/ync/ysync/service/CommunityService.java`
- `backend/src/main/java/com/ync/ysync/service/MemberService.java`
- `backend/src/main/java/com/ync/ysync/service/MemberSignupService.java`
- `backend/src/main/java/com/ync/ysync/service/NoticeGradeService.java`
- `backend/src/main/java/com/ync/ysync/service/NoticeService.java`
- `backend/src/main/resources/application.properties`
- `backend/src/test/java/com/ync/ysync/config/DemoAccessIntegrationTest.java`
- `backend/src/test/java/com/ync/ysync/config/DemoAccessPolicyTest.java`
- `backend/src/test/java/com/ync/ysync/config/DemoAccountInitializerTest.java`

### 프런트엔드

- `frontend/lib/models/member.dart`
- `frontend/lib/providers/api_client_provider.dart`
- `frontend/lib/providers/auth_provider.dart`
- `frontend/lib/providers/demo_access_provider.dart`
- `frontend/lib/providers/notification_provider.dart`
- `frontend/lib/providers/session_provider.dart`
- `frontend/lib/screens/auth_settings_screen.dart`
- `frontend/lib/screens/community_detail_screen.dart`
- `frontend/lib/screens/community_form_screen.dart`
- `frontend/lib/screens/community_list_screen.dart`
- `frontend/lib/screens/feedback_screen.dart`
- `frontend/lib/screens/main_tab_screen.dart`
- `frontend/lib/screens/notice_detail_screen.dart`
- `frontend/lib/screens/notice_form_screen.dart`
- `frontend/lib/screens/notice_list_screen.dart`
- `frontend/lib/screens/notification_center_screen.dart`
- `frontend/lib/screens/notification_settings_screen.dart`
- `frontend/lib/screens/pin_setup_screen.dart`
- `frontend/lib/screens/splash_screen.dart`
- `frontend/lib/screens/timetable_view.dart`
- `frontend/lib/widgets/comment_thread.dart`
- `frontend/lib/widgets/notice_grade_prompt.dart`
- `frontend/test/demo_read_only_test.dart`

### Docker

- `docker/docker-compose.yml`

### GitHub Actions

- `.github/workflows/deploy-production.yml`

### 문서

- `docs/WORK_LOG.md`
- `docs/deployment/demo-account.md`
- `docs/superpowers/plans/2026-10-06-read-only-demo-account.md`
