# 백로그

작업하다 발견했지만 당장 손대지 않은 것들입니다. 급한 순서가 아니라 발견 순서로 적습니다.
처리된 항목은 지우고 `docs/WORK_LOG.md`에 남깁니다.

---

## 그 외 미뤄 둔 것

- **커뮤니티 목록 페이징** — `/community`가 전체를 한 번에 돌려줍니다. 글이 쌓이면 응답이 계속 커집니다. `/scraps`, `/notifications`, `/members/me/posts`, `/admin/reports`도 같습니다. 공지처럼 "못 본다"가 아니라 "느려진다"라 덜 급합니다.
- **공지 검색 인덱스** — `LIKE %kw%`라 `idx_notice_feed`를 타지 못합니다. 공지 건수가 적어 지금은 수용하고, 커지면 전문 검색을 검토합니다.
- **DB 전용 계정 전환** — 앱이 운영 MySQL에 `root`로 붙습니다. `ddl-auto=validate` 전환으로 앱에 DDL 권한이 더는 필요 없어져 지금은 가능합니다.
- **Flyway/Liquibase** — `validate` 전환으로 스키마 변경 수단이 없습니다. 다음에 엔티티를 바꿀 일이 생기면 그때가 도입 시점입니다.
- **커스텀 예외** — 실패가 전부 `IllegalArgumentException`이라 400·404·409를 구분하지 못합니다.
- **`csv_picker_web.dart`의 `dart:html`** — `file_picker` 13이 웹까지 커버하므로 아마 이전이 아니라 조건부 import 3파일을 1파일로 합치고 삭제하면 끝납니다. 관리자 계정으로 명단 업로드를 확인할 수 있을 때.
