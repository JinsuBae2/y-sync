# 1차 운영 조회 부하테스트

이 부하테스트는 Oracle Cloud 1GB Free Tier 운영 서버의 **공개 조회 API 처리 성능과 안정성**을 확인하기 위한 수동 테스트입니다. 운영 데이터를 변경하는 요청은 포함하지 않습니다.

## 테스트 범위

`SecurityConfig` 기준으로 인증 없이 허용된 다음 GET만 호출합니다.

- `GET /api/v1/notices?page=0&size=20&sort=createdAt,desc` (약 65%)
- `GET /api/v1/notices/search?keyword=공지` (약 30%)
- `GET /api/v1/hello` (약 5%, 상태 확인용)

커뮤니티, 학사일정, 시간표 조회는 현재 `anyRequest().authenticated()`에 의해 인증이 필요하므로 제외했습니다. 공지 상세 조회는 조회수 변경 가능성이 있어 제외했습니다. 계정·JWT·임의 로그인은 사용하지 않습니다.

## 부하 단계와 측정값

순차적으로 다음 단계가 실행됩니다.

`5 VU/1분 → 10 VU/2분 → 20 VU/2분 → 30 VU/2분 → 50 VU/2분`

각 단계별로 로그와 Job Summary에 다음 값이 표시됩니다.

- RPS
- 평균 응답시간, p95, p99
- HTTP 실패율
- timeout/전송 오류 수

기본 threshold는 `HTTP 실패율 < 1%`, `p95 < 1000ms`입니다. threshold가 실패해도 k6 summary를 먼저 출력한 뒤 workflow를 실패 처리합니다.

## GitHub Actions에서 실행

실제 테스트는 자동 실행되지 않습니다. GitHub 저장소에서 다음 버튼을 사용합니다.

1. **Actions** 탭 → **k6 Public Read Load Test** 선택
2. **Run workflow** 클릭
3. `base_url`에 운영 API의 `https://` 주소 입력
4. **Run workflow** 재클릭
5. 실행된 Job의 로그 또는 **Summary**에서 단계별 결과 확인

운영 URL은 workflow input으로만 주입되며 저장소 코드에 하드코딩하지 않습니다. 이번 1차 테스트가 안정적이어도 75/100 VU는 별도 실행에서 판단합니다.

## 운영 서버 리소스 확인

추가 인프라(Prometheus/Grafana)는 설치하지 않습니다. 부하테스트 실행과 동시에 Oracle 서버 SSH 세션에서 다음 명령을 단계별로 기록합니다.

```bash
# 전체 CPU/RAM 및 컨테이너별 메모리/CPU
docker stats --no-stream

# 메모리(MB), swap 포함
free -m

# 짧은 CPU 프로세스 스냅샷
top -b -n 1 | head -25

# 가능하면 1초 간격 5회 샘플
vmstat 1 5
```

기록할 항목은 전체 메모리 사용량·swap, 백엔드/DB 컨테이너 CPU·메모리, load average, OOM 또는 재시작 여부입니다. 이 명령들은 읽기 전용이며 서버 설정을 변경하지 않습니다.
