# Y-Sync Database Schema & Seed Data Guide

Y-Sync 프로젝트의 로컬 개발 및 QA 테스트를 원활하게 진행하기 위한 데이터베이스 스키마 구조 요약과 사전등록 테스트용 시드 데이터(Seed Data) 주입 가이드입니다.

---

## 1. 핵심 데이터베이스 스키마 구조 (DDL 요약)

```
┌──────────────┐      1:N      ┌──────────────────┐      1:N      ┌──────────────┐
│    MEMBER    ├──────────────►│  COMMUNITY_POST  ├──────────────►│   COMMENT    │
│  - id (PK)   │               │  - id (PK)       │               │  - id (PK)   │
│  - login_id  │               │  - member_id(FK) │               │  - parent_id │
└──────┬───────┘               └──────────────────┘               └──────┬───────┘
       │                                                                 │
       └───────────────────────── 1:N ───────────────────────────────────┘
```

### 주요 테이블 정보 및 제약조건
* **MEMBER (회원)**
  - `login_id`: 학번(유니크 인덱스). 회원가입 시 사전 등록 여부를 체크하는 기준 값입니다.
  - `is_activated`: 이메일 인증을 완료하여 가입이 승인되었는지 여부 (기본값 `false`).
  - `is_suspended`: 관리자에 의해 서비스 이용이 정지되었는지 여부 (기본값 `false`).
* **COMMUNITY_POST (게시물)**
  - `member_id`: 작성자 연관관계 (Foreign Key).
  - `is_deleted`: 논리 삭제(블라인드) 플래그.
* **COMMENT (댓글 / 자기참조)**
  - `parent_id`: 상위 댓글 식별키 (Self-Referencing FK). 루트 댓글인 경우 `null`.
  - `is_deleted`: 논리 삭제 플래그.
* **REPORT (신고)**
  - `target_type`: `"POST"` 혹은 `"COMMENT"` 문자열.
  - `target_id`: 신고 대상의 PK 식별자.

---

## 2. 테스트용 사전등록 학번 시드 데이터 (SQL INSERT)

Y-Sync의 가입 인증 테스트 및 기능 점검을 위해 로컬 데이터베이스 구동 시 아래 SQL 쿼리셋을 사용하여 테스트 환경을 구성할 수 있습니다.

```sql
-- 1. 테스트용 사전등록 학생 데이터 (아직 회원가입 안 한 학생 - 이메일 가입 테스트용)
INSERT INTO member (login_id, name, password, role, provider, auth_type, is_activated, is_suspended, notice_enabled, comment_enabled, created_at)
VALUES 
('20260001', '홍길동', '$2a$10$TEMP_HASH_PASSWORD_STRING_SIGNUP_WAITING', 'USER', 'LOCAL', 'PASSWORD', false, false, true, true, NOW()),
('20260002', '이순신', '$2a$10$TEMP_HASH_PASSWORD_STRING_SIGNUP_WAITING', 'USER', 'LOCAL', 'PASSWORD', false, false, true, true, NOW());

-- 2. 이미 활성화 완료된 일반 사용자 테스트용 계정 (학번: 20268888, 비번: test1234!)
-- 패스워드 해시값은 BCryptPasswordEncoder 기준입니다.
INSERT INTO member (login_id, name, password, role, provider, auth_type, is_activated, is_suspended, notice_enabled, comment_enabled, created_at)
VALUES 
('20268888', '일반테스터', '$2a$10$wK1mYp60c3nSwTj.Dqj7OOFN7Qn2fWwS5QYxZ1X8j.c/0L.e65c52', 'USER', 'LOCAL', 'PASSWORD', true, false, true, true, NOW());

-- 3. 이미 활성화 완료된 학과 관리자 테스트용 계정 (학번: 20269999, 비번: admin1234!)
INSERT INTO member (login_id, name, password, role, provider, auth_type, is_activated, is_suspended, notice_enabled, comment_enabled, created_at)
VALUES 
('20269999', '학과관리자', '$2a$10$H8z/8iC/6pL.2wSw9k9oOOFN7Qn2fWwS5QYxZ1X8j.c/0L.e65c52', 'ADMIN', 'LOCAL', 'PASSWORD', true, false, true, true, NOW());

-- 4. 차단(정지) 계정 테스트용 데이터 (학번: 20267777, 비번: test1234!)
INSERT INTO member (login_id, name, password, role, provider, auth_type, is_activated, is_suspended, notice_enabled, comment_enabled, created_at)
VALUES 
('20267777', '악성사용자', '$2a$10$wK1mYp60c3nSwTj.Dqj7OOFN7Qn2fWwS5QYxZ1X8j.c/0L.e65c52', 'USER', 'LOCAL', 'PASSWORD', true, true, true, true, NOW());
```

---

## 3. 로컬 개발 환경에서 시드 데이터 주입 및 테스트 실행 방법

### A. H2 Database Console 사용 (로컬 메모리 DB 환경)
1. 백엔드 어플리케이션을 가동하고 `http://localhost:8080/h2-console` 로 브라우저에서 접속합니다.
2. JDBC URL에 `jdbc:h2:mem:ysync_db` (혹은 application.properties에 기입된 로컬 H2 경로)를 입력하고 **Connect**합니다.
3. 쿼리 입력 창에 위의 **시드 데이터 SQL**을 붙여넣고 **Run** 버튼을 클릭하여 데이터를 영입합니다.

### B. 로컬 MySQL Docker 가동 환경
도커 컴포즈로 로컬 개발용 MySQL 데이터베이스가 올라가 있는 경우, CLI 터미널에서 다음 명령어로 직접 접속하여 주입합니다.
```bash
# MySQL 컨테이너 내부로 진입 및 쿼리 실행
docker exec -it ysync-mysql mysql -u root -p ysync_db

# (비밀번호 1234 입력 후 SQL 문 실행)
```
