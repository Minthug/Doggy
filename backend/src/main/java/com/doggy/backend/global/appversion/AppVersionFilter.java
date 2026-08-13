package com.doggy.backend.global.appversion;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Map;

@Component
@RequiredArgsConstructor
public class AppVersionFilter extends OncePerRequestFilter {

    private final AppVersionService appVersionService;
    private final ObjectMapper objectMapper;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        if (!shouldCheck(request) || !appVersionService.isCheckEnabled()) {
            filterChain.doFilter(request, response);
            return;
        }

        String platform = request.getHeader(AppVersionService.APP_PLATFORM_HEADER);
        String version = request.getHeader(AppVersionService.APP_VERSION_HEADER);
        if (!appVersionService.shouldBlock(platform, version)) {
            filterChain.doFilter(request, response);
            return;
        }

        AppVersionResponse versionResponse = appVersionService.check(platform, version);
        response.setStatus(HttpStatus.UPGRADE_REQUIRED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE + ";charset=UTF-8");
        response.getWriter().write(objectMapper.writeValueAsString(Map.of(
                "message", versionResponse.message(),
                "minimumVersion", versionResponse.minimumVersion(),
                "latestVersion", versionResponse.latestVersion(),
                "storeUrl", versionResponse.storeUrl()
        )));
    }

    private boolean shouldCheck(HttpServletRequest request) {
        String path = request.getRequestURI();
        return path.startsWith("/api/")
                && !path.equals("/api/app/version")
                && !path.startsWith("/api/internal")
                && !path.startsWith("/api/admin");
    }
}
