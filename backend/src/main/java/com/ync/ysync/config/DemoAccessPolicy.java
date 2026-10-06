package com.ync.ysync.config;

import org.springframework.security.core.Authentication;
import java.util.regex.Pattern;

public final class DemoAccessPolicy {
    private DemoAccessPolicy() {}

    private static final Pattern READ_PATH = Pattern.compile(
            "/api/v1/(?:hello|members/(?:me(?:/(?:posts|notices|comments))?|settings)"
            + "|notices(?:/(?:feed|feed-updates|search|[0-9]+(?:/comments)?))?"
            + "|community(?:/(?:search|[0-9]+(?:/comments)?))?"
            + "|calendar|timetable/(?:personal|GRADE_[1-4])|notifications|scraps)"
            + "|/(?:uploads|s3-uploads)/[^/]+");

    public static boolean isDemo(Authentication authentication) {
        return authentication != null && authentication.isAuthenticated()
                && authentication.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_DEMO"));
    }

    public static boolean isAllowed(String method, String servletPath) {
        if (method.equals("POST") && servletPath.equals("/api/v1/auth/logout")) return true;
        return (method.equals("GET") || method.equals("HEAD")) && READ_PATH.matcher(servletPath).matches();
    }
}
