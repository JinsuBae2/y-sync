# Y-Sync GitHub Branching & Commit Conventions

Y-Sync 프로젝트에서 안정적인 협업과 소스 코드 히스토리 보존을 위해 AI 어시스턴트와 개발자가 반드시 준수해야 하는 GitHub 브랜치 전략 및 커밋 컨벤션 명세입니다.

---

## 1. 브랜치 전략 (Branching Strategy - GitHub Flow 변형)

Y-Sync는 안정적인 통합과 무중단 배포를 위해 `main`, `develop`, `feature/*` 브랜치 구조를 기준으로 움직입니다.

```
  main (운영)    ───────────────────────────────────────── (최종 배포)
                   ▲
                   │ (Release/Merge)
  develop (개발) ──┴───┬───────────────────┬────────────── (개발 통합)
                       │                   ▲
                       ▼ (Branch out)      │ (PR & Merge)
  feature/*      ──────┴─── [개발 진행] ───┘
```

### 브랜치 분류 및 역할
* **`main` (or `master`)**
  - 운영 서버에 무중단 배포되는 최상위 브랜치입니다.
  - 이 브랜치는 항상 컴파일이 통과되고 즉시 상용 서빙이 가능한 검증된 코드가 유지되어야 합니다.
* **`develop`**
  - 기능 개발을 병합(Merge)하고 통합 테스트(CI/CD)를 돌리는 메인 개발 브랜치입니다.
  - 로컬 개발이 완료된 모든 기능은 이 브랜치로 Pull Request(PR)를 날려 머지됩니다.
* **`feature/[기능명]` (or `feat/[기능명]`)**
  - 개별 기능 단위(예: `feature/notification-center`, `feature/timetable-share`)로 나누어 개발을 진행하는 임시 브랜치입니다.
  - 완료 시 `develop` 브랜치로 병합 요청을 날린 뒤 삭제 처리합니다.
* **`hotfix/[버그명]`**
  - 상용 서버(`main` 브랜치)에서 즉각적인 수정이 필요한 크리티컬 크래시나 장애가 발생했을 때 긴급 대응하는 수정용 임시 브랜치입니다.

---

## 2. 커밋 메시지 규칙 (Commit Message Conventions)

커밋 메시지는 **Conventional Commits** 사양을 엄격히 따르며 한글로 직관적이게 작성합니다.

### A. 커밋 메시지 구조
```
type: Subject (제목)

- body (상세 설명 - 선택사항)
```

### B. 주요 Type 분류
| Type | 설명 | 실제 적용 예시 |
|---|---|---|
| **`feat`** | 새로운 기능 개발 및 추가 | `feat: 알림 센터 읽음 상태 처리 및 뱃지 UI 연동` |
| **`fix`** | 버그/오류 수정 | `fix: CommentController 내 AuthUtil 주입 NPE 오류 해결` |
| **`refactor`**| 로직 변경 없는 코드 구조 변경/최적화 | `refactor: Riverpod 3.0 호환을 위한 Notifier 리팩토링` |
| **`docs`** | 문서 신규 작성 및 수정 | `docs: GitHub 협업 전략 및 커밋 규칙 가이드 추가` |
| **`style`** | 코드 스타일링, 포맷팅, 세미콜론 수정 | `style: notice_detail_screen 공백 라인 정렬 수정` |
| **`chore`** | 빌드 설정, 의존성 라이브러리 추가/수정 | `chore: build.gradle 내 FCM Admin SDK 라이브러리 탑재` |

---

## 3. 머지 및 협업 약속 (Merge & Rebase Rules)

1. **머지 전 자가 빌드 검증**:
   - `develop` 브랜치로 PR을 올리거나 머지하기 전에, 반드시 백엔드 `./gradlew compileJava` 및 프론트엔드 `flutter build web --release`를 로컬에서 돌려 컴파일 성공을 사전에 강제 확인해야 합니다.
2. **머지 전 싱크업 (Sync-up)**:
   - 본인이 개발한 브랜치를 머지하기 전, `git pull origin develop`를 로컬에서 먼저 수행하여 원격 최신 변경사항을 미리 충돌(Conflict) 해결 및 병합한 후에 완료해야 히스토리가 깨지지 않습니다.
3. **커밋 쪼개기**:
   - 한 커밋에 백엔드 추가, 프론트엔드 UI 수정, 문서 작성을 모두 집어넣는 거대 커밋을 금지합니다.
   - 반드시 **"피처 1 개발 ➡️ 빌드 확인 ➡️ 커밋 ➡️ 피처 2 개발 ➡️ 빌드 확인 ➡️ 커밋"** 순의 단계별 분리 커밋을 준수합니다.
