# Y-Sync API Specification

Y-Sync 플랫폼의 백엔드와 프론트엔드가 교신하는 REST API 명세서입니다. 기존 명세에 그동안 추가 및 보완된 최신 API(대댓글, FCM, 어드민 제재, 신고 기각 등)를 통합 명세화했습니다.

---

## 1. 문서 기본 정보
- **기본 URL**: `http://localhost:8080/api/v1` (개발 환경)
- **정적 파일 제공 URL**: `http://localhost:8080/uploads/**` (업로드된 로컬 이미지 등 외부 서빙 용도)
- **인증 방식**: HTTP Request Header 내 `Authorization: Bearer [JWT]` 토큰 인증 수행.
- **Boolean JSON 계약**: 의미상 `is`로 시작하는 상태값은 `isRead`, `isPinned`, `isDeleted`, `isAuthorSuspended`처럼 `isX` 키를 공식 계약으로 사용합니다. Lombok/Jackson의 자동 이름 변환에 의존하지 않고 백엔드 DTO에 `@JsonProperty`를 명시합니다.
- **이전 버전 호환**: 배포 중 구형 응답과 신형 앱이 섞일 수 있으므로 Flutter 파서는 당분간 `read`, `pinned`, `deleted`, `authorSuspended` 키도 fallback으로 허용합니다. 새 API와 요청은 공식 `isX` 키만 사용합니다.

---

## 2. 세부 API 명세 (Request & Response)

### 🔑 Auth & Member (인증 및 회원)

#### 1. 회원가입 (`POST /auth/signup`)
- **Request Body**
  ```json
  {
    "loginId": "20261234",
    "password": "password123!",
    "name": "홍길동"
  }
  ```
- **Response (200 OK)**
  `"회원가입 성공"` (String)

#### 2. 로그인 (`POST /auth/login`)
- **Request Body**
  ```json
  {
    "loginId": "20261234",
    "password": "password123!"
  }
  ```
- **Response (200 OK)**
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiJ9..."
  }
  ```

#### 3. 내 정보 조회 (`GET /members/me`)
- **Response (200 OK)**
  ```json
  {
    "id": 1,
    "loginId": "20261234",
    "name": "홍길동",
    "role": "USER",
    "noticeEnabled": true,
    "commentEnabled": true,
    "isSuspended": false
  }
  ```

#### 4. FCM 디바이스 토큰 갱신 (`POST /members/fcm`)
- **Request Body**
  ```json
  {
    "fcmToken": "FCM_DEVICE_TOKEN_STRING"
  }
  ```
- **Response (200 OK)**: 없음 (Void)

#### 5. 알림 설정 업데이트 (`PUT /members/notification-settings`)
- **Request Body**
  ```json
  {
    "noticeEnabled": true,
    "commentEnabled": false
  }
  ```
- **Response (200 OK)**: 없음 (Void)

#### 6. 비밀번호 재설정 인증번호 요청 (`POST /auth/password-reset/request`)
- 활성 계정의 학번과 이름을 확인한 뒤 회원가입 시 인증한 학교 이메일로 인증번호를 발송합니다.
- **Request Body**
  ```json
  {
    "loginId": "20261234",
    "name": "홍길동"
  }
  ```

#### 7. 비밀번호 재설정 확정 (`POST /auth/password-reset/confirm`)
- 비밀번호를 변경하고 기존 JWT와 FCM 토큰을 무효화합니다. 계정 권한, 게시글, 댓글과 정지 상태는 유지됩니다.
- **Request Body**
  ```json
  {
    "loginId": "20261234",
    "code": "123456",
    "newPassword": "newPassword123!"
  }
  ```

#### 8. 관리자 비밀번호 재설정 안내 (`POST /admin/members/{id}/password-reset-email`)
- **ADMIN / SUPER_ADMIN 전용**
- 등록된 학교 이메일로 인증번호를 발송하며 계정 데이터는 변경하지 않습니다.

#### 9. 관리자 계정 재등록 초기화 (`POST /admin/members/{id}/reset-registration`)
- **ADMIN / SUPER_ADMIN 전용**
- 등록 이메일과 비밀번호를 초기화하고 가입 대기 상태로 전환합니다.
- 기존 JWT와 FCM 토큰은 무효화되며 권한, 게시글, 댓글과 정지 상태는 유지됩니다.

#### 10. 관리자 회원 목록 (`GET /admin/members`)
- **ADMIN / SUPER_ADMIN 전용**
- `Member` 엔티티가 아닌 관리자 회원 DTO를 반환합니다.
- 응답에는 `id`, `loginId`, `name`, `role`, `email`, 학년 선택 정보, 활성·정지 상태와 생성 시각만 포함합니다.
- `email`은 가입 시 인증한 학교 메일이며 계정 관련 문의에 대응하기 위해 관리자에게만 제공합니다. 본인 조회(`GET /members/me`)에는 포함하지 않습니다.
- 회원 개인의 알림 수신 토글(`noticeEnabled`, `commentEnabled`)은 관리 목적이 없어 반환하지 않습니다.
- `password`, `fcmToken`, `socialId`, `authVersion`은 반환하지 않습니다.

#### 11. 관리자 회원 등록·수정 (`POST /admin/members`, `POST /admin/members/csv`, `PUT /admin/members/{id}`)
- 일반 `ADMIN`은 자신이나 다른 회원에게 `SUPER_ADMIN` 역할을 부여하거나 `SUPER_ADMIN` 계정을 생성할 수 없습니다.
- 일반 `ADMIN`은 기존 `SUPER_ADMIN` 계정을 수정할 수 없습니다.
- 역할이 변경되면 기존 JWT는 즉시 무효화됩니다.
- `SUPER_ADMIN` 역할의 생성·변경은 현재 `SUPER_ADMIN`만 수행할 수 있습니다.
- Excel(`.xlsx`, `.xls`)과 CSV 명단을 지원합니다. 첫 번째 시트 헤더의 `학번`·`이름`·`역할`을 기준으로 열을 자동 매핑하므로 순서가 달라도 처리됩니다. 전화번호, 주소 등 인식 대상이 아닌 열은 저장하지 않습니다.
- 역할 열은 선택 사항이며 없으면 `USER`로 등록합니다. 헤더가 없는 파일은 `학번,이름,역할` 순서를 사용합니다.
- CSV 응답은 전체 행 수, 신규 등록 수, 중복 제외 수와 행별 오류 사유를 반환합니다. 필수 헤더인 학번 또는 이름을 찾지 못하면 등록하지 않습니다.

#### 12. 공지 알림 수신 학년 (`PUT /members/me/notice-grade`, `PUT /admin/members/{id}`)
- 값은 `GRADE_1`, `GRADE_2`, `GRADE_3`, `GENERAL_ONLY` 네 가지입니다. 아직 고르지 않은 '미설정'은 `null`입니다.
- 공지의 대상 학년 `ALL`(전체 학년에게 보내는 공지)과 회원의 `GENERAL_ONLY`(전체 공지만 받기)는 다른 개념입니다.
- 본인 수정은 인증된 회원 자신만 대상으로 합니다. 요청 본문에 대상 회원을 지정하는 값이 없어 타인의 설정을 바꿀 수 없습니다.
- 확인 학년도는 클라이언트가 지정하지 않습니다. 서버가 계산한 값을 선택값과 같은 트랜잭션에서 함께 저장합니다.
- 관리자 수정은 문의로 들어온 예외 상황을 지원하기 위한 것이며 기존 회원 수정 권한을 따릅니다. 값을 보내지 않으면 기존 선택을 유지합니다.
- `GET /members/me`는 선택값, 확인 학년도, 서버가 계산한 현재 학년도, 재확인 필요 여부를 함께 반환합니다.

#### 13. 공지 알림 학년 선택 현황 (`GET /admin/members/notice-grade-stats`)
- **ADMIN / SUPER_ADMIN 전용**
- 학년별 알림 전환 시점을 판단하기 위한 집계입니다. 전환하면 미설정 회원은 학년 공지 알림을 받지 못하므로, 그 인원을 먼저 확인할 수 있어야 합니다.
- 모수(`noticeTargetCount`)는 공지 알림을 받을 수 있는 회원입니다. 활성 회원이면서 공지 알림에 동의한 경우만 셉니다. 알림을 꺼 둔 회원은 전환과 무관하므로 제외합니다.
- `unsetCount`는 아직 선택하지 않은 회원 수이며 전환 시 학년 공지를 받지 못하는 인원입니다.
- `needsConfirmationCount`는 올해 확인이 필요한 회원 수입니다(미설정 포함). 확인하지 않아도 이전 선택 기준으로 알림은 계속 받습니다.
- `countsByPreference`는 선택값별 인원이며 미설정은 포함하지 않습니다.
- 개별 회원 정보는 반환하지 않고 인원 수만 반환합니다.

---

### 📢 Notice (공지사항)

#### 1. 공지사항 전체/검색 목록 조회 (`GET /notices` 또는 `/notices/search?keyword={str}`)
- **Response (200 OK)**
  ```json
  [
    {
      "id": 105,
      "title": "[모집] 하계 앱잼 팀원 모십니다!",
      "content": "본문 내용...",
      "authorName": "학과사무실",
      "category": "TEAM",
      "targetGrade": "GRADE_2",
      "isPinned": false,
      "viewCount": 240,
      "commentCount": 3,
      "imageUrls": ["/uploads/abc.jpg"],
      "createdAt": "2026-03-25T15:30:00.000",
      "updatedAt": "2026-03-25T15:35:00.000"
    }
  ]
  ```

#### 2. 공지사항 상세 조회 (`GET /notices/{id}`)
- **Response (200 OK)**: 단일 공지사항 객체 반환 (위 목록 구조와 동일, 조회수 +1)

#### 3. 공지사항 작성/수정 (`POST /admin/notices`, `PUT /admin/notices/{id}`) - **ADMIN / SUPER_ADMIN 전용**
- **Content-Type**: `multipart/form-data`
- **Request Body (Parts)**:
  - `request` (application/json):
    ```json
    {
      "title": "[안내] 도서관 연장 운영",
      "content": "시험기간 도서관 운영시간을 연장합니다.",
      "noticeType": "NEWS",
      "targetGrade": "ALL",
      "isPinned": true
    }
    ```
  - `images` (List<MultipartFile>): 파일 배열 (Optional)

---

### 💬 Community & Comments (커뮤니티 및 댓글)

#### 1. 커뮤니티 목록 및 검색 (`GET /community`)
- **Request Parameters**: `targetGrade` (Optional), `category` (Optional), `keyword` (Optional)
- **Response (200 OK)**: 게시글 DTO Array 반환

#### 2. 게시글 작성/수정 (`POST /community`, `PUT /community/{id}`)
- **Content-Type**: `multipart/form-data`
- **Request Body (Parts)**:
  - `request` (application/json):
    ```json
    {
      "title": "안드로이드 스튜디오 실행 오류 질문",
      "content": "이 에러 어떻게 고치나요?",
      "category": "QA",
      "targetGrade": "GRADE_1",
      "anonymous": false,
      "isPinned": false
    }
    ```
  - `images` (List<MultipartFile>): 파일 배열 (Optional)
  - 수정은 작성자 본인만 가능하며, 이미지를 보내지 않으면 기존 이미지가 유지되고 새 이미지를 보내면 교체됩니다.

#### 3. 댓글 및 대댓글 조회 (`GET /community/{id}/comments` 및 `/notices/{id}/comments`)
- **Response (200 OK)**: 계층적 트리 구조 DTO 리스트
  ```json
  [
    {
      "id": 12,
      "content": "루트 댓글입니다.",
      "authorName": "홍길동",
      "parentId": null,
      "isDeleted": false,
      "createdAt": "2026-03-25T12:00:00",
      "children": [
        {
          "id": 13,
          "content": "여기는 대댓글(답글)입니다.",
          "authorName": "이순신",
          "parentId": 12,
          "isDeleted": false,
          "createdAt": "2026-03-25T12:05:00",
          "children": []
        }
      ]
    }
  ]
  ```

#### 4. 댓글 및 대댓글 작성 (`POST /community/{id}/comments` 및 `/notices/{id}/comments`)
- **Request Body**
  ```json
  {
    "content": "답글을 작성합니다.",
    "parentId": 12
  }
  ```
  *(루트 댓글일 경우 `parentId`는 null로 전송하거나 생략 가능)*
- **Response (200 OK)**: 저장 완료된 댓글 DTO 반환

---

### 🚨 Report & Moderation (신고 및 제재)

#### 1. 신고하기 (`POST /reports`)
- **Request Body**
  ```json
  {
    "targetType": "POST",
    "targetId": 105,
    "reason": "광고성 스팸 게시물입니다."
  }
  ```
  *(`targetType`은 `"POST"` 혹은 `"COMMENT"` 중 하나)*
- **Response (200 OK)**
  `"신고가 접수되었습니다."` (String)

#### 2. 누적 신고 목록 조회 (`GET /admin/reports`) - **ADMIN / SUPER_ADMIN 전용**
- **Response (200 OK)**
  ```json
  [
    {
      "targetType": "POST",
      "targetId": 105,
      "reportCount": 3,
      "title": "[광고] 저렴한 노트북 판매",
      "content": "스팸 내용...",
      "authorName": "스패머",
      "authorId": 15,
      "isAuthorSuspended": false,
      "isDeleted": false,
      "deletionReason": null,
      "reasons": [
        "스팸 광고",
        "허위 사실",
        "비방"
      ]
    }
  ]
  ```

#### 3. 허위 신고 기각 및 복구 (`POST /admin/reports/dismiss`) - **ADMIN / SUPER_ADMIN 전용**
- **Request Body**
  ```json
  {
    "targetType": "POST",
    "targetId": 105
  }
  ```
- **Response (200 OK)**
  `"신고가 기각되고 대상이 복구되었습니다."` (String)

#### 4. 사용자 차단/정지 (`POST /admin/members/{id}/suspend`) - **ADMIN / SUPER_ADMIN 전용**
- **Response (200 OK)**
  `"회원이 성공적으로 차단되었습니다."` (String)

#### 5. 사용자 차단 해제 (`POST /admin/members/{id}/unsuspend`) - **ADMIN / SUPER_ADMIN 전용**
- **Response (200 OK)**
  `"회원의 차단이 성공적으로 해제되었습니다."` (String)

---

### ✨ Activity & Admin Config (스크랩 및 기본 설정)

#### 1. 스크랩 토글 (`POST /scraps`)
- **Request Body**
  ```json
  {
    "targetType": "NOTICE",
    "targetId": 105
  }
  ```
- **Response (200 OK)**: `"스크랩 완료"` 또는 `"스크랩 취소"`

#### 2. 관리자 권한 신청 (`POST /admin/requests`)
- **Request Body**
  ```json
  {
    "reason": "학과 부대표 권한 필요"
  }
  ```
- **Response (200 OK)**: `"관리자 권한 신청이 완료되었습니다."`

---

### 📅 Timetable (학과·개인 시간표)

#### 1. 학과 시간표 조회 (`GET /timetable/{grade}`)
- **Path Variable**: `grade`는 `GRADE_1`, `GRADE_2`, `GRADE_3` 중 하나입니다.
- **Response (200 OK)**: 해당 학년의 학과 공용 수업 목록을 반환합니다.
- 학과 시간표의 등록·수정·삭제는 기존 `/timetable` 관리자 API를 사용하며 `ADMIN` 또는 `SUPER_ADMIN`만 실행할 수 있습니다.

#### 2. 개인 시간표 조회·추가 (`GET`, `POST /timetable/personal`)
- **인증**: Bearer JWT 필수. 서버는 토큰의 회원 ID를 사용하며 클라이언트가 소유자 ID를 전달하지 않습니다.
- **Request Body (POST)**
  ```json
  {
    "dayOfWeek": "MONDAY",
    "subjectName": "모바일 프로그래밍",
    "professorName": "홍길동",
    "classroom": "공학관 301호",
    "startPeriod": 1,
    "endPeriod": 2
  }
  ```
- `dayOfWeek`는 월요일부터 금요일까지, 교시는 1~9교시 범위입니다. 과목명은 필수이고 교수명과 강의실은 선택입니다.
- 같은 회원의 동일 요일·교시가 겹치면 등록을 거부하며, 다른 회원의 시간표와는 독립적으로 저장합니다.
- **Response (200 OK)**: 개인 수업 또는 개인 수업 목록을 반환합니다. 응답은 회원 정보나 비밀번호를 포함하지 않습니다.

#### 3. 개인 시간표 수정·삭제 (`PUT`, `DELETE /timetable/personal/{id}`)
- 로그인한 회원이 소유한 항목만 수정하거나 삭제할 수 있습니다.
- 수정 요청 본문은 개인 시간표 추가와 동일하며, 삭제 성공 시 `{ "message": "개인 시간표 수업이 삭제되었습니다." }`를 반환합니다.

---

### 🔔 Notification Center (알림 센터)

#### 1. 수신한 알림 내역 최신순 조회 (`GET /notifications`)
- **Response (200 OK)**
  ```json
  [
    {
      "id": 1,
      "title": "💬 내 글에 새로운 댓글이 달렸어요!",
      "body": "방금 내 작성글에 새로운 댓글이 달렸습니다.",
      "targetType": "COMMUNITY",
      "targetId": 105,
      "isRead": false,
      "createdAt": "2026-06-29T13:00:00"
    },
    {
      "id": 2,
      "title": "[새 공지사항] 도서관 연장 운영",
      "body": "새로운 공지사항이 등록되었습니다.",
      "targetType": "NOTICE",
      "targetId": 12,
      "isRead": true,
      "createdAt": "2026-06-29T12:30:00"
    }
  ]
  ```

#### 2. 모든 알림 일괄 읽음 처리 (`PUT /notifications/read`)
- **Response (200 OK)**
  ```json
  {
    "updatedCount": 3
  }
  ```
  `updatedCount`는 이번 요청에서 실제로 읽음 처리된 알림 수입니다. 이미 모든 알림이 읽힌 상태라면 `0`을 반환합니다.

#### 3. 개별 알림 읽음 처리 (`PUT /notifications/{id}/read`)
- **Response (200 OK)**
  `"개별 읽음 처리 완료"` (String)

#### 4. 개별 알림 삭제 (`DELETE /notifications/{id}`)
- **Response (200 OK)**
  `"알림 삭제 완료"` (String)

---

## 도움말 및 사용자 의견

### 사용 흐름

- 내정보 → 도움말 및 의견 보내기에서 시간표, 알림·스크랩, 계정 관련 FAQ를 확인합니다.
- 의견 작성에서 오류 신고 / 개선 제안 / 기타 의견을 선택하고 제목·내용을 입력합니다. 관련 화면은 선택 입력입니다.
- PNG/JPG 이미지 최대 3장, 한 장당 2MB까지 첨부할 수 있습니다. 사용자에게 이미지와 본문에서 개인정보를 제거하도록 안내합니다.
- 제출 완료 안내만 제공하며 사용자용 내 제보 목록, 처리 상태, 관리자 답변, 공개 Q&A는 제공하지 않습니다.
- 관리자 → 의견 탭에서 미확인 / 확인 / 전체 목록을 페이지 단위로 보고, 내용을 펼쳐 확인 처리합니다. 확인은 내부 분류이며 사용자에게 알림을 보내지 않습니다.

### API와 접근 범위

| 메서드·경로 (`/api/v1` 기준) | 권한 | 용도 |
|---|---|---|
| `POST /feedback` | 로그인 회원 | multipart 의견 제출, 성공 시 201 |
| `GET /admin/feedback?reviewed=false&page=0` | ADMIN, SUPER_ADMIN | 최신순 20건, reviewed 생략 시 전체 |
| `PUT /admin/feedback/{id}/reviewed` | ADMIN, SUPER_ADMIN | 확인 처리, 성공 시 204, 반복 호출 가능 |
| `GET /admin/feedback/images/{id}` | ADMIN, SUPER_ADMIN | 이미지 바이너리, Cache-Control: no-store |

제출 필드는 `category`(BUG/SUGGESTION/OTHER), `title`(필수 100자), `content`(필수 3,000자), `screen`(선택 100자), `clientInfo`(선택 300자), `images`(선택 multipart 파일 목록)입니다. 이름·학번·이메일·토큰은 자동 첨부하지 않습니다. 앱 버전과 Web/PWA 또는 App 구분, 운영체제 종류만 실행 환경으로 전송하며 정확한 브라우저 버전은 수집하지 않습니다.

### 저장과 배포

- 신규 `feedback`, `feedback_image` 테이블을 추가합니다. 기존 JPA 스키마 관리 설정을 따르므로 배포 전 DB 백업과 테이블 생성 권한을 확인합니다.
- 제보 첨부는 공개 `/uploads` 또는 `/s3-uploads`에 저장하지 않고 DB LOB에 저장합니다. 의견과 이미지가 한 트랜잭션으로 기록됩니다. 이미지 시그니처는 PNG/JPEG만 허용합니다.
- 개인정보를 포함할 수 있는 원본 파일명은 저장하지 않습니다. 관리자 응답에는 작성자 식별자를 포함하지 않습니다.
- 관리자 목록에는 이미지 ID만 포함하며 이미지를 누를 때만 인증된 요청으로 바이너리를 가져옵니다. 목록·이미지 Provider는 세션 회원 ID에 종속되고 사용하지 않으면 폐기합니다.
- 이미지가 제보당 최대 6MB를 차지할 수 있습니다. 제보량 증가 시 DB·백업 용량을 확인하고 비공개 객체 저장소 이전 및 보관·삭제 정책을 검토합니다. 현재 자동 삭제는 없습니다.
- 백엔드를 먼저 배포한 뒤 프론트엔드를 반영합니다. 구형 백엔드에서는 전송 오류를 표시하고 입력 내용은 유지됩니다.
- 롤백은 프론트엔드·백엔드 코드를 이전 버전으로 되돌리면 됩니다. 수집된 데이터 보존을 위해 신규 테이블은 즉시 삭제하지 않습니다.

### 유지보수 및 검증

- FAQ는 `frontend/lib/screens/help_screen.dart`의 정적 콘텐츠입니다. 시간표·계정·알림 기능 변경 시 해당 답변을 함께 검토합니다.
- 실행 환경의 앱 버전 표기는 현재 앱 내정보 표기와 동일한 1.0.0이며, 앱 버전 변경 시 함께 갱신합니다.
- 백엔드 `FeedbackIntegrationTest`: 비로그인 제출 거부, 일반 사용자의 관리자 목록·이미지·확인 처리 차단, 입력·파일 제한, 저장 및 확인 필터 동작을 검증합니다.
- Flutter `help_feedback_test.dart`: 320px FAQ 탐색·의견 화면 이동, 제출 실패 후 재시도, 관리자 확인 처리를 검증합니다.
