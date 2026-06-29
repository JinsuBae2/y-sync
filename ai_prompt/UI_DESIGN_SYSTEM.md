# Y-Sync UI/UX Design System Guidelines

Y-Sync 프론트엔드(Flutter Web & Mobile) 개발 시 일관성 있고 고품질의 Rich Aesthetics 시각 경험을 유지하기 위한 디자인 가이드라인입니다. AI와 인간 개발자는 신규 화면 및 컴포넌트 구성 시 본 규격을 엄격하게 준수합니다.

---

## 1. 컬러 팔레트 (Color Palette)

Y-Sync는 영남이공대학교 고유의 브랜드 감각을 바탕으로 신뢰감 있고 모던한 색조 조합을 적용합니다.

| 색상 구분 | Hex Code | Flutter 표현 | 주로 사용되는 위치 |
|---|---|---|---|
| **Primary (Portal Blue)** | `#164687` | `Color(0xFF164687)` | 앱바 배경, 활성화 탭, 메인 액션 버튼, 강조 링크 |
| **Secondary (Amber)** | `#FFBF00` | `Color(0xFFFFBF00)` | 알림 뱃지, 중요 포인트 아이콘, 서브 강조 요소 |
| **Danger (Alert Red)** | `#E53935` | `Colors.redAccent` | 삭제/신고/블라인드/차단 관련 경고 버튼 및 칩 |
| **Success (Green)** | `#43A047` | `Colors.green.shade600` | 인증 성공, 복구 완료 스낵바, 정상 상태 칩 |
| **Background (Light)** | `#F9F9F9` | `Colors.grey.shade50` | 기본 스크롤 스크린 배경색 |
| **Card / Dialog Surface**| `#FFFFFF` | `Colors.white` | 개별 콘텐츠 리스트 카드 타일, 팝업 바디 |

---

## 2. 타이포그래피 (Typography)

* **글꼴**: 모바일 및 웹 크로스 플랫폼 렌더링 시 브라우저 기본 서체를 지양하고 `Outfit` 또는 `Inter` 글꼴군을 적용하여 고급스럽고 명확한 가독성을 제공합니다.
* **글자 크기 스케일 (Typography Scale)**:
  - **Header 1 (대제목)**: `fontSize: 18`, `fontWeight: FontWeight.w800` (앱바 타이틀 등)
  - **Header 2 (게시글 제목)**: `fontSize: 15~16`, `fontWeight: FontWeight.bold`, `color: Colors.black87`
  - **Body (본문/내용)**: `fontSize: 13~14`, `fontWeight: FontWeight.normal`, `color: Colors.black54`
  - **Caption (메타데이터)**: `fontSize: 11`, `fontWeight: FontWeight.normal`, `color: Colors.black38` (작성 시간, 카테고리 태그 등)

---

## 3. 컴포넌트 디자인 규칙 (Component Standards)

### A. 카드 레이아웃 (Card & Tiles)
- **그림자 최소화 및 테두리 정밀화 (Sleek Flat Style)**: 
  * `elevation` 값은 기본적으로 `0`을 적용합니다.
  * 그림자 오버헤드를 줄이기 위해, 모서리가 둥근 테두리 선을 두르는 방식을 우선합니다.
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

### B. 간격 규칙 (Spacing Grid)
- 여백(Margin/Padding) 구성 시 ad-hoc 수치 입력을 금하고, **8 / 12 / 16 / 24px 배수** 기반의 패딩을 적용하여 시각적 질서를 확립합니다.
  * 아이콘 간격: `8px`
  * 리스트 아이템 내부 패딩: `12px` or `16px`
  * 화면 전체 가로 마진: `16px` or `24px`

---

## 4. 대댓글(답글) 디자인 스펙

- **들여쓰기(Indent) 폭**: 자식 댓글(대댓글)의 경우 깊이(depth)에 따라 가로 여백을 동적으로 세팅합니다. 단, 모바일 화면 폭을 고려하여 최대 들여쓰기는 `depth * 16.0`을 한계값으로 둡니다.
- **연결 인디케이터**: 대댓글 좌측 여백에는 단순 들여쓰기뿐만 아니라, `Row` 내부에 작은 꺾임 화살표(`Icons.subdirectory_arrow_right_rounded`, size: 14, color: Colors.grey)를 부드럽게 노출하여 계층 관계가 눈에 확 띄도록 설계해야 합니다.
