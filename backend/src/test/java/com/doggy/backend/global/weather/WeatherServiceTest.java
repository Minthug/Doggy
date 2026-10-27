package com.doggy.backend.global.weather;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestTemplate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

class WeatherServiceTest {

    private final WeatherService weatherService = new WeatherService();

    @Test
    @DisplayName("미세먼지 정보가 없으면 좋은 날씨도 산책 주의로 제한한다")
    void unavailableAirQualityNeverReturnsGood() {
        WalkIndex index = weatherService.calculateIndex(
                new WeatherService.WeatherData(20, 0, 0),
                WeatherService.AirData.unavailable()
        );

        assertThat(index).isEqualTo(WalkIndex.CAUTION);
    }

    @Test
    @DisplayName("한 측정값이 매우 나쁘면 다른 측정값이 없어도 산책 자제한다")
    void knownVeryBadAirQualityStillReturnsAvoid() {
        WalkIndex index = weatherService.calculateIndex(
                new WeatherService.WeatherData(20, 0, 0),
                new WeatherService.AirData(180, null, "매우나쁨", "정보 없음")
        );

        assertThat(index).isEqualTo(WalkIndex.AVOID);
    }

    @Test
    @DisplayName("미세먼지 정보가 없으면 응답에 임의 수치를 넣지 않는다")
    void unavailableAirQualityUsesNullValuesAndExplanation() {
        WalkIndexResponse response = WalkIndexResponse.of(
                WalkIndex.CAUTION,
                20,
                0,
                0,
                null,
                null,
                "정보 없음",
                "정보 없음"
        );

        assertThat(response.pm10()).isNull();
        assertThat(response.pm25()).isNull();
        assertThat(response.airQualityAvailable()).isFalse();
        assertThat(response.description()).contains("미세먼지 정보는 현재 확인할 수 없어요");
    }

    @Test
    @DisplayName("기존 공공데이터 키로 가까운 측정소의 실제 미세먼지 값을 조회한다")
    void fetchesAirQualityFromNearestStationWithSharedApiKey() {
        ReflectionTestUtils.setField(weatherService, "apiKey", "shared-key");
        ReflectionTestUtils.setField(weatherService, "airStationApiKey", "");
        RestTemplate restTemplate = (RestTemplate) ReflectionTestUtils.getField(weatherService, "restTemplate");
        MockRestServiceServer server = MockRestServiceServer.bindTo(restTemplate).build();

        server.expect(requestTo(org.hamcrest.Matchers.containsString(
                        "/MsrstnInfoInqireSvc/getNearbyMsrstnList?serviceKey=shared-key")))
                .andRespond(withSuccess("""
                        {"response":{"header":{"resultCode":"00"},"body":{"items":[{"stationName":"봉담읍"}]}}}
                        """, MediaType.APPLICATION_JSON));
        server.expect(requestTo(org.hamcrest.Matchers.containsString(
                        "/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty?serviceKey=shared-key")))
                .andRespond(withSuccess("""
                        {"response":{"header":{"resultCode":"00"},"body":{"items":[{"pm10Value":"17","pm25Value":"5"}]}}}
                        """, MediaType.APPLICATION_JSON));

        WeatherService.AirData result = ReflectionTestUtils.invokeMethod(
                weatherService, "fetchAirQuality", 37.218392, 126.944858);

        assertThat(result).isEqualTo(new WeatherService.AirData(17, 5, "좋음", "좋음"));
        server.verify();
    }
}
