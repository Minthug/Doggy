package com.doggy.backend.global.observability;

import com.doggy.backend.global.alert.AlertService;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.exception.GlobalExceptionHandler;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

@ExtendWith(OutputCaptureExtension.class)
class WalkLocationLogPrivacyTest {

    @Test
    void locationRequestSkipsAccessLogAndHidesCoordinatesFromErrorLog(CapturedOutput output) throws Exception {
        var request = new MockHttpServletRequest("PATCH", "/api/walks/123/location");
        var response = new MockHttpServletResponse();
        new HttpAccessLogFilter().doFilter(request, response,
                (servletRequest, servletResponse) -> response.setStatus(500));

        AlertService alerts = mock(AlertService.class);
        var handler = new GlobalExceptionHandler(new MockEnvironment(), alerts);
        handler.handleException(new IllegalStateException("lat=37.123456 lng=127.123456"), request);
        handler.handleBusinessException(BusinessException.internalError("lat=37.123456 lng=127.123456"), request);

        assertThat(output).doesNotContain("http_request", "37.123456", "127.123456", "session=123");
        verify(alerts, times(2)).recordServerError(eq("/api/walks/{id}/location"),
                argThat(error -> !error.getMessage().contains("37.123456") && error.getCause() == null), isNull());
    }
}
