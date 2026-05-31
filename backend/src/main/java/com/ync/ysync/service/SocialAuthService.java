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

    private String getGoogleSocialId(String idToken) {
        // 구글의 경우 프론트에서 idToken을 전달받아 tokeninfo 엔드포인트를 호출합니다.
        String reqUrl = "https://oauth2.googleapis.com/tokeninfo?id_token=" + idToken;
        log.info("구글 토큰 검증 시작 - 토큰 앞 20자: {}", idToken.length() > 20 ? idToken.substring(0, 20) + "..." : idToken);
        try {
            ResponseEntity<String> response = restTemplate.exchange(reqUrl, HttpMethod.GET, null, String.class);
            log.info("구글 토큰 검증 응답 상태코드: {}", response.getStatusCode());

            JsonNode root = objectMapper.readTree(response.getBody());
            String sub = root.path("sub").asText();
            log.info("구글 토큰 검증 성공 - SocialID(sub): {}", sub);
            // 구글의 고유 식별자는 "sub" 필드에 있습니다.
            return sub;
        } catch (Exception e) {
            log.error("구글 토큰 검증 실패 - 요청 URL: {}", reqUrl.substring(0, Math.min(reqUrl.length(), 80)) + "...", e);
            throw new IllegalArgumentException("유효하지 않은 구글 토큰입니다.");
        }
    }
}
