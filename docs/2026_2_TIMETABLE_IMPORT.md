# 2026학년도 2학기 학과 시간표 등록

## 등록 데이터

- 원본: `2026학년도_2학기_시간표(소프트웨어융합과(26.08.24)).pdf`
- 등록 파일: `docs/data/2026-2-department-timetable.json`
- 총 40개 수업: 1학년 15개, 2학년 13개, 3학년 12개
- 영어트랙은 제외한다.
- 토요일 `자동차구조입문` 사이버 강의는 포함한다.

## 강의실 약어 변환

- 모소: 모바일소프트웨어실습실
- 시프: 시스템프로그래밍실습실
- 디컨: 디지털컨텐츠실습실
- 모인: 모바일 인터넷 실습실
- DB: 데이터베이스실습실

## 운영 등록

`PUT /api/v1/timetable/bulk` API는 기존 학과 시간표 전체를 JSON 목록으로 교체한다. ADMIN 이상의 JWT가 필요하다.

```bash
curl --fail-with-body \
  --request PUT \
  --header "Authorization: Bearer $YSYNC_ADMIN_TOKEN" \
  --header "Content-Type: application/json" \
  --data-binary @docs/data/2026-2-department-timetable.json \
  "$YSYNC_API_BASE_URL/timetable/bulk"
```

일괄 등록은 트랜잭션으로 처리되며, 같은 학년·반·요일의 교시가 겹치면 기존 시간표를 지우지 않고 요청 전체를 거부한다.
