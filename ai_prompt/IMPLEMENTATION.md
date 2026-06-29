# Y-Sync Implemented Features & Flows

Y-Sync 플랫폼에 구현되어 있는 핵심 비즈니스 로직과 데이터 흐름의 구조적 명세서입니다.

---

## 1. 사전 등록 및 학번 인증 회원가입

### Flow
1. **학번 사전 등록**: 관리자가 학생 학번과 이름, 기본 USER 역할을 데이터베이스에 사전 등록(단건 혹은 CSV 대량 등록)합니다. 가입 전까지 계정은 `isActivated = false` 상태입니다.
2. **이메일 인증번호 발송**: 학생은 회원가입 화면에서 학번과 이름을 입력하고 인증을 요청합니다. 시스템은 사전 등록 데이터와 일치할 경우 영남이공대 웹메일(`[학번]@ync.ac.kr`)로 6자리 일회용 인증코드를 발송합니다.
3. **인증코드 매칭**: 서버는 인증코드를 인메모리 스토리지(`ConcurrentHashMap`)에 5분간 보관하며, 사용자가 맞게 입력하면 10분 동안 회원가입 완료가 가능한 승인 토큰을 보관합니다.
4. **가입 완료 및 활성화**: 최종 가입 폼에서 입력받은 패스워드를 인코딩하여 저장하고 `isActivated = true`로 상태를 변환함으로써 가입 절차가 마무리됩니다.

---

## 2. JWT Stateless 인증 및 차단 유저 실시간 격리 가드

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

---

## 3. 대댓글 자기참조 계층 트리 조립 ($O(N)$ 최적화)

대댓글의 계층 구조를 쿼리 한 번으로 조립하고 N+1 문제를 방지하기 위한 가공 알고리즘이 탑재되어 있습니다.

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

- **성향**: 데이터베이스에는 평탄하게 조회 쿼리를 날리고 메모리 단에서 `Map`을 사용해 단일 루프로 조립함으로써 쿼리 횟수를 최소화하여 DB 부하를 경감시켰습니다.

---

## 4. 신고 및 모더레이션(신고 기각 및 복구) 시스템

- **다형성 신고 수집**: `ReportRepository`를 통해 게시물(POST)과 댓글(COMMENT)의 신고 이력을 고유 ID 및 타겟 타입 문자열 형태로 수집합니다.
- **블라인드 (소프트 딜리트)**: 어드민이 신고 대상을 블라인드 처리하면 `isDeleted = true` 및 `deletionReason`이 세팅되며, 프론트엔드에서는 취소선 및 숨김 메시지를 띄웁니다.
- **신고 기각 / 복원 (Dismiss)**:
  * 허위 신고의 경우 관리자가 [신고 기각/복구]를 실행하면 백엔드는 해당 대상에 등록된 모든 `Report` 레코드를 DB에서 영구 삭제합니다.
  * 대상이 이미 소프트 딜리트 처리되어 가려졌던 상태였다면 `isDeleted = false`로 원복시킵니다.
  * 복원 대상이 댓글인 경우, 상위 관계에 있는 게시물(Post) 혹은 공지사항(Notice)의 전체 댓글 카운트(`commentCount`) 값을 정상적으로 다시 1 올려주어 정합성을 정교하게 동기화합니다.

---

## 5. 인앱 알림 센터 및 딥링크 라우팅 흐름

```
   [비동기 이벤트 발행 (AFTER_COMMIT)]
                │
                ▼
   ┌──────────────────────────────┐
   │  Comment / Notice Listener   │
   ├──────────────────────────────┤
   │  1. FCM 푸시 알림 전송        │
   │  2. DB 알림 적재 서비스 호출  │
   └──────────────┬───────────────┘
                  │
                  ▼
   ┌──────────────────────────────┐
   │  NotificationService         │
   │  - 개별 저장 / 일괄 저장      │
   │  - Batch Save 활용 (saveAll) │
   └──────────────┬───────────────┘
```

### 작동 원리
- **비동기 이벤트 기반 처리**: API 응답 지연을 방지하기 위해 댓글 작성 및 공지사항 작성 완료 트랜잭션이 커밋된 후(`TransactionPhase.AFTER_COMMIT`), `@Async`를 통해 별도의 스레드에서 백그라운드로 알림을 전송하고 DB에 저장합니다.
- **수신 대상자 검증**: FCM 토큰의 등록 여부와는 무관하게 사용자의 알림 수신 설정(`noticeEnabled`, `commentEnabled`)이 활성화되어 있다면 인앱 알림 센터를 위해 DB 적재를 수행합니다.
- **성능 최적화**: 공지사항의 경우 전체 회원에게 대량의 알림이 발생하므로, JPA의 `saveAll`을 통한 일괄 저장을 수행하여 데이터베이스 IO 왕복 오버헤드를 경감시켰습니다.
- **딥링크 텔레포트 라우팅**: 알림 아이템 탭 시 읽음 처리(`PUT /notifications/{id}/read`)를 호출하여 읽음 마크를 갱신하고, 해당 알림의 `targetType`과 `targetId`를 넘겨 받아 Flutter의 `DeepLinkLoadingScreen`을 통해 상세 화면으로 즉시 이동시킵니다.
