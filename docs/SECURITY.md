# Y-Sync 보안 운영 기준

## 회원 권한 관리

- 일반 `ADMIN`은 단건 등록, CSV 등록, 회원 수정 API를 통해 `SUPER_ADMIN`을 생성하거나 부여할 수 없습니다.
- 일반 `ADMIN`은 기존 `SUPER_ADMIN` 계정을 수정할 수 없습니다.
- 권한 경계는 컨트롤러뿐 아니라 `MemberService`에서도 검증합니다.
- 회원 역할이 변경되면 `authVersion`이 증가하며, 변경 전에 발급된 JWT는 다음 요청부터 `401 Unauthorized`로 거부됩니다.
- 인증 권한은 JWT의 역할 claim을 신뢰하지 않고 데이터베이스의 현재 회원 역할로 구성합니다.

## 회원 정보 응답

관리자 회원 관리 API는 `Member` 엔티티를 직접 반환하지 않고 전용 DTO를 사용합니다. 응답에는 화면에 필요한 식별자, 이름, 역할, 알림 설정 및 계정 상태만 포함합니다.

다음 값은 회원 관리 응답에서 제외합니다.

- 비밀번호 해시
- FCM 토큰
- 소셜 로그인 식별자
- 인증 버전

`Member.password`에는 엔티티가 실수로 직렬화되는 경우를 대비해 별도의 JSON 직렬화 차단도 적용합니다.

## 비밀값과 JWT

- `JWT_SECRET`에는 소스 코드 기본값이 없습니다. 값이 없으면 애플리케이션은 기동에 실패합니다.
- 테스트는 `backend/src/test/resources/application.properties`의 테스트 전용 키를 사용합니다.
- 운영 비밀값은 GitHub Environment Secrets 또는 운영 서버의 안전한 비밀 저장소에서 관리하며 문서, 로그, 이슈와 PR에 원문을 남기지 않습니다.
- JWT 키를 교체하면 기존 토큰은 서명 검증에 실패하므로 전체 사용자 재로그인이 필요합니다.

## 공급망 및 CI

- GitHub Actions의 외부 action은 전체 commit SHA로 고정합니다. 버전 주석은 업데이트 판단을 위한 정보일 뿐 실행 기준은 SHA입니다.
- Gradle wrapper 배포본은 `distributionSha256Sum`으로 검증합니다.
- Dependabot은 Gradle, Dart/Pub, GitHub Actions와 백엔드 Docker 기반 이미지를 매주 확인합니다.
- workflow, Docker, Compose와 Gradle wrapper 변경은 `.github/CODEOWNERS`의 검토 대상입니다.

GitHub Dependency Review는 저장소의 Dependency Graph가 활성화되지 않아 CI에서 지원되지 않았습니다. 기존 빌드를 실패시키지 않도록 해당 job은 제외하고 Dependabot 기반 정기 점검을 사용합니다.

## 컨테이너 실행

- 백엔드 Java 프로세스는 `ysync` 비root 사용자로 실행합니다.
- 이미지 빌드 시 `APP_UID`와 `APP_GID`를 지정할 수 있으며 기본값은 `1000:1000`입니다.
- 운영 배포 워크플로는 원격 배포 사용자의 UID/GID를 자동으로 빌드 인자에 전달합니다.
- `/app/uploads`와 `/app/config`는 `ysync` 소유로 생성합니다. `./uploads` 바인드 마운트는 배포 사용자가 먼저 생성해 호스트와 컨테이너의 쓰기 권한을 맞춥니다.

## 보안 변경 검증

```bash
cd backend
./gradlew test

cd ../frontend
flutter test
flutter analyze --no-fatal-warnings --no-fatal-infos

cd ..
DB_PASSWORD=test-password \
JWT_SECRET=test-secret \
MAIL_USERNAME=test@example.com \
MAIL_PASSWORD=test-password \
docker compose -f docker/docker-compose.yml config --quiet
```

`JWT_SECRET` 누락 시 기동 실패는 다음 명령으로 확인합니다. 이 명령의 실패 종료 코드는 정상적인 보안 검증 결과입니다.

```bash
cd backend
env -u JWT_SECRET ./gradlew bootRun --no-daemon
```
