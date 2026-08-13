package com.doggy.backend.global.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.ServletException;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.io.IOException;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.assertj.core.api.Assertions.assertThat;

class InternalApiTokenFilterTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void allowsPublicHealthWithoutInternalToken() throws ServletException, IOException {
        InternalApiTokenFilter filter = new InternalApiTokenFilter(objectMapper, "secret");
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/actuator/health");
        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicBoolean continued = new AtomicBoolean(false);

        filter.doFilter(request, response, (servletRequest, servletResponse) -> continued.set(true));

        assertThat(continued).isTrue();
        assertThat(response.getStatus()).isEqualTo(200);
    }

    @Test
    void blocksActuatorMetricsWithoutInternalToken() throws ServletException, IOException {
        InternalApiTokenFilter filter = new InternalApiTokenFilter(objectMapper, "secret");
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/actuator/metrics");
        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicBoolean continued = new AtomicBoolean(false);

        filter.doFilter(request, response, (servletRequest, servletResponse) -> continued.set(true));

        assertThat(continued).isFalse();
        assertThat(response.getStatus()).isEqualTo(403);
        assertThat(response.getContentAsString()).contains("내부 API 접근 권한");
    }

    @Test
    void allowsInternalPathWithMatchingToken() throws ServletException, IOException {
        InternalApiTokenFilter filter = new InternalApiTokenFilter(objectMapper, "secret");
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/internal/jobs");
        request.addHeader(InternalApiTokenFilter.INTERNAL_TOKEN_HEADER, "secret");
        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicBoolean continued = new AtomicBoolean(false);

        filter.doFilter(request, response, (servletRequest, servletResponse) -> continued.set(true));

        assertThat(continued).isTrue();
        assertThat(response.getStatus()).isEqualTo(200);
    }

    @Test
    void blocksInternalPathWhenServerTokenIsMissing() throws ServletException, IOException {
        InternalApiTokenFilter filter = new InternalApiTokenFilter(objectMapper, "");
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/admin/users");
        request.addHeader(InternalApiTokenFilter.INTERNAL_TOKEN_HEADER, "secret");
        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicBoolean continued = new AtomicBoolean(false);

        filter.doFilter(request, response, (servletRequest, servletResponse) -> continued.set(true));

        assertThat(continued).isFalse();
        assertThat(response.getStatus()).isEqualTo(403);
    }
}
