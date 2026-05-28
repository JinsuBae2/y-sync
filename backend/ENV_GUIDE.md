# Y-Sync 로컬 개발 환경변수 설정 가이드 (Spring Boot)

보안 강화를 위해 데이터베이스 접속 비밀번호 및 JWT Secret Key 등의 중요한 설정을 소스코드에서 분리하고 환경변수로 주입받도록 수정되었습니다. 환경변수가 지정되지 않은 경우 기본값(Fallback)으로 동작하지만, 보안 강화를 위해 로컬 개발 환경에서도 환경변수 사용을 권장합니다.

---

## 1. 사용되는 환경변수 목록

| 환경변수명 | 설명 | 기본값 (Fallback) |
|---|---|---|
| `DB_URL` | MySQL 접속 URL | `jdbc:mysql://127.0.0.1:3306/ysync_db?...` |
| `DB_USERNAME` | 데이터베이스 계정명 | `root` |
| `DB_PASSWORD` | 데이터베이스 패스워드 | `1234` |
| `JWT_SECRET` | JWT 서명용 비밀키 | `YSyncSuperSecretKeyYSyncSuperSecretKey...` |

---

## 2. 개발 도구(IDE)별 설정 방법

### A. IntelliJ IDEA
1. 상단 메뉴의 **Run/Debug Configurations** (실행 구성 설정) 드롭다운을 클릭하고 **Edit Configurations...**를 선택합니다.
2. 실행할 Spring Boot Application (예: `YSyncApplication`) 구성을 선택합니다.
3. **Environment variables** (환경 변수) 필드를 찾습니다.
4. 우측의 폴더/수정 아이콘을 누르거나 직접 값을 입력합니다. (형식: `KEY=VALUE;KEY2=VALUE2`)
   * 예: `DB_PASSWORD=your_db_password;JWT_SECRET=your_custom_jwt_secret_key`
5. **Apply** 및 **OK**를 눌러 저장 후 실행합니다.

### B. STS (Spring Tool Suite) / Eclipse
1. 상단 메뉴의 **Run** -> **Run Configurations...**로 이동합니다.
2. 좌측 메뉴에서 **Spring Boot App** 하위의 구동 설정을 선택합니다.
3. 우측 탭 중 **Environment** 탭을 클릭합니다.
4. **Add...** 버튼을 눌러 변수명과 값을 입력합니다.
   * Name: `DB_PASSWORD`, Value: `your_db_password`
   * Name: `JWT_SECRET`, Value: `your_custom_jwt_secret_key`
5. **Apply**를 누른 후 구동합니다.

---

## 3. 터미널(CLI) 구동 시 설정 방법

### Windows (PowerShell)
터미널에서 아래 명령어로 환경변수를 선언한 후 빌드 및 실행합니다.
```powershell
$env:DB_PASSWORD="your_db_password"
$env:JWT_SECRET="your_custom_jwt_secret_key"
./gradlew bootRun
```

### Windows (CMD)
```cmd
set DB_PASSWORD=your_db_password
set JWT_SECRET=your_custom_jwt_secret_key
gradlew bootRun
```

### macOS / Linux (Bash/Zsh)
```bash
export DB_PASSWORD="your_db_password"
export JWT_SECRET="your_custom_jwt_secret_key"
./gradlew bootRun
```
