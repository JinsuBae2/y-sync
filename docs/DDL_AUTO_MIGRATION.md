# `ddl-auto` 전환 절차 (update → validate)

> ## ✅ 전환 완료 — 2026-09-21
>
> 운영 백엔드는 `spring.jpa.hibernate.ddl-auto=validate`로 동작합니다. Hibernate는 더 이상 운영 스키마를 자동으로 변경하지 않습니다.
>
> 전환 전에 아래 3~4단계를 그대로 수행해 **불일치 0건**을 확인했습니다. `update`로 오래 운영됐지만 엔티티와 어긋난 컬럼·타입·인덱스가 없었습니다.
>
> **이 문서는 이제 "엔티티를 바꿀 때 영향을 미리 확인하는 절차"로 씁니다.** 3~4단계가 그 부분입니다. 엔티티를 바꾸고 운영 DDL을 적용하지 않은 채 배포하면 `validate`가 불일치를 잡아 **기동에 실패합니다.**

이 문서는 `validate`로 전환하는 절차입니다. **값만 바꾸고 배포하면 안 됩니다.**

## 왜 값만 바꾸면 안 되는가

`update`로 운영돼 온 스키마는 엔티티 정의와 미세하게 어긋나 있을 수 있습니다. 컬럼 타입, 길이, 인덱스, nullable 여부 등이 대표적입니다. `validate`는 불일치를 발견하면 **애플리케이션 기동을 실패시킵니다.** 검증 없이 전환하면 배포 즉시 운영 장애가 됩니다.

`docs/TROUBLESHOOTING.md` 4번의 `NoticeType` ENUM 장애가 이 계열의 사고입니다.

## 전환 절차

### 1. 운영 DB 백업 및 복구 확인

```bash
ssh -i ~/.ssh/y-sync-oci.key ubuntu@168.107.29.144

docker exec ysync-mysql mysqldump -u root -p ysync_db > ~/ysync_backup_$(date +%Y%m%d).sql
ls -lh ~/ysync_backup_*.sql
```

백업 파일이 비어 있지 않은지, 그리고 **복구 절차를 알고 있는지** 확인합니다. 백업만 있고 복구를 못 하면 백업이 아닙니다.

### 2. 스키마만 덤프

```bash
docker exec ysync-mysql mysqldump -u root -p --no-data --skip-comments ysync_db > ~/ysync_schema.sql
```

이 파일을 로컬로 가져옵니다.

```bash
scp -i ~/.ssh/y-sync-oci.key ubuntu@168.107.29.144:~/ysync_schema.sql .
```

### 3. 복제 환경에 스키마 적재

로컬 MySQL 컨테이너에 운영 스키마만 올립니다. 데이터는 필요 없습니다.

```bash
docker run --name ysync-schema-check -e MYSQL_ROOT_PASSWORD=check \
  -e MYSQL_DATABASE=ysync_db -p 3307:3306 -d mysql:8.0

# 컨테이너가 준비될 때까지 기다린 뒤
docker exec -i ysync-schema-check mysql -u root -pcheck ysync_db < ysync_schema.sql
```

### 4. `validate`로 기동 시도

**코드를 수정할 필요 없습니다.** Spring의 환경변수 바인딩으로 값을 덮어씁니다.

```bash
cd backend

SPRING_PROFILES_ACTIVE=prod \
SPRING_JPA_HIBERNATE_DDL_AUTO=validate \
DB_URL='jdbc:mysql://127.0.0.1:3307/ysync_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Seoul&characterEncoding=UTF-8' \
DB_USERNAME=root \
DB_PASSWORD=check \
JWT_SECRET=local-check-local-check-local-check-local-check \
MAIL_USERNAME=check@example.com \
MAIL_PASSWORD=check \
./gradlew bootRun
```

- **정상 기동하면** 스키마와 엔티티가 일치합니다. 5단계로 넘어갑니다.
- **`SchemaManagementException`으로 실패하면** 로그에 불일치 항목이 그대로 나옵니다. 6단계를 먼저 수행합니다.

### 5. 불일치가 없는 경우

`application-prod.properties`의 값을 `validate`로 바꾸고 주석을 정리한 뒤 배포합니다. 배포 후 `/api/v1/hello` 응답을 확인합니다.

**2026-09-21 전환 시에는 여기서 끝났습니다.** 4단계가 바로 통과해 6단계로 갈 일이 없었습니다.

전환 이후 엔티티를 바꿨다면, 이 단계는 "적용할 DDL을 운영에 먼저 넣고 배포한다"로 읽으십시오. 순서가 뒤집히면 배포가 기동 실패로 끝납니다.

### 6. 불일치가 있는 경우

로그에 나온 항목을 **명시적 DDL로** 해결합니다. Hibernate에게 다시 맡기지 않습니다.

```sql
-- 예시입니다. 실제 항목은 로그를 보고 판단하십시오.
ALTER TABLE notice MODIFY COLUMN notice_type VARCHAR(255) NOT NULL;
ALTER TABLE member ADD INDEX idx_member_email (email);
```

복제 환경에서 DDL을 적용해 4단계가 통과할 때까지 반복한 뒤, **같은 DDL을 운영에 적용**하고 5단계를 수행합니다.

적용한 DDL은 전부 기록해 두었다가 `docs/WORK_LOG.md`에 남깁니다.

### 7. 정리

```bash
docker rm -f ysync-schema-check
```

## 이후 과제

`validate`로 전환하면 스키마 변경 수단이 없어집니다. 엔티티를 바꿀 때마다 수동 DDL이 필요해지므로, 다음 단계로 **Flyway 또는 Liquibase 도입**을 검토합니다.

- 기존 스키마를 baseline으로 잡고 이후 변경만 마이그레이션으로 관리하는 방식이 전환 비용이 가장 낮습니다.
- 도입 전까지는 엔티티 변경 시 이 문서의 4단계로 영향을 먼저 확인합니다.

## 참고

`validate`는 **Hibernate의 자동 스키마 변경을 막는 설정**입니다. 데이터 유실 자체를 막아 주는 기능이 아니며, 잘못된 DDL이나 애플리케이션 버그로 인한 데이터 손상은 별개로 방어해야 합니다.
