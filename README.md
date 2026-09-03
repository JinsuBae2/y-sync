# Y-Sync

영남이공대학교 소프트웨어융합과 학생을 위한 학사 정보·커뮤니티 통합 서비스입니다.

[![CI](https://github.com/JinsuBae2/y-sync/actions/workflows/ci.yml/badge.svg)](https://github.com/JinsuBae2/y-sync/actions/workflows/ci.yml)
[![Production Deploy](https://github.com/JinsuBae2/y-sync/actions/workflows/deploy-production.yml/badge.svg)](https://github.com/JinsuBae2/y-sync/actions/workflows/deploy-production.yml)

## 서비스 바로가기

- 운영 PWA: [y-sync-31c03.web.app](https://y-sync-31c03.web.app)
- 저장소: [github.com/JinsuBae2/y-sync](https://github.com/JinsuBae2/y-sync)

## 주요 기능

- 학번 사전 등록과 학교 이메일 인증 기반 회원가입
- 학과 공지사항 조회·검색·학년별 필터 및 중요 공지 알림
- 익명/기명 커뮤니티 게시글, 이미지, 댓글·답글, 신고와 스크랩
- 학사 일정과 학년별 학과 시간표 조회
- 학생 개인 시간표 추가·수정·삭제
- 앱 내 알림 센터와 Firebase Cloud Messaging 푸시 알림
- 학생, 학과 관리자, 총괄 관리자 역할별 관리 기능

## 기술 스택

| 영역 | 기술 |
| --- | --- |
| Frontend | Flutter Web/PWA, Dart, Riverpod, Dio |
| Backend | Java 21, Spring Boot 4, Spring Security, Spring Data JPA |
| Database | MySQL 8, H2(Test) |
| Notification | Firebase Cloud Messaging |
| Infrastructure | Oracle Cloud Ubuntu, Docker Compose, Nginx, Certbot |
| Hosting | Firebase Hosting |
| CI/CD | GitHub Actions |

## 시스템 구성

```text
Flutter Web/PWA
      │ HTTPS / JWT
      ▼
Nginx ── Spring Boot API ── MySQL
              │
              └── Firebase Cloud Messaging
```

상세 구조는 [아키텍처 문서](docs/ARCHITECTURE.md)에서 확인할 수 있습니다.

## 저장소 구조

```text
y-sync/
├── frontend/       # Flutter Web/PWA 애플리케이션
├── backend/        # Spring Boot API 서버
├── docker/         # MySQL, Backend, Nginx, Certbot 운영 구성
├── docs/           # 기능·API·아키텍처·운영 문서와 작업 이력
└── .github/        # CI 및 운영 배포 워크플로
```

## 로컬 실행

### 사전 요구사항

- Flutter 3.41.4
- JDK 21
- MySQL 8

### Backend

로컬 MySQL에 `ysync_db` 데이터베이스를 준비하고 필요한 환경변수를 설정합니다.

```bash
cd backend
export DB_URL='jdbc:mysql://127.0.0.1:3306/ysync_db?serverTimezone=Asia/Seoul&characterEncoding=UTF-8'
export DB_USERNAME='your_db_username'
export DB_PASSWORD='your_db_password'
export JWT_SECRET='your_jwt_secret'
export MAIL_USERNAME='your_mail_username'
export MAIL_PASSWORD='your_mail_password'
./gradlew bootRun
```

Firebase Admin 서비스 계정은 Git에 추가하지 말고, 필요한 경우 `FIREBASE_CONFIG_PATH`로 안전한 로컬 경로를 지정합니다.

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

다른 API를 사용할 때는 빌드 인자로 주소를 주입합니다.

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8080/api/v1 \
  --dart-define=IMAGE_BASE_URL=http://localhost:8080
```

## 검증

```bash
# Backend
cd backend
./gradlew test bootJar

# Frontend
cd frontend
flutter analyze
flutter test
flutter build web --release

# Docker Compose
docker compose -f docker/docker-compose.yml config
```

## 브랜치와 배포

- `main`: 운영 브랜치
- `develop`: 통합 브랜치
- 모든 변경은 `feature/*`, `fix/*`, `docs/*` 브랜치에서 시작합니다.
- 작업 브랜치는 CI 통과 후 `develop`에 병합합니다.
- 운영 배포는 `develop`에서 `main`으로 PR을 생성하고 승인된 GitHub Actions 워크플로로 진행합니다.

자세한 개발·배포 규칙은 [개발 가이드](docs/DEVELOPMENT.md)와 [macOS 운영 가이드](docs/MAC_MIGRATION_GUIDE.md)를 참고하세요.

## 문서

- [서비스 컨텍스트와 기능 명세](docs/CONTEXT.md)
- [API 명세](docs/API_SPECIFICATION.md)
- [시스템 아키텍처](docs/ARCHITECTURE.md)
- [개발 규칙](docs/DEVELOPMENT.md)
- [보안 운영 기준](docs/SECURITY.md)
- [문제 해결 기록](docs/TROUBLESHOOTING.md)
- [작업 이력](docs/WORK_LOG.md)

## 보안 원칙

비밀번호, JWT 비밀키, Firebase 서비스 계정, 메일 앱 비밀번호와 운영 계정 정보는 저장소에 커밋하지 않습니다. 운영 비밀값은 GitHub Environment Secrets, 운영 서버 또는 OS의 안전한 비밀 저장소에서 관리합니다.
