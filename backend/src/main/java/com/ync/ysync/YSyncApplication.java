package com.ync.ysync;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@EnableJpaAuditing
@SpringBootApplication
public class YSyncApplication {

    public static void main(String[] args) {
        SpringApplication.run(YSyncApplication.class, args);
    }
}
