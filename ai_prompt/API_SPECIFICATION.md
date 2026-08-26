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
