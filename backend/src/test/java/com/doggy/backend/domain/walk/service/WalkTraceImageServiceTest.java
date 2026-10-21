package com.doggy.backend.domain.walk.service;

import com.doggy.backend.global.exception.BusinessException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class WalkTraceImageServiceTest {

    private final WalkTraceImageService service = new WalkTraceImageService(new ObjectMapper());

    @Test
    void createsNormalizedSvgWithoutOriginalCoordinates() {
        String geoJson = """
                {"type":"LineString","coordinates":[
                  [127.123456,37.555555],[127.124111,37.556222],[127.125222,37.557333]
                ]}
                """;

        String svg = service.createSvg(geoJson);

        assertThat(svg).contains("<svg", "<path", "viewBox=\"0 0 600 360\"");
        assertThat(svg).doesNotContain("127.123456", "37.555555");
    }

    @Test
    void rejectsRouteWithFewerThanTwoPoints() {
        assertThatThrownBy(() -> service.createSvg(
                "{\"type\":\"LineString\",\"coordinates\":[[127.1,37.5]]}"))
                .isInstanceOf(BusinessException.class);
    }
}
