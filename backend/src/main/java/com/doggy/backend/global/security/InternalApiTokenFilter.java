package com.doggy.backend.global.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;

@Component
public class InternalApiTokenFilter extends OncePerRequestFilter {

    public static final String INTERNAL_TOKEN_HEADER = "X-Internal-Token";

    private final ObjectMapper objectMapper;
    private final String internalToken;

    public InternalApiTokenFilter(
            ObjectMapper objectMapper,
            @Value("${app.internal-api.token:}") String internalToken
    ) {
        this.objectMapper = objectMapper;
        this.internalToken = internalToken;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        if (!requiresInternalToken(request)) {
            filterChain.doFilter(request, response);
            return;
        }

        if (isValidInternalToken(request.getHeader(INTERNAL_TOKEN_HEADER))) {
            filterChain.doFilter(request, response);
            return;
        }

        response.setStatus(HttpStatus.FORBIDDEN.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE + ";charset=UTF-8");
        response.getWriter().write(objectMapper.writeValueAsString(Map.of(
                "message", "내부 API 접근 권한이 없습니다"
        )));
    }

    private boolean requiresInternalToken(HttpServletRequest request) {
        String path = request.getRequestURI();
        if (path == null) {
            return false;
        }
        if (path.equals("/actuator/health")) {
            return false;
        }
        return path.startsWith("/actuator/")
                || path.equals("/actuator")
                || path.startsWith("/api/admin/")
                || path.equals("/api/admin")
                || path.startsWith("/api/internal/")
                || path.equals("/api/internal");
    }

    private boolean isValidInternalToken(String requestToken) {
        if (!StringUtils.hasText(internalToken) || !StringUtils.hasText(requestToken)) {
            return false;
        }
        byte[] expected = internalToken.getBytes(StandardCharsets.UTF_8);
        byte[] actual = requestToken.trim().getBytes(StandardCharsets.UTF_8);
        return MessageDigest.isEqual(expected, actual);
    }
}
