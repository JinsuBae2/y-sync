# Y-Sync Development Guidelines & Conventions

이 문서는 Y-Sync 프로젝트 개발 시 모든 개발자와 AI 어시스턴트가 준수해야 하는 코딩 규칙, 디자인 시스템, Git 협업 전략 및 환경 구성 가이드라인을 하나로 통합한 메인 개발 표준 명세서입니다.

---

## 1. AI 코딩 어시스턴트 지침 및 강제 규칙 (Guidelines)

### A. Rich Aesthetics UI 디자인 정책
* **커스텀 컬러 팔레트 준수**: 단순 브라우저 기본 색상(단순 Red, Blue, Green) 사용을 엄격히 금지합니다. 어두운 네이비 계열의 HSL Tailored Color(`0xFF164687`)와 어우러지는 Amber 포인트 컬러 등을 조화롭게 활용합니다.
* **디자인 완성도**: 모서리 곡률(`BorderRadius.circular(10)` 이상), 섀도우 블러 효과, 카드 레이아웃의 투명감(Glassmorphism 느낌)을 살려 고급스러운 분위기를 연출해야 합니다.
* **마이크로 애니메이션**: 버튼의 Hover 효과, 댓글 들여쓰기 꺾임 선 디자인 등 사용자의 동작에 직관적이고 부드럽게 반응하는 디테일을 포함해야 합니다.

### B. 작업 격리 및 로컬 커밋 분리 정책 (Git)
* **단계별 격리**: "대댓글 완료 후 커밋 ➡️ 어드민 완료 후 커밋" 과 같이 논리적인 피처 단계가 끝날 때마다 로컬 커밋을 개별 수행합니다.
* **커밋 전 빌드 검증**: 커밋을 날리기 직전 반드시 백엔드/프론트엔드의 컴파일 빌드 테스트를 통과했는지 확인해야 합니다. 빌드가 깨진 커밋은 원격 저장소에 Push되어서는 안 됩니다.

### C. 백엔드/프론트엔드 빌드 검증 파이프라인
변경 사항이 생기면 아래 명령어로 테스트와 빌드 안정성을 사전 검사합니다.
* **백엔드 수정 시**: `y-sync/backend` 경로에서 가까운 단위 테스트를 먼저 실행하고, 완료 시 `./gradlew test bootJar`로 전체 검증합니다.
* **프론트엔드 수정 시**: `y-sync/frontend` 경로에서 가까운 테스트와 `flutter analyze`를 먼저 실행하고, 완료 시 `flutter test && flutter build web --release`로 전체 검증합니다.
* **설정 수정 시**: `docker compose -f docker/docker-compose.yml config`와 CI의 운영 포트 노출 검사를 통과해야 합니다.

### D. OS별 CLI 환경 및 명령 우회 규칙 (Windows vs Mac)
* **Windows 파워쉘 스크립트 우회**: 윈도우 파워쉘 보안 정책(`PSSecurityException`)으로 인해 `firebase` 명령 실행 시 `.cmd` 확장자를 붙여 호출합니다.
  - ❌ Windows: `firebase deploy --only hosting` (에러 발생 가능)
  - ⭕ Windows: `firebase.cmd deploy --only hosting` (정상 작동 보장)
* **macOS (Mac) 터미널 환경**: Mac Zsh/Bash 터미널 환경에서는 `.cmd` 없이 표준 CLI 명령어를 사용합니다.
  - ⭕ macOS: `firebase deploy --only hosting`
  - 💡 Mac 환경 세팅 및 전체 이관 방법은 [MAC_MIGRATION_GUIDE.md](./MAC_MIGRATION_GUIDE.md) 가이드 문서를 참고하십시오.

### E. 컨트롤러 NPE 방지 및 JWT 가드 규칙
* **빈(Bean) 주입 규칙**: 컨트롤러 내부 핸들러 메소드 매개변수에 `AuthUtil`을 직접 선언하여 요청 맵핑 시 null이 삽입되는 버그를 원천 차단하십시오. 반드시 클래스 필드 주입과 생성자(`@RequiredArgsConstructor`) 주입을 사용해야 합니다.
* **차단 필터 연동**: 신규 API 개발 시 정지 회원(isSuspended)의 접근 제한이 필요한 보안 대상일 경우, 필터 단(`JwtAuthenticationFilter`)에서 처리되므로 별도의 복잡한 차단 검증 코드를 컨트롤러에 중복 구현할 필요가 없습니다.

### F. 육하원칙 작업 이력 기록
* 모든 기능 개발, 버그 수정, 운영 설정 변경, 배포 및 장애 대응은 완료 시 [WORK_LOG.md](./WORK_LOG.md)에 기록합니다.
* 각 기록은 **누가(Who), 언제(When), 어디서(Where), 무엇을(What), 왜(Why), 어떻게(How)**를 빠짐없이 작성합니다.
* 관련 브랜치, 코드 커밋, PR, 검증 명령과 결과, 배포 상태를 함께 적어 소스와 운영 상태를 추적할 수 있어야 합니다.
* 작업 순서는 `구현 및 검증 → 코드 커밋 → WORK_LOG 갱신 → 문서 커밋`을 기본으로 합니다. PR 병합이나 배포가 나중에 완료되면 같은 항목의 상태를 후속 문서 커밋으로 갱신합니다.
* 비밀번호, JWT, 개인키, Firebase 서비스 계정 원문, 사용자 개인정보는 기록하지 않습니다. 비밀값은 저장 위치와 회전 여부만 기록합니다.

---

## 2. 개발 환경 변수 (Environment Variables) 설정

보안 강화를 위해 데이터베이스 접속 비밀번호 및 JWT Secret Key 등의 중요한 설정을 소스코드에서 분리하고 환경변수로 주입받도록 구성되어 있습니다.

### A. 사용되는 환경변수 목록
| 환경변수명 | 설명 | 기본값 (Fallback) |
|---|---|---|
| `DB_URL` | MySQL 접속 URL | `jdbc:mysql://127.0.0.1:3306/ysync_db?...` |
| `DB_USERNAME` | 데이터베이스 계정명 | `root` |
| `DB_PASSWORD` | 데이터베이스 패스워드 | `[your_db_password]` |
| `JWT_SECRET` | JWT 서명용 비밀키 | `[your_jwt_secret_key]` |

### B. 개발 도구(IDE)별 설정 방법
* **IntelliJ IDEA**: `Run/Debug Configurations` ➡️ `Edit Configurations...` ➡️ Spring Boot Application 실행 설정 ➡️ `Environment variables` 필드에 입력 (형식: `DB_PASSWORD=your_password;JWT_SECRET=your_secret`).
* **STS / Eclipse**: `Run Configurations...` ➡️ `Environment` 탭 ➡️ `Add...` 버튼을 눌러 변수명과 값을 기입.

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

---

## 3. 코드 스타일 및 코딩 규칙 (Code Style)

### A. 주석 작성 규칙 (Commenting Policy)
* **전두 이모지(💡) 및 대괄호 활용**: 새로 구현되거나 수정된 로직에는 반드시 한글 설명 전두에 **전구 이모지(`💡`)**를 필수로 삽입합니다.
  - 예: `// 💡 대댓글(답글) 작성 시 선택된 부모 댓글 상태를 포스트 ID별로 추적하는 Notifier`
* **버그 픽스 및 보완**: 특정 버그 해결 과정에서 추가된 코드에는 버그 ID나 라벨을 명시합니다.
  - 예: `// 💡 [Bug4 Fix] 커뮤니티 목록 갱신을 위해 추가`
  - 예: `// 💡 [FCM 마운트] 외부 파이어베이스 키 설정 경로 지정`
* **한글 주석 원칙**: 소스 코드 내의 모든 설명 주석은 **한국어**로 작성하며, 단순히 "코드 추가"라고 적기보다 **"왜 이 코드가 이 시점에 필요했는지"** 맥락과 부연 설명을 상세하고 친절하게 기입합니다.
* **소스 코드 보존 정책**: 수정을 요청받지 않은 영역의 기존 주석, 영문 설명문, Javadoc 다큐멘테이션은 절대로 임의로 지우거나 훼손하지 않고 원본 그대로 보존합니다. (불필요한 리포맷팅으로 Git Diff를 크게 만들지 마십시오.)

### B. 백엔드 코딩 규칙 (Java/Spring Boot)
* **네이밍 컨벤션**:
  - 클래스 및 인터페이스: PascalCase (예: `AdminMemberController`, `MemberRepository`)
  - 메소드 및 변수: camelCase (예: `dismissReport()`, `isAuthorSuspended`)
  - 데이터베이스 테이블 및 컬럼: snake_case (예: `member_id`, `is_deleted`)
* **DTO 정의**:
  - Request DTO는 요청 성격이 명확히 보이도록 접미사를 맞춥니다 (예: `ReportDismissRequest`).
  - Response DTO는 응답 구조를 명확히 투영하도록 설계합니다 (예: `AdminReportSummaryResponse`).
  - boolean 필드의 공식 JSON 키가 `isX`라면 `@JsonProperty("isX")`를 명시하고 Jackson 직렬화 테스트를 추가합니다. Lombok이 `isX`를 `x`로 자동 변경하도록 두지 않습니다.
  - 점진 배포 중인 Flutter 파서는 공식 `isX` 키를 우선 사용하고 기존 `x` 키를 fallback으로 허용하며, 모델 테스트로 두 형식을 모두 검증합니다.
* **JPA 제약 조건 명시**: 엔티티 필드 선언 시 `@Column(nullable = false, length = ...)` 등 데이터베이스 수준의 제약 조건을 명시적으로 기입하여 데이터 정합성을 보장합니다.

### C. 프론트엔드 코딩 규칙 (Dart/Flutter)
* **네이밍 컨벤션**:
  - 파일 및 디렉토리: snake_case (예: `admin_post_management_screen.dart`, `admin_provider.dart`)
  - 클래스 및 위젯: PascalCase (예: `AdminPostManagementScreen`)
  - 변수 및 함수: camelCase (예: `fetchPendingRequests()`, `_isSubmitting`)
* **Riverpod 3.x 상태 명명 규칙**:
  - `Notifier` 클래스: PascalCase + `Notifier` 접미사 (예: `ActiveParentCommentNotifier`)
  - `Provider` 변수: camelCase + `Provider` 접미사 (예: `activeParentCommentProvider`)
  - Notifier 내부 상태 수정 메소드는 `updateState(Value)` 또는 `set(Value)` 로 통일하여 직관성을 높입니다.

---

## 4. UI/UX 디자인 시스템 (Design System)

### A. 컬러 팔레트 (Color Palette)
| 색상 구분 | Hex Code | Flutter 표현 | 주로 사용되는 위치 |
|---|---|---|---|
| **Primary (Portal Blue)** | `#164687` | `Color(0xFF164687)` | 앱바 배경, 활성화 탭, 메인 액션 버튼, 강조 링크 |
| **Secondary (Amber)** | `#FFBF00` | `Color(0xFFFFBF00)` | 알림 뱃지, 중요 포인트 아이콘, 서브 강조 요소 |
| **Danger (Alert Red)** | `#E53935` | `Colors.redAccent` | 삭제/신고/블라인드/차단 관련 경고 버튼 및 칩 |
| **Success (Green)** | `#43A047` | `Colors.green.shade600` | 인증 성공, 복구 완료 스낵바, 정상 상태 칩 |
| **Background (Light)** | `#F9F9F9` | `Colors.grey.shade50` | 기본 스크롤 스크린 배경색 |
| **Card / Dialog Surface**| `#FFFFFF` | `Colors.white` | 개별 콘텐츠 리스트 카드 타일, 팝업 바디 |

### B. 타이포그래피 (Typography)
* **글꼴**: 모바일 및 웹 크로스 플랫폼 렌더링 시 브라우저 기본 서체를 지양하고 `Outfit` 또는 `Inter` 글꼴군을 적용하여 고급스럽고 명확한 가독성을 제공합니다.
* **글자 크기 스케일 (Typography Scale)**:
  - **Header 1 (대제목)**: `fontSize: 18`, `fontWeight: FontWeight.w800` (앱바 타이틀 등)
  - **Header 2 (게시글 제목)**: `fontSize: 15~16`, `fontWeight: FontWeight.bold`, `color: Colors.black87`
  - **Body (본문/내용)**: `fontSize: 13~14`, `fontWeight: FontWeight.normal`, `color: Colors.black54`
  - **Caption (메타데이터)**: `fontSize: 11`, `fontWeight: FontWeight.normal`, `color: Colors.black38` (작성 시간, 카테고리 태그 등)

### C. 컴포넌트 디자인 규칙 (Component Standards)
* **카드 레이아웃 (Card & Tiles)**: 그림자를 최소화하고 테두리를 정교화하여 Sleek Flat 스타일을 적용합니다. (`elevation: 0`을 사용하고 모서리가 둥근 테두리 선을 룰로 두릅니다.)
  ```dart
  Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    child: ...
  )
  ```
* **간격 규칙 (Spacing Grid)**: 여백(Margin/Padding) 구성 시 ad-hoc 수치 입력을 금하고, **8 / 12 / 16 / 24px 배수** 기반의 패딩을 적용하여 시각적 일관성을 확보합니다.
  - 아이콘 간격: `8px`
  - 리스트 아이템 내부 패딩: `12px` or `16px`
  - 화면 전체 가로 마진: `16px` or `24px`

### D. 대댓글(답글) 디자인 스펙
* **들여쓰기(Indent) 폭**: 자식 댓글(대댓글)의 경우 깊이(depth)에 따라 가로 여백을 동적으로 세팅합니다. 단, 모바일 화면 폭을 고려하여 최대 들여쓰기는 `depth * 16.0`을 한계값으로 둡니다.
* **연결 인디케이터**: 대댓글 좌측 여백에는 단순 들여쓰기뿐만 아니라, `Row` 내부에 작은 꺾임 화살표(`Icons.subdirectory_arrow_right_rounded`, size: 14, color: Colors.grey)를 부드럽게 노출하여 계층 관계가 직관적으로 노출되도록 설계합니다.

---

## 5. GitHub 협업 전략 및 커밋 컨벤션 (GitHub Strategy)

### A. 브랜치 전략 (Branching Strategy - GitHub Flow 변형)
* **`main`**: 운영 서버에 무중단 배포되는 최상위 브랜치입니다. 항상 컴파일이 통과되고 즉시 상용 서빙이 가능한 검증된 코드가 유지되어야 합니다.
* **`develop`**: 기능 개발을 병합(Merge)하고 통합 테스트(CI/CD)를 돌리는 메인 개발 브랜치입니다.
* **`feature/[기능명]` (or `feat/[기능명]`)**: 개별 기능 단위로 개발을 진행하는 임시 브랜치입니다. 완료 시 `develop` 브랜치로 PR을 날리고 병합 후 삭제합니다.
* **`hotfix/[버그명]`**: 상용 서버 장애 발생 시 즉각 대응하는 긴급 수정용 임시 브랜치입니다.
* **배포 흐름**: 기능 브랜치 → `develop` PR에서 CI를 통과한 뒤 병합하고, 릴리스 시 `develop` → `main` PR을 병합합니다. `main` push가 운영 배포를 시작하며 GitHub `production` Environment 승인 뒤 Oracle VM과 Firebase Hosting에 반영됩니다.

### B. 커밋 메시지 규칙 (Commit Message Conventions)
커밋 메시지는 **Conventional Commits** 사양을 따르며 한글로 작성합니다.
`type: Subject (제목)` 및 상세 설명 구조를 사용하며, 분류는 다음과 같습니다.
* **`feat`**: 새로운 기능 개발 및 추가
* **`fix`**: 버그/오류 수정
* **`refactor`**: 로직 변경 없는 코드 구조 변경/최적화
* **`docs`**: 문서 신규 작성 및 수정
* **`style`**: 코드 스타일링, 포맷팅, 세미콜론 수정
* **`chore`**: 빌드 설정, 의존성 라이브러리 추가/수정

### C. 머지 및 협업 약속 (Merge & Rebase Rules)
* **머지 전 자가 빌드 검증**: `develop` 브랜치로 PR을 올리기 전에 반드시 백엔드 `./gradlew test bootJar` 및 프론트엔드 `flutter analyze`, `flutter test`, `flutter build web --release`가 로컬에서 성공적으로 통과되는지 확인합니다.
* **머지 전 싱크업 (Sync-up)**: 본인의 브랜치를 머지하기 전, `git pull origin develop`를 먼저 수행하여 원격 최신 변경사항을 미리 충돌 해결 및 병합한 후에 완료해야 히스토리가 깨지지 않습니다.
* **커밋 쪼개기**: 백엔드, 프론트엔드, 문서를 한 번에 섞어서 거대 커밋으로 올리는 것을 금지합니다. 피처 단계별로 빌드 확인 후 개별적인 분리 커밋을 준수합니다.
