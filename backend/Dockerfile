# 💡 실행 스테이지 (초경량 Alpine JRE 사용 - GitHub Actions 러너가 빌드한 JAR을 복사하여 실행만 수행)
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# GitHub Actions 빌드로 생성되어 복사해 올 JAR 파일 매핑
COPY build/libs/*.jar app.jar

# 타임존 서울 설정
RUN apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/Asia/Seoul /etc/localtime && \
    echo "Asia/Seoul" > /etc/timezone

# 💡 1GB 램 서버 환경에 최적화된 JVM 메모리 튜닝
ENTRYPOINT ["java", "-XX:+UseSerialGC", "-Xms192m", "-Xmx192m", "-XX:MaxMetaspaceSize=160m", "-jar", "app.jar"]
