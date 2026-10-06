package com.ync.ysync.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;

public class DemoReadOnlyFilter extends OncePerRequestFilter {
    private final boolean enabled;

    public DemoReadOnlyFilter(boolean enabled) { this.enabled = enabled; }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        if (DemoAccessPolicy.isDemo(SecurityContextHolder.getContext().getAuthentication())
                && (!enabled || !DemoAccessPolicy.isAllowed(request.getMethod(), request.getRequestURI().substring(request.getContextPath().length())))) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write("{\"code\":\"DEMO_READ_ONLY\",\"message\":\"데모 계정에서는 변경할 수 없습니다.\"}");
            return;
        }
        chain.doFilter(request, response);
    }
}
