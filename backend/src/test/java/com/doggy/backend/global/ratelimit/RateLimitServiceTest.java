package com.doggy.backend.global.ratelimit;

import com.doggy.backend.global.alert.AlertService;
import com.doggy.backend.global.exception.BusinessException;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RateLimitServiceTest {

    private final RateLimitService rateLimitService = new RateLimitService(AlertService.noop());

    @Test
    void loginBlocksAfterLimitForSameIpAndEmail() {
        MockHttpServletRequest request = request("203.0.113.10");

        for (int i = 0; i < 10; i++) {
            assertThatCode(() -> rateLimitService.checkLogin(request, "USER@example.com"))
                    .doesNotThrowAnyException();
        }

        assertThatThrownBy(() -> rateLimitService.checkLogin(request, "user@example.com"))
                .isInstanceOf(BusinessException.class)
                .hasMessage("요청이 너무 많습니다. 잠시 후 다시 시도해주세요");
    }

    @Test
    void loginLimitIsSeparatedByEmail() {
        MockHttpServletRequest request = request("203.0.113.20");

        for (int i = 0; i < 10; i++) {
            rateLimitService.checkLogin(request, "first@example.com");
        }

        assertThatCode(() -> rateLimitService.checkLogin(request, "second@example.com"))
                .doesNotThrowAnyException();
    }

    @Test
    void signupBlocksAfterLimitForForwardedIp() {
        MockHttpServletRequest request = request("10.0.0.1");
        request.addHeader("X-Forwarded-For", "198.51.100.5, 10.0.0.1");

        for (int i = 0; i < 5; i++) {
            rateLimitService.checkSignup(request);
        }

        assertThatThrownBy(() -> rateLimitService.checkSignup(request))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    void uploadLimitIsSeparatedByUser() {
        MockHttpServletRequest request = request("203.0.113.30");

        for (int i = 0; i < 10; i++) {
            rateLimitService.checkImageUpload(1L, request);
        }

        assertThatCode(() -> rateLimitService.checkImageUpload(2L, request))
                .doesNotThrowAnyException();
        assertThatThrownBy(() -> rateLimitService.checkImageUpload(1L, request))
                .isInstanceOf(BusinessException.class);
    }

    private MockHttpServletRequest request(String remoteAddress) {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr(remoteAddress);
        return request;
    }
}
