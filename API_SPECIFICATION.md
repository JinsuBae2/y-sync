# Y-Sync API Specification

## 1. 문서 기본 정보
- **프로젝트명**: Y-Sync (Yeungnam University College Sync)
- **버전**: v1.2 (Search & Scrap Update)
- **기본 URL**: `http://localhost:8080/api/v1` (개발 환경)

### 공통 처리 (응답/에러 구조)
모든 API 응답은 HTTP Status Code(200, 400, 401, 403, 500 등)와 함께 DTO 클래스 구조로 JSON을 직렬화하여 반환합니다. 클라이언트는 상태 코드를 확인하고 데이터를 파싱합니다. 에러 시엔 문자열 에러 메시지가 Body에 담겨 반환됩니다.

> 💡 **Visual Guide**: 본 API 데이터들은 학교 브랜드 컬러인 **포털 블루(#164687)** 테마가 적용된 프론트엔드 UI 요소(필터 칩, 북마크 아이콘, 핀셋 등)에 바인딩되도록 설계되었습니다. `isPinned`, `targetGrade`, `commentCount`, `isScrapped` 등은 전부 시각적 수치나 상태로 렌더링됩니다.

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
  `"로그인 성공"` (String)
  *(로그인 성공 시 헤더에 `Set-Cookie: JSESSIONID=...` 발급)*

#### 3. 내 정보 조회 (`GET /members/me`)
- **Request Parameters**: 없음 (JSESSIONID 쿠키 기반 인증)
- **Response (200 OK)**
  ```json
  {
    "id": 1,
    "loginId": "20261234",
    "name": "홍길동",
    "role": "USER"
  }
  ```
  *(role 필드는 `USER`, `ADMIN`, `SUPER_ADMIN` 중 하나 반환)*

---

### 📢 Notice (공지사항)

#### 1. 공지사항 전체/검색 목록 조회 (`GET /notices` 또는 `/notices/search?keyword={str}`)
- **Request Parameters**: `keyword` (Optional, String)
- **Response (200 OK)**
  ```json
  [
    {
      "id": 105,
      "title": "[모집] 하계 영남이공대 앱잼 팀원 모십니다!",
      "content": "본문 내용...",
      "authorName": "컴정",
      "category": "TEAM",
      "targetGrade": "GRADE_2",
      "isPinned": false,
      "viewCount": 240,
      "commentCount": 3,
      "createdAt": "2026-03-25T15:30:00.000",
      "updatedAt": "2026-03-25T15:35:00.000"
    }
  ]
  ```

#### 2. 공지사항 상세 조회 (`GET /notices/{id}`)
- **Request Parameters**: Path Variable `id`
- **Response (200 OK)**
  *(단일 공지사항 객체 반환. 위 목록과 동일한 JSON DTO 형식이며 `viewCount`가 1 상승합니다.)*

#### 3. 공지 작성/수정 (`POST /admin/notices`, `PUT /admin/notices/{id}`) - **ADMIN / SUPER_ADMIN 전용**
- **Request Body**
  ```json
  {
    "title": "[안내] 도서관 연장 운영",
    "content": "시험기간 도서관 운영시간을 연장합니다.",
    "noticeType": "INTERNAL",
    "targetGrade": "ALL",
    "isPinned": true
  }
  ```
- **Response (200 OK)**
  *(저장 완료된 공지사항 DTO)*

---

### 💬 Community (커뮤니티)

#### 1. 커뮤니티 필터 목록 및 통합 검색 (`GET /community`, `/community/search?keyword={str}`)
- **Request Parameters**: 
  - `targetGrade`: (Optional) `ALL`, `GRADE_1`, `GRADE_2`, `GRADE_3`
  - `category`: (Optional) `NOTICE`, `QNA`, `TEAM`, `FREE`
  - `keyword`: (Optional) 검색 키워드 (제목, 본문 매칭)
- **Response (200 OK)**
  *(공지사항 배열과 거의 동일한 JSON DTO Array를 Response 함)*

#### 2. 게시글 작성/수정 (`POST /community`, `PUT /community/{id}`)
- **Request Body**
  ```json
  {
    "title": "안드로이드 스튜디오 실행 오류 질문",
    "content": "이 에러 어떻게 고치나요?",
    "category": "QNA",
    "targetGrade": "GRADE_1",
    "isPinned": false
  }
  ```
- **Response (200 OK)**
  *(저장 완료된 커뮤니티 상세 DTO)*

#### 3. 특정 게시글 댓글 작성 (`POST /community/{id}/comments`)
- **Request Body**
  ```json
  {
    "content": "저 관심 있습니다!"
  }
  ```
- **Response (200 OK)**
  ```json
  {
    "id": 12,
    "content": "저 관심 있습니다!",
    "authorName": "홍길동",
    "createdAt": "2026-03-25T12:00:00.000",
    "updatedAt": "2026-03-25T12:00:00.000"
  }
  ```
  *(작성 성공 시, 종속된 커뮤니티 게시글의 `commentCount`가 자동으로 +1 됩니다.)*

---

### ✨ Activity (활동 - 스크랩)

#### 1. 스크랩 토글 (추가/취소) (`POST /scraps`)
- **Request Body**
  ```json
  {
    "targetType": "NOTICE",
    "targetId": 105
  }
  ```
  *(`targetType`은 반드시 `"NOTICE"` 또는 `"COMMUNITY"` 중 하나여야 합니다.)*
- **Response (200 OK)**
  `"스크랩 완료"` 또는 `"스크랩 취소"` (기존 스크랩 여부에 따라 자동 토글)

#### 2. 내 스크랩 목록 (`GET /scraps`)
- **Request Parameters**: 없음
- **Response (200 OK)**
  ```json
  [
    {
      "id": 1,
      "targetType": "NOTICE",
      "targetId": 105,
      "category": "공지사항",
      "title": "[모집] 하계 앱잼 팀원 모십니다!",
      "authorName": "컴정",
      "commentCount": 3,
      "postCreatedAt": "2026-03-25T15:30:00.000",
      "scrappedAt": "2026-03-25T16:00:00.000"
    }
  ]
  ```

---

### ⚙️ Admin (관리자 도구)

#### 1. 관리자 권한 신청 (`POST /members/request-admin`)
- **Request Body**: 없음 (현재 로그인 세션 기반 적용)
- **Response (200 OK)**
  `"관리자 권한 신청이 완료되었습니다."`

#### 2. 대기 중인 권한 목록 (`GET /admin/requests`) - **ADMIN 전용**
- **Request Parameters**: 없음
- **Response (200 OK)**
  ```json
  [
    {
      "id": 4,
      "memberId": 12,
      "memberName": "컴정_부과대",
      "status": "PENDING"
    }
  ]
  ```

#### 3. 신청 승인 (`POST /admin/approve/{requestId}`) - **SUPER_ADMIN 전용**
- **Request Parameters**: 없음
- **Response (200 OK)**
  `"권한이 승인되었습니다."`

---

## 3. 핵심 Enum 구조 백서

- **`Grade`**: `ALL`(전체), `GRADE_1`(1학년), `GRADE_2`(2학년), `GRADE_3`(3학년)
- **`Category`**: `NOTICE`(공지성), `QNA`(질문게시판), `TEAM`(팀원모집), `FREE`(자유게시판)
- **`TargetType`**: `NOTICE`(공지용 식별), `COMMUNITY`(커뮤니티 식별)

> **Note on `isScrapped`**:
> 백엔드의 단순 리스트 조회 API에서는 성능 향상을 위해 각 리스트의 Scrap 여부를 반환하지 않습니다. 대신 프론트엔드가 `/scraps` API를 활용하여 Riverpod(`scrapsProvider`)의 메모리에 글로벌하게 저장하고, 게시글 ID와 매칭(targetType + targetId 조합)하여 UI에 실시간(Optimistic UI)으로 북마크(🔖) 활성화 여부를 덧칠하게 됩니다.
