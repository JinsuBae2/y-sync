# Y-Sync Infrastructure & Deployment Specifications

Y-Sync 플랫폼의 프로덕션 배포 파이프라인(Oracle Cloud 인프라 구조, Docker-compose, Nginx Reverse Proxy 설정, SSL 자동 갱신 및 Firebase Hosting 배포)에 대한 세부 명세서입니다.

---

## 1. 서버 인프라 토폴로지 (Docker Compose 아키텍처)

Y-Sync 백엔드는 리눅스 VM(Oracle Cloud 1GB RAM 프리티어 환경 맞춤) 상에서 **Docker Compose**를 통해 4개의 컨테이너가 마이크로서비스 형태로 협력 동작합니다.

```
                  [외부 인터넷 클라이언트]
                             │
                      80/443 (HTTP/S)
                             ▼
                    ┌─────────────────┐
                    │   ysync-nginx   │ ◄───► [ysync-certbot] (SSL 갱신)
                    └────────┬────────┘
                             │
                       Docker Bridge
                             ▼
                    ┌─────────────────┐
                    │  ysync-backend  │
                    └────────┬────────┘
                             │
                       Docker Bridge
                             ▼
                    ┌─────────────────┐
                    │   ysync-mysql   │ (RAM 350M 제한)
                    └─────────────────┘
```

* **리소스 절약 기법**: 1GB 저사양 RAM VM 환경에서 커널 OOM(Out of Memory)으로 서버가 종료되는 현상을 막기 위해, MySQL의 성능 스키마(`performance_schema=OFF`)를 끄고 버퍼 풀을 64MB로 제한하여, 컨테이너별 메모리 한계(MySQL: 350M, Backend: 450M)를 엄격히 한정시켰습니다.

---

## 2. Nginx Reverse Proxy & SSL 세부 설정

전방 프록시 Nginx(`docker/nginx/default.conf`) 설정 명세입니다.
- **도메인 호스트**: `168-107-29-144.sslip.io`
- **HTTP (80) 서버**:
  - `/.well-known/acme-challenge/`: Certbot의 SSL 인증용 경로로 `/var/www/certbot` 볼륨 마운트 서빙.
  - 이외의 모든 일반 요청은 `301 Redirect`를 통해 HTTPS(443)로 강제 리다이렉트 처리.
- **HTTPS (443) SSL 서버**:
  - LetsEncrypt에서 발급된 fullchain/privkey pem 파일을 로드하여 SSL 통신 제공.
  - `client_max_body_size 50M`: 미디어 파일 업로드 제한 완화.
  - `proxy_pass http://ysync-backend:8080`: 도커 브릿지 네트워크를 통해 Spring Boot 내부 서버로 데이터 패스.

---

## 3. LetsEncrypt SSL 인증서 자동 갱신 프로세스

- **동작 원리**: `ysync-certbot` 컨테이너가 12시간 주기(`sleep 12h`)로 백그라운드 루프를 돌며 `certbot renew` 명령을 호출합니다.
- **볼륨 공유**: Nginx와 Certbot 컨테이너 간에 인증서 챌린지 경로 `/var/www/certbot` 및 키 스토리지 `/etc/letsencrypt`를 볼륨 바인딩하여 무중단 갱신을 수행합니다.

---

## 4. 프론트엔드 배포 가이드 (Firebase Hosting)

프론트엔드 정적 파일들은 구글 **Firebase Hosting** 상에 배포되어 있으며, 빌드 및 배포 순서는 다음과 같습니다.

### 1) 빌드 (Build)
반드시 프론트엔드 디렉토리(`y-sync/frontend/`)로 이동하여 릴리즈 빌드를 실행합니다.
```powershell
flutter build web --release
```
*(결과물은 `build/web` 폴더 내에 생성됩니다.)*

### 2) 배포 (Deploy)
윈도우 파워쉘 환경 스크립트 실행 보안 정책을 우회하기 위해 `.cmd` 경로를 지정해 배포를 완료합니다.
```powershell
firebase.cmd deploy --only hosting
```
* **배포 호스팅 실주소**: [https://y-sync-31c03.web.app](https://y-sync-31c03.web.app)
* **URL 라우팅 리디렉션**: `firebase.json` 설정 파일 내의 `"rewrites"` 지침에 따라 Flutter의 모든 가상 Path 라우팅 요청이 `/index.html`로 향하도록 포워딩 처리가 잡혀 있습니다.
