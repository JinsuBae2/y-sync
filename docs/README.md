# Y-Sync 문서 안내

어떤 문서를 봐야 하는지 먼저 정하기 위한 목차입니다. 문서는 목적별로 하나씩만 두고, 같은 내용을 여러 곳에 두지 않습니다.

## 무엇을 찾고 있나요

| 하려는 일 | 볼 문서 |
|---|---|
| 서비스가 무엇이고 어떻게 굴러가는지 알고 싶다 | [서비스 기능과 시스템 아키텍처](ARCHITECTURE.md) |
| API 요청·응답 규격을 확인하고 싶다 | [API 명세](API_SPECIFICATION.md) |
| 개발 환경을 만들고 코드를 올리고 배포하고 싶다 | [개발 가이드](DEVELOPMENT.md) |
| 보안 기준과 운영 원칙을 확인하고 싶다 | [보안 운영 기준](SECURITY.md) |
| 겪은 장애의 원인과 대응을 찾고 싶다 | [문제 해결 기록](TROUBLESHOOTING.md) |
| 언제 무엇을 왜 바꿨는지 알고 싶다 | [작업 이력](WORK_LOG.md) |

## 문서별 성격

**상시 기준 문서** — 현재 상태를 기술하며 변경이 생기면 갱신합니다.

- [ARCHITECTURE.md](ARCHITECTURE.md) — 서비스 개요, 사용자와 역할, 기능 흐름, 기술 스택, 패키지 구조, 데이터 모델, 인프라 배포 스펙
- [API_SPECIFICATION.md](API_SPECIFICATION.md) — 엔드포인트별 요청·응답과 접근 권한
- [DEVELOPMENT.md](DEVELOPMENT.md) — 코딩 규칙, 디자인 시스템, Git 전략, macOS 개발 환경 구성, 로컬 검증 절차, 자격 증명 관리, 운영 서버 점검
- [SECURITY.md](SECURITY.md) — 보안 운영 기준

**기록 문서** — 특정 시점의 사실을 남기며 나중에 고쳐 쓰지 않습니다.

- [WORK_LOG.md](WORK_LOG.md) — 기능 개발, 버그 수정, 설정 변경, 배포와 장애 대응을 육하원칙으로 남기는 작업 원장
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — 재발할 수 있는 장애의 증상, 원인, 대응
- [LOAD_TEST.md](LOAD_TEST.md) — 운영 조회 부하테스트 결과
- [2026_2_TIMETABLE_IMPORT.md](2026_2_TIMETABLE_IMPORT.md) — 2026학년도 2학기 학과 시간표 등록 내역

**절차 문서** — 실행 전에 순서대로 따라야 하는 운영 작업입니다.

- [DDL_AUTO_MIGRATION.md](DDL_AUTO_MIGRATION.md) — `ddl-auto`를 `update`에서 `validate`로 전환하는 절차

## 첨부 자료

- `data/` — 문서가 참조하는 원본 데이터 파일
- `images/` — 아키텍처·시퀀스 다이어그램 이미지

## 문서를 추가하기 전에

새 파일을 만들기 전에 위 문서 중 들어갈 곳이 있는지 먼저 확인합니다. 한 번 쓰고 끝나는 조사 기록이나 기능별 안내는 별도 파일로 두지 말고 해당 기록 문서에 절로 추가합니다. 조사가 끝나 결론이 난 임시 문서는 결론을 기록 문서로 옮기고 삭제합니다.
