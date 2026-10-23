package com.doggy.backend.domain.walk.service;

import com.doggy.backend.global.exception.BusinessException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class WalkTracePathServiceTest {

    private final WalkTracePathService service = new WalkTracePathService(new ObjectMapper());

    @Test
    void createsCompactNormalizedPathWithoutOriginalCoordinates() {
        String geoJson = """
                {"type":"LineString","coordinates":[
                  [127.123456,37.555555],[127.124111,37.556222],[127.125222,37.557333]
                ]}
                """;

        String pathData = service.createPathData(geoJson);

        assertThat(pathData).startsWith("v1|").contains(";");
        assertThat(pathData).doesNotContain("127.123456", "37.555555");
        assertThat(pathData.length()).isLessThan(80);
    }

    @Test
    void samplesLongRouteToAtMostSeventyTwoPoints() {
        String coordinates = IntStream.range(0, 500)
                .mapToObj(i -> "[" + (127.0 + i * 0.00001) + "," + (37.0 + i * 0.00001) + "]")
                .reduce((a, b) -> a + "," + b)
                .orElseThrow();

        String pathData = service.createPathData(
                "{\"type\":\"LineString\",\"coordinates\":[" + coordinates + "]}");

        assertThat(pathData.split(";")).hasSize(72);
        assertThat(pathData.length()).isLessThan(800);
    }

    @Test
    void rejectsRouteWithFewerThanTwoPoints() {
        assertThatThrownBy(() -> service.createPathData(
                "{\"type\":\"LineString\",\"coordinates\":[[127.1,37.5]]}"))
                .isInstanceOf(BusinessException.class);
    }
}
