package com.ync.ysync.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ync.ysync.domain.AuthProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Slf4j
@Service
@RequiredArgsConstructor
public class SocialAuthService {

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 프론트엔드에서 전달받은 액세스 토큰을 이용해 소셜 플랫폼(카카오/구글)에서 사용자 식별자(socialId)를 가져옵니다.
     */
    public String getSocialId(String accessToken, AuthProvider provider) {
        if (provider == AuthProvider.KAKAO) {
            return getKakaoSocialId(accessToken);
        } else if (provider == AuthProvider.GOOGLE) {
            return getGoogleSocialId(accessToken);
        }
        throw new IllegalArgumentException("지원하지 않는 소셜 로그인 제공자입니다.");
    }

    private String getKakaoSocialId(String accessToken) {
        String reqUrl = "https://kapi.kakao.com/v2/user/me";
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.add("Authorization", "Bearer " + accessToken);
            headers.add("Content-type", "application/x-www-form-urlencoded;charset=utf-8");

            HttpEntity<String> entity = new HttpEntity<>(headers);
            ResponseEntity<String> response = restTemplate.exchange(reqUrl, HttpMethod.GET, entity, String.class);

            JsonNode root = objectMapper.readTree(response.getBody());
            return root.path("id").asText();
        } catch (Exception e) {
            log.error("카카오 토큰 검증 실패", e);
            throw new IllegalArgumentException("유효하지 않은 카카오 토큰입니다.");
        }
    }

    private String getGoogleSocialId(String token) {
        // 💡 [구글 로그인 리팩토링]
        // 웹 브라우저 환경 등에서 idToken이 누락되고 accessToken만 들어올 수 있으므로, 두 가지 방식을 유연하게 처리합니다.
        log.info("구글 토큰 검증 시작 - 토큰 앞 20자: {}", token.length() > 20 ? token.substring(0, 20) + "..." : token);

        // 1. JWT 형식(점 '.'이 포함됨)인 경우 ID Token으로 간주하여 tokeninfo API를 호출합니다.
        if (token.contains(".")) {
            String reqUrl = "https://oauth2.googleapis.com/tokeninfo?id_token=" + token;
            try {
                ResponseEntity<String> response = restTemplate.exchange(reqUrl, HttpMethod.GET, null, String.class);
                JsonNode root = objectMapper.readTree(response.getBody());
                String sub = root.path("sub").asText();
                if (sub != null && !sub.isEmpty()) {
                    log.info("구글 ID 토큰 검증 성공 - SocialID(sub): {}", sub);
                    return sub;
                }
            } catch (Exception e) {
                log.warn("구글 ID 토큰 검증 실패, 액세스 토큰 방식으로 재시도합니다. 에러: {}", e.getMessage());
            }
        }

        // 2. JWT 형식이 아니거나 ID Token 검증이 실패한 경우, Access Token으로 간주하여 Userinfo API를 호출합니다.
        try {
            String reqUrl = "https://www.googleapis.com/oauth2/v3/userinfo";
            HttpHeaders headers = new HttpHeaders();
            headers.add("Authorization", "Bearer " + token);
            HttpEntity<String> entity = new HttpEntity<>(headers);

            ResponseEntity<String> response = restTemplate.exchange(reqUrl, HttpMethod.GET, entity, String.class);
            JsonNode root = objectMapper.readTree(response.getBody());
            String sub = root.path("sub").asText();
            if (sub != null && !sub.isEmpty()) {
                log.info("구글 액세스 토큰 검증 성공 - SocialID(sub): {}", sub);
                return sub;
            }
        } catch (Exception e) {
            log.error("구글 액세스 토큰 검증 최종 실패", e);
        }

        throw new IllegalArgumentException("유효하지 않은 구글 토큰입니다.");
    }
}
