package com.ync.ysync.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

// 💡 외부 디렉토리(로컬 폴더)에 저장된 파일들을 클라이언트가 URL로 접근할 수 있게 설정하는 클래스입니다.
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // 클라이언트가 /uploads/** 패턴으로 요청하면, 
        // 실제 물리적인 경로인 C:/uploads/y-sync/ 에서 파일을 찾아 응답합니다.
        registry.addResourceHandler("/uploads/**")
                .addResourceLocations("file:///C:/uploads/y-sync/");
    }
}
