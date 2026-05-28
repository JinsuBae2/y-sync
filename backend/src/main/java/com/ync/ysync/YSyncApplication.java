package com.ync.ysync;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@org.springframework.scheduling.annotation.EnableAsync // 💡 비동기 처리를 활성화합니다.
@EnableJpaAuditing
@SpringBootApplication
public class YSyncApplication {

    public static void main(String[] args) {
        SpringApplication.run(YSyncApplication.class, args);
    }
}
