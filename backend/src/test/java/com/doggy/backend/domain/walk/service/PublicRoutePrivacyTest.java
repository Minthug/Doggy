package com.doggy.backend.domain.walk.service;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class PublicRoutePrivacyTest {

    @Test
    void minimizeGeoJsonRemovesPrivateEdgesAndLowersPrecision() {
        String geoJson = """
                {"type":"LineString","coordinates":[
                [127.000001,37.000001],
                [127.003001,37.000001],
                [127.006001,37.000001],
                [127.009001,37.000001],
                [127.012001,37.000001],
                [127.015001,37.000001],
                [127.018001,37.000001]
                ]}
                """;

        String result = PublicRoutePrivacy.minimizeGeoJson(geoJson);

        assertThat(result).isNotNull();
        assertThat(result).doesNotContain("127.000001");
        assertThat(result).doesNotContain("127.018001");
        assertThat(result).contains("[127.003,37.0]");
        assertThat(result).contains("[127.015,37.0]");
        assertThat(PublicRoutePrivacy.searchPoint(geoJson))
                .isEqualTo(new PublicRoutePrivacy.SearchPoint(37.0, 127.003));
    }

    @Test
    void minimizeGeoJsonReturnsNullWhenRouteIsTooShortAfterEdgeRemoval() {
        String geoJson = """
                {"type":"LineString","coordinates":[
                [127.000001,37.000001],
                [127.000501,37.000001],
                [127.001001,37.000001]
                ]}
                """;

        assertThat(PublicRoutePrivacy.minimizeGeoJson(geoJson)).isNull();
        assertThat(PublicRoutePrivacy.searchPoint(geoJson)).isNull();
    }

    @Test
    void straightRouteWithTwoStoredPointsStillHasAVisibleMiddle() {
        String geoJson = """
                {"type":"LineString","coordinates":[[127.0,37.0],[127.01,37.0]]}
                """;

        String result = PublicRoutePrivacy.minimizeGeoJson(geoJson);

        assertThat(result).contains("[127.003,37.0]", "[127.007,37.0]");
        assertThat(result).doesNotContain("[127.0,37.0]", "[127.01,37.0]");
        assertThat(PublicRoutePrivacy.searchPoint(geoJson))
                .isEqualTo(new PublicRoutePrivacy.SearchPoint(37.0, 127.003));
    }

    @Test
    void shortStraightRouteStaysPrivate() {
        String geoJson = """
                {"type":"LineString","coordinates":[[127.0,37.0],[127.005,37.0]]}
                """;

        assertThat(PublicRoutePrivacy.minimizeGeoJson(geoJson)).isNull();
    }

    @Test
    void pausedRouteKeepsSegmentsSeparateAndMasksEachEnd() {
        String geoJson = """
                {"type":"MultiLineString","coordinates":[
                  [[127.0,37.0],[127.003,37.0],[127.006,37.0],[127.009,37.0]],
                  [[127.02,37.0],[127.023,37.0],[127.026,37.0],[127.029,37.0]]
                ]}
                """;

        String result = PublicRoutePrivacy.minimizeGeoJson(geoJson);

        assertThat(result).contains("MultiLineString", "[[127.003,37.0],[127.006,37.0]]",
                "[[127.023,37.0],[127.026,37.0]]");
        assertThat(result).doesNotContain("[127.0,37.0]", "[127.009,37.0]",
                "[127.02,37.0]", "[127.029,37.0]");
        assertThat(PublicRoutePrivacy.searchPoint(geoJson))
                .isEqualTo(new PublicRoutePrivacy.SearchPoint(37.0, 127.003));
    }
}
