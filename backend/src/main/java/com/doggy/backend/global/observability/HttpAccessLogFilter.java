package com.doggy.backend.global.observability;

import com.doggy.backend.global.security.UserPrincipal;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Slf4j
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class HttpAccessLogFilter extends OncePerRequestFilter {

    @Value("${app.access-log.success-enabled:false}")
    private boolean successLogEnabled;

    @Value("${app.access-log.slow-threshold-ms:500}")
    private long slowThresholdMs;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return request.getRequestURI().equals("/actuator/health");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        long startedAt = System.nanoTime();
        try {
            filterChain.doFilter(request, response);
        } finally {
            long durationMs = (System.nanoTime() - startedAt) / 1_000_000;
            int status = response.getStatus();
            String userId = currentUserId();
            String message = "http_request method={} path={} status={} durationMs={} userId={} clientIp={}";
            Object[] args = {
                    request.getMethod(),
                    request.getRequestURI(),
                    status,
                    durationMs,
                    userId,
                    clientIp(request)
            };
            if (status >= 500) {
                log.error(message, args);
            } else if (status >= 400) {
                log.warn(message, args);
            } else if (successLogEnabled || durationMs >= slowThresholdMs) {
                log.info(message, args);
            }
        }
    }

    private String currentUserId() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof UserPrincipal principal)) {
            return "anonymous";
        }
        return String.valueOf(principal.getId());
    }

    private String clientIp(HttpServletRequest request) {
        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (forwardedFor != null && !forwardedFor.isBlank()) {
            return cleanIp(forwardedFor.split(",")[0]);
        }
        String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isBlank()) {
            return cleanIp(realIp);
        }
        return cleanIp(request.getRemoteAddr());
    }

    private String cleanIp(String value) {
        if (value == null || value.isBlank()) {
            return "unknown";
        }
        String clean = value.trim();
        return clean.length() <= 128 ? clean : clean.substring(0, 128);
    }
}
