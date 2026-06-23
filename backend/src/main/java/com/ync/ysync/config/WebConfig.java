package com.ync.ysync.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

// 💡 외부 디렉토리(로컬 폴더)에 저장된 파일들을 클라이언트가 URL로 접근할 수 있게 설정하는 클래스입니다.
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Value("${ysync.upload.resource-location}")
    private String uploadResourceLocation;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // 클라이언트가 /uploads/** 패턴으로 요청하면, 
        // 주입받은 물리적 스토리지 리소스를 맵핑하여 파일을 찾아 응답합니다.
        registry.addResourceHandler("/uploads/**")
                .addResourceLocations(uploadResourceLocation);
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        // 💡 [CORS 설정 보완] 글로벌 MVC CORS 매핑 추가
        registry.addMapping("/**")
                .allowedOrigins(
                        "https://y-sync-31c03.web.app",
                        "https://y-sync-31c03.firebaseapp.com",
                        "https://y-sync.netlify.app",
                        "http://localhost:3000",
                        "http://localhost:8080",
                        "http://localhost:5000",
                        "http://127.0.0.1:3000",
                        "http://127.0.0.1:8080",
                        "http://127.0.0.1:5000"
                )
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true)
                .maxAge(3600);
    }
}
