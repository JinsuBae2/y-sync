# 공지사항 커서 기반 무한 스크롤

## Context

`noticesProvider`(`frontend/lib/providers/notice_provider.dart:42`)가 `/notices`를 페이지 지정 없이 부르고 응답의 `content`만 꺼내 씁니다. Spring 기본 페이지 크기가 20이고 화면에는 `ListView.separated` 하나뿐이라 **21번째 공지부터 학생이 접근할 방법이 없습니다.** 운영 공지가 이미 20건을 넘었으므로 지금 실제로 못 보고 있는 글이 있습니다.

목표는 세 가지입니다.

1. 10건씩 커서 기반으로 이어 받는 무한 스크롤
2. offset이 아닌 커서 페이징 — 스크롤 중 새 공지가 올라와도 목록이 밀리거나 중복되지 않게
3. 스크롤 도중 새 공지가 올라오면 "새 공지 N개" 칩을 띄우고, 탭하면 최상단으로

---

## 설계

### 1. 고정 공지는 커서에서 분리한다

현재 정렬은 `isPinned DESC, createdAt DESC`입니다(`NoticeRepository:22`). 고정 공지는 날짜와 무관하게 위로 뜨므로 `(createdAt, id)` 커서 하나로는 고정/일반 경계를 넘을 때 깨집니다.

**첫 요청에서만 고정 공지 전량을 함께 내려주고, 커서는 일반 공지에만 적용합니다.** 고정 공지는 몇 건 안 되고, 스크롤 도중 중간에 끼어들지 않아 UX도 낫습니다. 대안인 `(isPinned, createdAt, id)` 3중 커서는 정확하지만 쿼리와 경계 테스트가 훨씬 복잡합니다.

### 2. 커서는 `(createdAt, id)` 복합 키

`createdAt`은 UNIQUE가 아닙니다. 같은 시각에 두 건이 들어오면 커서가 행을 건너뛰거나 중복시키므로 `id`를 tie-breaker로 함께 씁니다.

```sql
WHERE is_pinned = false
  AND (created_at < :c OR (created_at = :c AND id < :i))
ORDER BY created_at DESC, id DESC
LIMIT :size + 1        -- +1로 hasNext 판정
```

커서는 Base64URL로 인코딩해 불투명하게 넘깁니다. 클라이언트가 내부 구조에 의존하지 않게 하기 위함입니다. 파싱 실패는 400으로 돌려줍니다(조용히 첫 페이지로 폴백하면 버그를 숨깁니다).

### 3. ⚠️ 인덱스 — `validate` 전환 후 첫 수동 DDL

운영 `notice` 테이블에는 PK와 `author_id` FK 인덱스뿐입니다(스키마 덤프 확인). 인덱스 없이는 커서 쿼리가 풀스캔 + 정렬입니다.

```sql
ALTER TABLE notice ADD INDEX idx_notice_feed (is_pinned, created_at, id);
```

엔티티에는 `@Table(indexes = ...)`로 선언해 스키마와 코드가 어긋나지 않게 합니다.

> **정정 — Hibernate `validate`는 인덱스를 검증하지 않습니다.**
> 계획 단계에서는 UNIQUE 제약 때와 같이 "DDL을 먼저 넣지 않으면 기동 실패"로 적었지만, 구현하며 확인한 결과 스키마 검증 대상은 테이블·컬럼·시퀀스이고 인덱스는 포함되지 않습니다. 즉 이 DDL을 적용하지 않아도 **배포는 성공하고 조회만 느려집니다.** 순서 사고의 위험은 없지만, 인덱스 없이는 커서 조회가 풀스캔 후 정렬이라 반드시 적용해야 합니다.

검색(`keyword`)은 `LIKE %kw%`라 이 인덱스를 타지 못합니다. 공지 건수가 적어 지금은 수용하고, 커지면 전문 검색을 별도로 검토합니다.

### 4. 학년 필터를 서버로 옮긴다 (필수)

지금은 클라이언트가 받은 목록을 필터합니다(`notice_list_screen.dart:156-164`). **무한 스크롤과 양립할 수 없습니다** — 10건 받아 필터하면 0건이 남을 수 있고, 그게 "끝"인지 "이 페이지에 없음"인지 구분할 수 없습니다.

기존 의미를 그대로 옮깁니다: `grade=ALL`이면 조건 없음, 그 외에는 `targetGrade IN ('ALL', :grade)`.

### 5. 새 공지 감지

커서 페이징이라 최신 `id`만 알면 됩니다.

```
GET /api/v1/notices/feed/updates?sinceId=1234&grade=&keyword=
→ { "newCount": 3 }        // 상한 99
```

클라이언트는 60초 주기 + 앱 복귀(`AppLifecycleState.resumed`) 시 1회 폴링합니다. 공지는 자주 올라오지 않으므로 60초면 충분합니다.

`newCount > 0`이고 스크롤이 최상단이 아닐 때만 칩을 띄웁니다. 최상단에 있어도 목록에 자동 삽입하지 않습니다 — 읽는 중에 목록이 튀는 것을 막습니다.

### 6. 하위 호환 — 새 엔드포인트를 추가한다

기존 `GET /notices`(Page)와 `GET /notices/search`는 **그대로 둡니다.** 홈 화면(`home_provider.dart:12`)이 `page=0&size=20`으로 쓰고 있고, 캐시된 구버전 PWA도 있습니다. `docs/SECURITY_FIX_PLAN.md` #10이 정한 "새 엔드포인트 추가 → 클라이언트 이전 후 폐기" 방침을 따릅니다.

홈 화면은 최근 공지 미리보기라 무한 스크롤이 필요 없으므로 손대지 않습니다.

---

## API

```
GET /api/v1/notices/feed?cursor=&size=10&grade=ALL&keyword=

{
  "pinned":     [NoticeResponse],   // cursor 없을 때만 채움
  "items":      [NoticeResponse],   // 일반 공지, 최신순
  "nextCursor": "eyJ0Ijoi...",      // 마지막 페이지면 null
  "hasNext":    true,
  "latestId":   1234                // 새 공지 감지 기준
}
```

`size`는 기본 10, 최대 30으로 서버에서 상한을 겁니다.

---

## 작업 순서

1. ✅ **계획서를 `docs/NOTICE_FEED_PLAN.md`로 커밋**
2. ✅ **백엔드**
   - `NoticeRepository` — 커서 조회 4종(고정 / 커서 없음 / 커서 있음 / keyword 조합), `updates` 카운트
   - `NoticeService.getFeed(cursor, size, grade, keyword)`, `countNewerThan(...)`
   - `NoticeFeedResponse` DTO, 커서 인코딩/디코딩 유틸
   - `NoticeController` — `GET /notices/feed`, `GET /notices/feed/updates`
   - `Notice` 엔티티에 `@Table(indexes = ...)` 선언
3. ⬜ **운영 인덱스 DDL 적용** (배포 전, 수동)
4. ✅ **프론트**
   - `noticeFeedProvider` — `{pinned, items, nextCursor, hasNext, latestId}` 상태를 들고 `loadMore()` 제공
   - `notice_list_screen` — `ScrollController`로 끝 근처에서 `loadMore()`, 이미 있는 id는 건너뜀
   - 학년 필터·검색어 변경 시 커서 초기화 후 재조회
   - `_NewNoticeChip` — 폴링 결과와 스크롤 위치에 따라 노출, 탭하면 최상단 + 새로고침
5. ✅ **검증 → PR**

---

## 검증

**백엔드 테스트**

- 같은 `createdAt`을 가진 공지 3건에서 커서가 행을 건너뛰거나 중복하지 않는다
- `size + 1` 조회로 `hasNext`가 정확하고, 마지막 페이지에서 `nextCursor`가 null이다
- 고정 공지는 첫 페이지에만 오고 커서 페이지에는 오지 않는다
- `grade=GRADE_1`이 `ALL` + `GRADE_1`만 돌려준다 — **기존 클라이언트 필터와 결과가 같은지**가 핵심
- `keyword` + `cursor` 조합이 동작한다
- 깨진 커서는 400
- `updates?sinceId=`가 새 공지 수를 정확히 센다

**프론트 테스트**

- 스크롤 끝에 닿으면 다음 페이지를 요청한다
- `hasNext=false` 이후로는 더 요청하지 않는다
- 학년/검색어를 바꾸면 처음부터 다시 로드한다
- `newCount > 0` + 최상단이 아닐 때만 칩이 보인다

**수동 확인**

빌드한 웹을 운영과 같은 CSP 헤더로 로컬 서빙해 브라우저에서 스크롤·필터·검색·칩을 직접 확인합니다(오늘 쓴 방법 그대로).

---

## 리스크

| 리스크 | 대응 |
|---|---|
| 인덱스 DDL 누락 → 커서 조회가 풀스캔 | 기동은 성공하므로 놓치기 쉽습니다. 배포 전 수동 적용하고 `WORK_LOG`에 기록 |
| 학년 필터 서버 이관은 실제 동작 변경 | 기존 클라이언트 필터와 같은 결과를 내는지 테스트로 고정 |
| 검색은 인덱스를 못 탄다 | 현재 공지 건수에서는 수용. 계획서에 명시하고 커지면 재검토 |
| 구버전 PWA가 캐시에 남아 있음 | 기존 `/notices` 유지 |
