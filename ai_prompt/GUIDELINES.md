# Y-Sync AI Coding Guidelines & Rules

Y-Sync 프로젝트에서 AI 코딩 어시스턴트가 기능을 구현하거나 코드를 수정할 때 반드시 준수해야 하는 강제적 가이드라인 문서입니다.

---

## 1. Rich Aesthetics UI 디자인 정책 (프론트엔드)

Y-Sync의 UI/UX는 모던하고 프리미엄한 감각을 지향합니다.
* **커스텀 컬러 팔레트**: 브라우저 기본 색상(단순 Red, Blue, Green) 사용을 엄격히 금지합니다. 어두운 네이비 계열의 HSL Tailored Color(`0xFF164687`)와 어우러지는 Amber 포인트 컬러 등을 조화롭게 활용합니다.
* **디자인 요소**: 모서리 곡률(`BorderRadius.circular(10)` 이상), 섀도우 블러 효과, 카드 레이아웃의 투명감(Glassmorphism 느낌)을 살려 고급스러운 분위기를 연출해야 합니다.
* **마이크로 애니메이션**: 버튼의 Hover 효과, 댓글 들여쓰기 꺾임 선 디자인 등 사용자의 동작에 직관적이고 부드럽게 반응하는 디테일을 포함해야 합니다.

---

## 2. 작업 격리 및 로컬 커밋 분리 정책 (Git)

작업 단위별로 Git 커밋을 잘게 쪼개어 아카이빙해야 합니다.
* **단계별 격리**: "대댓글 완료 후 커밋 ➡️ 어드민 완료 후 커밋" 과 같이 논리적인 피처 단계가 끝날 때마다 로컬 커밋을 개별 수행합니다.
* **커밋 전 빌드 검증**: 커밋을 날리기 직전 반드시 백엔드/프론트엔드의 컴파일 빌드 테스트를 통과했는지 확인해야 합니다. 빌드가 깨진 커밋은 원격 저장소에 Push되어서는 안 됩니다.

---

## 3. 백엔드/프론트엔드 빌드 검증 파이프라인

변경 사항이 생기면 아래 명령어로 빌드 안정성을 사전 검사합니다.
* **백엔드 수정 시**
  ```powershell
  ./gradlew compileJava
  ```
  - 반드시 y-sync/backend 경로에서 위 명령을 수행하여 무결성을 통과하는지 확인합니다.
* **프론트엔드 수정 시**
  ```powershell
  flutter build web --release
  ```
  - 반드시 y-sync/frontend 경로에서 위 빌드 명령을 최종 통과해야 합니다.
  - **주의**: 빌드는 마지막에 한 번만 실행하여 불필요한 배포 지연을 방지하십시오.

---

## 4. 윈도우 파워쉘 환경 및 보안 정책 우회 규칙

* **파워쉘 스크립트 차단 에러 대응**: 윈도우 파워쉘 보안 정책(`PSSecurityException`)으로 인해 `firebase` 또는 `npx` 명령 실행 시 스크립트 로드 불가 오류가 발생할 수 있습니다.
* **해결책**: 명령어 뒤에 반드시 **`.cmd` 배치 파일 확장자**를 명시하여 호출합니다.
  - ❌ `firebase deploy --only hosting` (에러 발생 가능)
  - ⭕ `firebase.cmd deploy --only hosting` (정상 작동 보장)

---

## 5. 컨트롤러 NullPointerException(NPE) 방지 및 JWT 가드 규칙

* **빈(Bean) 주입 규칙**: 컨트롤러 내부 핸들러 메소드 매개변수에 `AuthUtil`을 직접 선언하여 요청 맵핑 시 null이 삽입되는 버그를 원천 차단하십시오. 반드시 클래스 필드 주입과 생성자(`@RequiredArgsConstructor`) 주입을 사용해야 합니다.
* **차단 필터 연동**: 신규 API 개발 시 정지 회원(isSuspended)의 접근 제한이 필요한 보안 대상일 경우, 필터 단(`JwtAuthenticationFilter`)에서 처리되므로 별도의 복잡한 차단 검증 코드를 컨트롤러에 중복 구현할 필요가 없습니다.

---

## 6. 로컬 개발 환경 변수 (Environment Variables) 설정 지침

보안 강화를 위해 데이터베이스 접속 비밀번호 및 JWT Secret Key 등의 중요한 설정을 소스코드에서 분리하고 환경변수로 주입받도록 구성되어 있습니다.

### A. 사용되는 환경변수 목록
| 환경변수명 | 설명 | 기본값 (Fallback) |
|---|---|---|
| `DB_URL` | MySQL 접속 URL | `jdbc:mysql://127.0.0.1:3306/ysync_db?...` |
| `DB_USERNAME` | 데이터베이스 계정명 | `root` |
| `DB_PASSWORD` | 데이터베이스 패스워드 | `1234` |
| `JWT_SECRET` | JWT 서명용 비밀키 | `YSyncSuperSecretKeyYSyncSuperSecretKey...` |

### B. 개발 도구(IDE)별 설정 방법
* **IntelliJ IDEA**: 
  1. `Run/Debug Configurations` ➡️ `Edit Configurations...` 선택.
  2. Spring Boot Application 실행 설정 선택 후 `Environment variables` 필드에 입력 (형식: `DB_PASSWORD=your_password;JWT_SECRET=your_secret`).
* **STS / Eclipse**: 
  1. `Run Configurations...` ➡️ `Environment` 탭 선택.
  2. `Add...` 버튼을 눌러 변수명(`DB_PASSWORD`, `JWT_SECRET`)과 값을 기입.

### C. 터미널(CLI) 구동 시 설정 방법
* **Windows (PowerShell)**:
  ```powershell
  $env:DB_PASSWORD="your_db_password"
  $env:JWT_SECRET="your_custom_jwt_secret_key"
  ./gradlew bootRun
  ```
* **Windows (CMD)**:
  ```cmd
  set DB_PASSWORD=your_db_password
  set JWT_SECRET=your_custom_jwt_secret_key
  gradlew bootRun
  ```
* **macOS / Linux**:
  ```bash
  export DB_PASSWORD="your_db_password"
  export JWT_SECRET="your_custom_jwt_secret_key"
  ./gradlew bootRun
  ```
