package com.doggy.backend.global.weather;

import com.doggy.backend.global.exception.BusinessException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;
import java.util.ArrayList;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

class WeatherServiceTest {

    private final WeatherService weatherService = new WeatherService(org.mockito.Mockito.mock(RainObservationService.class));

    @Test
    void hourlyRainAmountIsRecordedEvenAfterRainStops() {
        var rain = org.mockito.Mockito.mock(RainObservationService.class);
        var service = new WeatherService(rain);
        ReflectionTestUtils.setField(service, "apiKey", "test-key");
        RestTemplate rest = (RestTemplate) ReflectionTestUtils.getField(service, "restTemplate");
        var server = MockRestServiceServer.bindTo(rest).build();
        server.expect(requestTo(org.hamcrest.Matchers.containsString("getUltraSrtNcst")))
                .andRespond(withSuccess("""
                        {"response":{"body":{"items":{"item":[
                        {"category":"PTY","obsrValue":"0"},{"category":"RN1","obsrValue":"2.5"}]}}}}
                        """, MediaType.APPLICATION_JSON));
        var observed = java.time.LocalDateTime.of(2026, 11, 26, 12, 0);
        assertThat(service.observeRain(57, 120, observed)).isTrue();
        org.mockito.Mockito.verify(rain).record(57, 120, observed.minusHours(1));
        server.verify();
    }

    @Test
    void recordsRainButNotDryOrSnowObservations() {
        for (int precipitation : new int[]{0, 1, 2, 3, 4, 5, 6, 7}) {
            var rain = org.mockito.Mockito.mock(RainObservationService.class);
            var service = new WeatherService(rain);
            ReflectionTestUtils.setField(service, "apiKey", "test-key");
            RestTemplate rest = (RestTemplate) ReflectionTestUtils.getField(service, "restTemplate");
            var server = MockRestServiceServer.bindTo(rest).build();
            server.expect(requestTo(org.hamcrest.Matchers.containsString("getUltraSrtNcst")))
                    .andRespond(withSuccess("{\"response\":{\"body\":{\"items\":{\"item\":[{\"category\":\"PTY\",\"obsrValue\":\""
                            + precipitation + "\"}]}}}}", MediaType.APPLICATION_JSON));
            ReflectionTestUtils.invokeMethod(service, "fetchObservation", new int[]{57, 120});
            if (precipitation == 0 || precipitation == 3 || precipitation == 7) {
                org.mockito.Mockito.verifyNoInteractions(rain);
            } else {
                org.mockito.Mockito.verify(rain).record(org.mockito.ArgumentMatchers.eq(57),
                        org.mockito.ArgumentMatchers.eq(120), org.mockito.ArgumentMatchers.any());
            }
            server.verify();
        }
    }

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

    @Test
    void distinctCoordinatesCannotGrowCacheWithoutBound() {
        var cache = new ConcurrentHashMap<String, WeatherService.CacheEntry<Integer>>();
        for (int i = 0; i < 600; i++) {
            int value = i;
            assertThat(weatherService.getCached(cache, "cell-" + i, Duration.ofMinutes(5), () -> value))
                    .isEqualTo(value);
        }
        assertThat(cache).hasSizeLessThanOrEqualTo(512);
    }

    @Test
    @SuppressWarnings("unchecked")
    void cleanupRemovesExpiredEntriesWithoutRemovingFreshOnes() {
        var cache = (ConcurrentMap<String, WeatherService.CacheEntry<WalkIndexResponse>>)
                ReflectionTestUtils.getField(weatherService, "walkIndexCache");
        cache.put("expired", new WeatherService.CacheEntry<>(null, 0));
        cache.put("fresh", new WeatherService.CacheEntry<>(null, System.currentTimeMillis() + 60_000));

        weatherService.cleanupExpiredCaches();

        assertThat(cache).containsKey("fresh").doesNotContainKey("expired");
    }

    @Test
    void slowWeatherFetchForOneCellDoesNotBlockAnotherCell() throws Exception {
        var cache = new ConcurrentHashMap<String, WeatherService.CacheEntry<Integer>>();
        var firstStarted = new CountDownLatch(1);
        var releaseFirst = new CountDownLatch(1);
        var pool = Executors.newFixedThreadPool(2);
        try {
            var first = pool.submit(() -> weatherService.getCached(cache, "first", Duration.ofMinutes(5), () -> {
                firstStarted.countDown();
                try {
                    releaseFirst.await();
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    throw new IllegalStateException(e);
                }
                return 1;
            }));
            assertThat(firstStarted.await(2, TimeUnit.SECONDS)).isTrue();

            var second = pool.submit(() -> weatherService.getCached(cache, "second", Duration.ofMinutes(5), () -> 2));
            assertThat(second.get(2, TimeUnit.SECONDS)).isEqualTo(2);
            releaseFirst.countDown();
            assertThat(first.get(2, TimeUnit.SECONDS)).isEqualTo(1);
        } finally {
            releaseFirst.countDown();
            pool.shutdownNow();
        }
    }

    @Test
    void concurrentRequestsForSameCellShareOneFetch() throws Exception {
        var cache = new ConcurrentHashMap<String, WeatherService.CacheEntry<Integer>>();
        var started = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        var fetches = new AtomicInteger();
        var pool = Executors.newFixedThreadPool(2);
        try {
            var first = pool.submit(() -> weatherService.getCached(cache, "same", Duration.ofMinutes(5), () -> {
                fetches.incrementAndGet();
                started.countDown();
                try {
                    release.await();
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    throw new IllegalStateException(e);
                }
                return 7;
            }));
            assertThat(started.await(2, TimeUnit.SECONDS)).isTrue();
            var second = pool.submit(() -> weatherService.getCached(cache, "same", Duration.ofMinutes(5), () -> {
                fetches.incrementAndGet();
                return 8;
            }));
            release.countDown();
            assertThat(first.get(2, TimeUnit.SECONDS)).isEqualTo(7);
            assertThat(second.get(2, TimeUnit.SECONDS)).isEqualTo(7);
            assertThat(fetches).hasValue(1);
        } finally {
            release.countDown();
            pool.shutdownNow();
        }
    }

    @Test
    void rejectsInvalidWeatherCoordinatesBeforeExternalCalls() {
        assertThatThrownBy(() -> weatherService.getWalkIndex(Double.NaN, 127.0))
                .hasMessageContaining("올바른 좌표");
        assertThatThrownBy(() -> weatherService.getWalkForecast(37.0, Double.POSITIVE_INFINITY))
                .hasMessageContaining("올바른 좌표");
    }

    @Test
    void limitsConcurrentExternalFetches() throws Exception {
        var cache = new ConcurrentHashMap<String, WeatherService.CacheEntry<Integer>>();
        var started = new CountDownLatch(8);
        var release = new CountDownLatch(1);
        var pool = Executors.newFixedThreadPool(8);
        var calls = new ArrayList<java.util.concurrent.Future<Integer>>();
        try {
            for (int i = 0; i < 8; i++) {
                String key = "cell-" + i;
                calls.add(pool.submit(() -> weatherService.getCached(cache, key, Duration.ofMinutes(5), () -> {
                    started.countDown();
                    try {
                        release.await();
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        throw new IllegalStateException(e);
                    }
                    return 1;
                })));
            }
            assertThat(started.await(2, TimeUnit.SECONDS)).isTrue();
            assertThatThrownBy(() -> weatherService.getCached(cache, "ninth", Duration.ofMinutes(5), () -> 9))
                    .isInstanceOf(BusinessException.class);
        } finally {
            release.countDown();
            for (var call : calls) call.get(2, TimeUnit.SECONDS);
            pool.shutdownNow();
        }
    }
}
