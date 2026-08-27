# Y-Sync Service Context & Core Implementations

이 문서는 Y-Sync(영남이공대학교 컴퓨터정보과 학사 연동 및 커뮤니티 플랫폼)의 비즈니스 목적, 핵심 도메인 영역, 타겟 사용자 정의 및 실제 구현된 비즈니스 로직과 데이터 흐름의 구조적 명세를 담은 통합 메인 스펙 문서입니다.

---

## 1. 서비스 개요 (Service Overview)
Y-Sync는 영남이공대학교 컴퓨터정보과 학생들의 학업 효율성과 학과 커뮤니티의 소통 증진을 위해 개발된 전용 플랫폼입니다. 
파편화되어 있던 학사 일정, 시간표 설정, 익명 커뮤니티, 공지사항 알림 등을 모바일 및 웹 환경에서 유기적으로 연결하고 통합 관리합니다.

---

## 2. 타겟 사용자 (Target Users)
* **학생 (User)**
  - 실시간으로 학사 일정을 조회하고, 자신의 학기 시간표를 동적으로 구성 및 스크랩합니다.
  - 커뮤니티 게시판을 통해 질문(Q&A), 팀원 모집, 자유 주제로 익명/기명 소통을 나눕니다.
* **학과 관리자 (Admin)**
  - 학사 공지사항 및 학사 일정을 생성하고 관리합니다.
  - 학생들의 신고가 누적된 게시글 및 댓글을 실시간 모니터링(블라인드)하고, 악성 유저를 즉시 차단합니다.
* **총괄 관리자 (Super Admin)**
  - 학과 관리자(Admin) 권한 신청을 검토하고 최종 승인 또는 반려합니다.
  - 사전 등록된 학번 기반의 데이터베이스를 일괄 관리(CSV 등)합니다.

---

## 3. 핵심 비즈니스 도메인 및 구현 흐름 (Core Domains & Implementations)

### 🌐 1. 전체 시스템 배포 아키텍처 다이어그램 (System Architecture)

![Y-Sync 전체 시스템 배포 아키텍처](./images/system_architecture_diagram.png)

---

### 🧩 2. 서비스 비즈니스 도메인 아키텍처 다이어그램 (Domain Architecture)

![Y-Sync 서비스 비즈니스 도메인 아키텍처](./images/domain_architecture_diagram.png)

---

### 🔄 3. 시스템 핵심 인증 & 푸시 알림 시퀀스 다이어그램 (Sequence Diagram)

![Y-Sync 시스템 요청 & 푸시 알림 시퀀스](./images/sequence_diagram.png)


* **1. 인증 및 정지 회원 차단**: Bearer JWT 검증 ➡️ DB 정지 상태 조회 ➡️ HTTP 403 차단 반환
* **2. 공지사항 저장 및 푸시 알림**: 공지 저장 ➡️ DB 활성 FCM 토큰 조회 ➡️ `loop [토큰 500개 단위]` 멀티캐스트 전송 ➡️ 푸시 전달
* **3. 예외 및 실패 처리**: DB 저장 오류(500) 핸들링 및 FCM 일부 실패 시 토큰 비활성화/기록 처리



### A. 회원 및 인증 (Member & Authentication)
* **학번 기반 사전 등록 및 인증 가입**:
  1. **학번 사전 등록**: 관리자가 학생 학번과 이름, 기본 USER 역할을 데이터베이스에 사전 등록(단건 혹은 CSV 대량 등록)합니다. 가입 전까지 계정은 `isActivated = false` 상태입니다. (외부인 가입 완전 통제)
  2. **이메일 인증번호 발송**: 학생은 회원가입 화면에서 학번과 이름을 입력하고 인증을 요청합니다. 시스템은 사전 등록 데이터와 일치할 경우 영남이공대 웹메일(`[학번]@ync.ac.kr`)로 6자리 일회용 인증코드를 발송합니다.
  3. **인증코드 매칭**: 서버는 인증코드를 인메모리 스토리지(`ConcurrentHashMap`)에 5분간 보관하며, 사용자가 맞게 입력하면 10분 동안 회원가입 완료가 가능한 승인 토큰을 보관합니다.
  4. **가입 완료 및 활성화**: 최종 가입 폼에서 입력받은 패스워드를 인코딩하여 저장하고 `isActivated = true`로 상태를 변환함으로써 가입 절차가 마무리됩니다.

* **JWT Stateless 인증 및 차단 유저 실시간 격리 가드**:
  ```
  [클라이언트 API 요청 (Bearer JWT)]
                 │
                 ▼
  ┌──────────────────────────────┐
  │  JwtAuthenticationFilter     │
  │  - JWT 서명 검증 및 복호화    │
  │  - DB에서 유저 정지 여부 조회  │
  └──────────────┬───────────────┘
                 │
                 ├─► (isSuspended == true) ──► [즉시 HTTP 403 반환 및 중단]
                 │
                 ▼  (정상 상태)
  ┌──────────────────────────────┐
  │  SecurityContext 인증 등록   │ ──► [컨트롤러로 요청 이관]
  └──────────────────────────────┘
  ```
  - **실시간 정지 제재**: JWT의 특성상 서버에 세션이 없어 실시간 제재가 어렵다는 한계를 극복하기 위해 `JwtAuthenticationFilter`에서 토큰 검증 시점마다 DB의 `isSuspended` 차단 플래그를 실시간 확인합니다.
  - **가드 동작**: 정지된 유저가 요청 시 컨트롤러 단으로 이관되기 전 필터 레벨에서 즉각 **HTTP 403 Forbidden** 응답("차단된 계정입니다. 관리자에게 문의하세요.")을 내보내며 요청을 중단시킵니다.

### B. 학사 일정 및 시간표 (Calendar & Timetable)
* **학사 일정**: 공지사항 및 일정 관리 도구와 연계되어 일 단위/월 단위로 이벤트를 조회합니다. 모바일 월간 달력은 항상 6주 높이를 확보하고 달력 전체를 먼저 배치하여 마지막 주 날짜가 일정 목록에 가려지지 않습니다.
* **학과 시간표**: 관리자가 학년별 공용 수업을 등록하며 학생은 `학과 시간표` 모드에서 학년을 선택해 조회합니다.
* **개인 시간표**: 학생이 `개인 시간표` 모드에서 본인의 수업을 직접 추가·수정·삭제합니다. 데이터는 회원별로 서버에 영구 저장되고 JWT 소유권으로 격리되며, 같은 회원의 요일·교시 중복은 서버에서 차단합니다.

### C. 공지사항 및 푸시 알림 (Notice & FCM Notification)
* **공지사항 요약**: 학과 주요 소식을 전파하며, AI 요약 필드(aiSummary)를 포함하여 모바일 카드 뷰에서 가독성을 높입니다.
* **FCM 푸시**: 새로운 공지사항이 등록되거나 본인 글에 댓글이 작성되었을 때, 활성화된 Member들의 디바이스 토큰(fcmToken)으로 즉시 백그라운드/포그라운드 푸시 알림을 발송합니다.
* **인앱 알림 센터 (Notification Center)**: 수신한 알림 내역과 `isRead` 상태를 데이터베이스에 보관하여 앱 내에서 모아볼 수 있는 기능을 제공합니다. 알림을 탭하면 해당하는 공지사항이나 커뮤니티 게시물 상세 화면으로 즉시 이동(딥링크 연동)하며, 전체 읽음 요청은 실제 갱신 건수(`updatedCount`)를 반환합니다. 프론트엔드는 성공 응답 뒤 목록과 미읽음 배지를 함께 갱신하고, 실패 시 읽음 상태를 낙관적으로 바꾸지 않습니다.

### D. 커뮤니티 및 대댓글 (Community & Nested Comments)
* **익명성 및 카테고리**: 질문, 팀원 모집, 자유 등으로 나누어 작성하며, 익명 여부를 선택할 수 있습니다.
* **목록 카드 UX**: 게시글은 흰색 표면, 얇은 테두리, 카드 간 간격으로 항목 경계를 구분합니다. 이미지가 있으면 본문 우측 상단에 썸네일을 표시하고, 조회·댓글 수와 즐겨찾기는 이미지 유무와 관계없이 카드 하단 전체 너비에서 동일하게 정렬합니다.
* **대댓글 자기참조 계층 트리 조립 ($O(N)$ 최적화)**: 부모-자식 관계가 명확한 계층 트리 구조의 댓글 레이아웃을 제공하기 위해, 쿼리 횟수를 최소화하여 DB 부하를 경감시키는 가공 알고리즘이 탑재되어 있습니다.
  ```java
  // CommentService.java 내 트리 조립 구현 원리
  public List<CommentResponse> getCommentTree(Long postId) {
      List<Comment> comments = commentRepository.findByCommunityPostIdOrderByCreatedAtAsc(postId);
      Map<Long, CommentResponse> map = new HashMap<>();
      List<CommentResponse> rootComments = new ArrayList<>();

      // 1. 모든 댓글을 DTO로 변환하여 맵에 보관 (O(N))
      for (Comment comment : comments) {
          CommentResponse dto = CommentResponse.from(comment);
          map.put(dto.getId(), dto);
          
          // 부모가 없으면 루트 댓글 리스트에 삽입
          if (comment.getParent() == null) {
              rootComments.add(dto);
          } else {
              // 부모가 있으면 부모 DTO의 자식 리스트에 조립
              CommentResponse parentDto = map.get(comment.getParent().getId());
              if (parentDto != null) {
                  parentDto.getChildren().add(dto);
              }
          }
      }
      return rootComments;
  }
  ```
  - **동작 방식**: 데이터베이스에는 평탄하게 조회 쿼리를 날리고 메모리 단에서 `Map`을 사용해 단일 루프로 조립함으로써 N+1 문제를 방지하고 성능을 최적화했습니다.

### E. 신고 및 모더레이션 (Report & Moderation)
* **다형성 신고 수집**: `ReportRepository`를 통해 게시물(POST)과 댓글(COMMENT)의 신고 이력을 고유 ID 및 타겟 타입 문자열 형태로 수집합니다.
* **블라인드 (소프트 딜리트)**: 게시글/댓글에 대해 허위 정보, 비방 등의 사유로 신고가 5회 이상 누적되거나 어드민이 강제 블라인드 처리하면 `isDeleted = true` 및 `deletionReason`이 세팅되며, 프론트엔드에서는 취소선 및 숨김 메시지를 띄웁니다.
* **신고 기각 / 복원 (Dismiss)**:
  - 허위 신고의 경우 관리자가 [신고 기각/복구]를 실행하면 백엔드는 해당 대상에 등록된 모든 `Report` 레코드를 DB에서 영구 삭제합니다.
  - 대상이 이미 소프트 딜리트 처리되어 가려졌던 상태였다면 `isDeleted = false`로 원복시킵니다.
  - 복원 대상이 댓글인 경우, 상위 관계에 있는 게시물(Post) 혹은 공지사항(Notice)의 전체 댓글 카운트(`commentCount`) 값을 정상적으로 다시 1 올려주어 정합성을 동기화합니다.
