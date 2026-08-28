# Y-Sync macOS 개발 및 운영 가이드

이 문서는 Y-Sync를 macOS에서 개발하고 GitHub Actions를 통해 운영 배포할 때 필요한 도구, 자격 증명, 검증 절차를 정리합니다. 운영 비밀값은 저장소에 넣지 않으며 로컬, GitHub, Oracle VM의 책임 범위를 분리합니다.

---

## 1. 현재 운영 구조

```text
사용자 브라우저
  ├─ Web App ──> Firebase Hosting (https://y-sync-31c03.web.app)
  └─ REST API ─> Nginx/HTTPS ─> Spring Boot ─> MySQL
                              Oracle Cloud VM
```

### 백엔드
- Java 21, Spring Boot 4.0.3, Gradle Wrapper, Spring Data JPA, MySQL 8.0을 사용합니다.
- Oracle Cloud VM에서 `ysync-nginx`, `ysync-certbot`, `ysync-backend`, `ysync-mysql` 컨테이너가 Docker Compose로 실행됩니다.
- 운영 API 주소는 `https://168-107-29-144.sslip.io`입니다.

### 프론트엔드
- Flutter Web, Riverpod 3.x, Dio를 사용합니다.
- 빌드 결과는 Firebase Hosting의 `https://y-sync-31c03.web.app`에 배포됩니다.

### CI/CD
- 기능 브랜치에서 `develop`으로 보내는 PR은 `.github/workflows/ci.yml`의 백엔드 테스트/JAR 빌드, Flutter 분석/테스트/Web 빌드, Docker Compose 설정 검사를 통과해야 합니다.
- `develop`에서 `main`으로 보내는 PR을 병합하면 `.github/workflows/deploy-production.yml`이 변경 영역을 판별합니다.
- GitHub `production` Environment 승인 후 백엔드는 SSH로 Oracle VM에, 프론트엔드는 Firebase Hosting에 자동 배포됩니다.
- 로컬 Firebase CLI 배포와 서버 내 직접 재배포는 자동화가 실패한 비상 상황에서만 사용합니다.

---

## 2. 자격 증명과 키 관리

### 로컬 Mac에 필요한 항목

| 항목 | 권장 위치/저장소 | 용도 |
|---|---|---|
| Oracle Cloud SSH 개인키 | `~/.ssh/y-sync-oci.key` | 운영 서버 점검 및 비상 대응 |
| GitHub 인증 | macOS Keychain 또는 `gh auth login` | clone, push, PR 관리 |
| SUPER_ADMIN 비밀번호 | macOS Keychain 서비스 `y-sync-production-super-admin`, 계정 `2305009` | 운영 점검용 로그인 |
| Firebase CLI 로그인 | Firebase CLI 자체 로그인 저장소 | 비상 수동 Hosting 배포 시에만 필요 |

SSH 개인키는 다음 권한을 유지합니다.

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
chmod 400 ~/.ssh/y-sync-oci.key
```

운영 SUPER_ADMIN 비밀번호는 평문 파일이나 셸 히스토리에 기록하지 않고 Keychain에서 조회합니다.

```bash
security find-generic-password \
  -a 2305009 \
  -s y-sync-production-super-admin \
  -w
```

### 로컬로 복사하지 않는 운영 비밀값
- `DB_PASSWORD`, `JWT_SECRET`, `MAIL_USERNAME`, `MAIL_PASSWORD`
- S3 애플리케이션 사용자용 `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- GitHub Actions의 `SERVER_IP`, `SERVER_USER`, `SSH_PRIVATE_KEY`
- Firebase Hosting 배포용 `FIREBASE_SERVICE_ACCOUNT_Y_SYNC_31C03`
- Oracle VM의 `/home/ubuntu/ysync/app/docker/firebase-adminsdk.json`

위 값은 GitHub `production` Environment Secrets 또는 Oracle VM에만 보관합니다. Firebase Admin SDK 키는 백엔드 FCM용이고 Firebase Hosting 배포 서비스 계정과 별개입니다. 로컬 FCM 통합 테스트가 꼭 필요한 경우에만 별도 개발용 서비스 계정을 발급하고, Git 무시 경로에 저장합니다.

S3 저장소 전환 시 GitHub `production` Environment Variables에는 다음 값을 등록합니다.

- `STORAGE_PROVIDER=s3`
- `AWS_S3_BUCKET=y-sync-attachments-155641294529`
- `AWS_REGION=ap-northeast-2`

신규 S3 파일은 `/s3-uploads/**` 경로에서 5분짜리 Presigned URL로 리다이렉트되고, 기존 로컬 파일은 `/uploads/**` 경로로 계속 제공됩니다. Secret 등록 전에는 `STORAGE_PROVIDER`를 `local`로 유지합니다.

---

## 3. macOS 개발 환경 구성

### Homebrew와 Java 21

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install openjdk@21
sudo ln -sfn "$(brew --prefix)/opt/openjdk@21/libexec/openjdk.jdk" \
  /Library/Java/JavaVirtualMachines/openjdk-21.jdk
java -version
```

프로젝트는 Gradle Wrapper를 사용하므로 시스템 Gradle을 별도로 설치하지 않습니다.

### Flutter

```bash
brew install --cask flutter
flutter doctor
```

### Docker와 선택 도구

```bash
# 둘 중 하나만 설치
brew install orbstack
# brew install --cask docker

# 비상 수동 Firebase 배포가 필요한 경우만 설치
brew install node
npm install -g firebase-tools
firebase login
```

### 저장소 복제

```bash
git clone https://github.com/JinsuBae2/y-sync.git
cd y-sync
git switch develop
```

---

## 4. 로컬 검증 절차

### 백엔드

```bash
cd backend
chmod +x gradlew
./gradlew test bootJar
```

Java 선택이 필요한 경우 현재 셸에 Java 21을 지정합니다.

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
```

### 프론트엔드

```bash
cd frontend
flutter pub get --enforce-lockfile
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
flutter build web --release
```

### Docker Compose 설정

운영 비밀값 대신 검사용 임시값을 현재 셸에만 지정한 뒤 설정을 렌더링합니다.

```bash
DB_PASSWORD=local-check \
JWT_SECRET=local-check-local-check-local-check-local-check \
MAIL_USERNAME=local@example.com \
MAIL_PASSWORD=local-check \
docker compose -f docker/docker-compose.yml config
```

---

## 5. 브랜치와 배포 절차

1. `develop`에서 `feature/*`, `fix/*`, `hotfix/*` 브랜치를 생성합니다.
2. 코드 변경과 관련 `docs` 문서를 논리적으로 분리해 한글 커밋으로 기록합니다.
3. 원격 브랜치에 push하고 `develop` 대상 PR을 생성해 CI를 통과시킵니다.
4. 릴리스할 때 `develop`에서 `main` 대상 PR을 생성합니다.
5. `main` 병합 후 `Production Deploy`의 빌드 결과를 확인하고 `production` 승인을 수행합니다.
6. 배포 완료 후 운영 URL과 API 상태를 읽기 전용 요청으로 확인합니다.

수동 배포는 정상 흐름이 아닙니다. 비상 대응이 필요하면 먼저 실패한 GitHub Actions 로그와 현재 서버 컨테이너 상태를 확인하고, 원인을 기록한 뒤 최소 범위만 복구합니다.

---

## 6. 운영 서버 점검

```bash
ssh -i ~/.ssh/y-sync-oci.key ubuntu@168.107.29.144
docker ps
docker compose -f ~/ysync/app/docker/docker-compose.yml ps
free -h
df -h
docker logs --tail 100 ysync-backend
```

백엔드의 8080 포트는 호스트에 공개하지 않고 Docker 네트워크 내부에서 Nginx가 접근합니다. 따라서 VM에서 `curl http://localhost:8080/...`가 실패하는 것은 현재 보안 구성에서 정상이며, HTTPS 도메인 또는 컨테이너 네트워크를 통해 상태를 확인합니다.

---

## 7. 완료 체크리스트

- [ ] `java -version`이 Java 21을 가리킨다.
- [ ] `flutter doctor`에서 Web 개발 필수 항목이 정상이다.
- [ ] 백엔드 `./gradlew test bootJar`가 통과한다.
- [ ] 프론트엔드 분석, 테스트, Web 빌드가 통과한다.
- [ ] `~/.ssh/y-sync-oci.key` 권한이 `400`이고 운영 VM 접속이 된다.
- [ ] SUPER_ADMIN 비밀번호가 평문 파일이 아닌 macOS Keychain에 있다.
- [ ] 운영 비밀값과 Firebase Admin SDK 키가 Git 추적 대상에 없다.
- [ ] 기능 PR의 CI와 `main` 병합 후 운영 배포 워크플로가 정상 완료된다.
