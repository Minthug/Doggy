package com.doggy.backend.global.appversion;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.ServletException;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.io.IOException;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.assertj.core.api.Assertions.assertThat;

class AppVersionFilterTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void blocksApiRequestWhenAppVersionIsBelowMinimum() throws ServletException, IOException {
        AppVersionFilter filter = new AppVersionFilter(service(true, true), objectMapper);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/users/me");
        request.addHeader(AppVersionService.APP_PLATFORM_HEADER, "android");
        request.addHeader(AppVersionService.APP_VERSION_HEADER, "1.0.0");
        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicBoolean continued = new AtomicBoolean(false);

        filter.doFilter(request, response, (servletRequest, servletResponse) -> continued.set(true));

        assertThat(continued).isFalse();
        assertThat(response.getStatus()).isEqualTo(426);
        assertThat(response.getContentAsString()).contains("앱 업데이트가 필요합니다");
    }

    @Test
    void allowsVersionCheckEndpointWithoutHeaders() throws ServletException, IOException {
        AppVersionFilter filter = new AppVersionFilter(service(true, true), objectMapper);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/app/version");
        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicBoolean continued = new AtomicBoolean(false);

        filter.doFilter(request, response, (servletRequest, servletResponse) -> continued.set(true));

        assertThat(continued).isTrue();
        assertThat(response.getStatus()).isEqualTo(200);
    }

    @Test
    void allowsApiRequestWhenEnforcementIsDisabled() throws ServletException, IOException {
        AppVersionFilter filter = new AppVersionFilter(service(true, false), objectMapper);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/users/me");
        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicBoolean continued = new AtomicBoolean(false);

        filter.doFilter(request, response, (servletRequest, servletResponse) -> continued.set(true));

        assertThat(continued).isTrue();
    }

    private AppVersionService service(boolean checkEnabled, boolean enforceMinimum) {
        AppVersionProperties.PlatformVersion android =
                new AppVersionProperties.PlatformVersion("1.1.0", "1.2.0", "");
        AppVersionProperties.PlatformVersion ios =
                new AppVersionProperties.PlatformVersion("1.1.0", "1.2.0", "");
        return new AppVersionService(new AppVersionProperties(checkEnabled, enforceMinimum, android, ios));
    }
}
