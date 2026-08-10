package com.doggy.backend.global.alert;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThatCode;

class DiscordAlertServiceTest {

    @Test
    void alertIsNoopWhenWebhookIsMissing() {
        DiscordAlertService service = new DiscordAlertService(new ObjectMapper());
        ReflectionTestUtils.setField(service, "webhookUrl", "");
        ReflectionTestUtils.setField(service, "windowSeconds", 300L);
        ReflectionTestUtils.setField(service, "cooldownSeconds", 300L);
        ReflectionTestUtils.setField(service, "serverErrorThreshold", 1);

        assertThatCode(() ->
                service.recordServerError("/api/test", new IllegalStateException("boom"), "request-1")
        ).doesNotThrowAnyException();
    }
}
