package com.doggy.backend.global.weather;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.*;
import java.util.stream.Collectors;

@Slf4j
@Service
public class WeatherService {

    private static final String OBSERVATION_URL =
            "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst";
    private static final String FORECAST_URL =
            "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst";
    private static final String AIR_STATION_URL =
            "https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesurDnsty";
    private static final String NEARBY_STATION_URL =
            "https://apis.data.go.kr/B552584/MsrstnInfoInqireSvc/getNearbyMsrstnList";

    private static final double DEFAULT_LAT = 37.218392;
    private static final double DEFAULT_LNG = 126.944858;

    private static final long CACHE_TTL_MS = 10 * 60 * 1000L; // 10분

    @Value("${weather.api.key}")
    private String apiKey;

    @Value("${air.station.api.key}")
    private String airStationApiKey;

    private final RestTemplate restTemplate = new RestTemplateBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .readTimeout(Duration.ofSeconds(10))
            .build();

    // 병렬 외부 API 호출용 스레드풀
    private final ExecutorService executor = Executors.newFixedThreadPool(6);

    // 간단한 인메모리 캐시 (key → {value, expiresAtMs})
    private final ConcurrentHashMap<String, Object[]> cache = new ConcurrentHashMap<>();

    // ── 공개 API ────────────────────────────────────────────────

    public WalkIndexResponse getWalkIndex() {
        return getWalkIndex(DEFAULT_LAT, DEFAULT_LNG);
    }

    public WalkIndexResponse getWalkIndex(double lat, double lng, String sido) {
        return getWalkIndex(lat, lng);
    }

    public WalkIndexResponse getWalkIndex(double lat, double lng) {
        String key = cacheKey("index", lat, lng);
        WalkIndexResponse cached = fromCache(key);
        if (cached != null) {
            log.debug("[날씨캐시] walk-index 히트");
            return cached;
        }

        int[] grid = KmaGridConverter.toGrid(lat, lng);

        // 기상청(기온+강수) 와 에어코리아(미세먼지) 를 병렬 호출
        CompletableFuture<WeatherData> weatherFuture =
                CompletableFuture.supplyAsync(() -> fetchWeather(grid), executor);
        CompletableFuture<AirData> airFuture =
                CompletableFuture.supplyAsync(() -> fetchAirQuality(lat, lng), executor);

        WeatherData weather = safeGet(weatherFuture, new WeatherData(20, 0, 0));
        AirData air        = safeGet(airFuture,     new AirData(30, 10, "보통", "보통"));

        WalkIndex index = calculateIndex(weather, air);
        WalkIndexResponse result = WalkIndexResponse.of(
                index, weather.tmp(), weather.pop(), weather.pty(),
                air.pm10(), air.pm25(), air.pm10Grade(), air.pm25Grade());

        toCache(key, result);
        return result;
    }

    public WalkForecastResponse getWalkForecast() {
        return getWalkForecast(DEFAULT_LAT, DEFAULT_LNG);
    }

    public WalkForecastResponse getWalkForecast(double lat, double lng) {
        String key = cacheKey("forecast", lat, lng);
        WalkForecastResponse cached = fromCache(key);
        if (cached != null) {
            log.debug("[날씨캐시] walk-forecast 히트");
            return cached;
        }

        int[] grid = KmaGridConverter.toGrid(lat, lng);

        // 에어코리아와 시간대별 예보를 병렬 호출
        CompletableFuture<AirData> airFuture =
                CompletableFuture.supplyAsync(() -> fetchAirQuality(lat, lng), executor);
        CompletableFuture<List<HourlyForecast>> hourlyFuture =
                CompletableFuture.supplyAsync(() -> fetchNextHourlyForecasts(grid, 3), executor);

        AirData air              = safeGet(airFuture,     new AirData(30, 10, "보통", "보통"));
        List<HourlyForecast> hourly = safeGet(hourlyFuture,
                List.of(new HourlyForecast(20, 0, 0), new HourlyForecast(20, 0, 0), new HourlyForecast(20, 0, 0)));

        String[] labels = {"지금", "+30분", "+1시간", "+1시간30분", "+2시간"};
        int[] hourIdx   = {0,      0,       1,       1,            2};

        List<WalkForecastSlot> slots = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            int idx = Math.min(hourIdx[i], hourly.size() - 1);
            HourlyForecast f = hourly.get(idx);
            WalkIndex index = calculateIndex(new WeatherData(f.tmp(), f.pop(), f.pty()), air);
            slots.add(new WalkForecastSlot(
                    labels[i], index, index.label, index.emoji,
                    f.tmp(), f.pop(), precipitationLabel(f.pty()), f.pty() != 0));
        }

        WalkForecastResponse result = new WalkForecastResponse(slots);
        toCache(key, result);
        return result;
    }

    // ── 산책 지수 계산 ────────────────────────────────────────

    private WalkIndex calculateIndex(WeatherData w, AirData a) {
        if (w.tmp() < 0 || w.tmp() > 32) return WalkIndex.AVOID;
        if (w.pty() != 0)                return WalkIndex.AVOID;
        if (w.pop() >= 60)               return WalkIndex.AVOID;
        if ("매우나쁨".equals(a.pm10Grade()) || "매우나쁨".equals(a.pm25Grade())) return WalkIndex.AVOID;

        if (w.tmp() < 5 || w.tmp() > 27) return WalkIndex.CAUTION;
        if (w.pop() >= 30)                return WalkIndex.CAUTION;
        if ("나쁨".equals(a.pm10Grade()) || "나쁨".equals(a.pm25Grade())) return WalkIndex.CAUTION;

        return WalkIndex.GOOD;
    }

    // ── 기상청 날씨 (기온 + 강수 병렬) ────────────────────────

    private WeatherData fetchWeather(int[] grid) {
        // 초단기실황(기온)과 단기예보(강수)를 병렬 호출
        CompletableFuture<Integer> tmpFuture =
                CompletableFuture.supplyAsync(() -> fetchObservedTemperature(grid), executor);
        CompletableFuture<int[]> precipFuture =
                CompletableFuture.supplyAsync(() -> fetchPrecipitation(grid), executor);

        int tmp    = safeGet(tmpFuture, 20);
        int[] popPty = safeGet(precipFuture, new int[]{0, 0});
        return new WeatherData(tmp, popPty[0], popPty[1]);
    }

    @SuppressWarnings("unchecked")
    private int fetchObservedTemperature(int[] grid) {
        try {
            String baseDate = getBaseDate();
            String baseTime = getObsBaseTime();

            String url = OBSERVATION_URL
                    + "?serviceKey=" + apiKey
                    + "&pageNo=1&numOfRows=10&dataType=JSON"
                    + "&base_date=" + baseDate
                    + "&base_time=" + baseTime
                    + "&nx=" + grid[0]
                    + "&ny=" + grid[1];

            Map<String, Object> response = restTemplate.getForObject(new java.net.URI(url), Map.class);
            Map<String, Object> body = (Map<String, Object>)
                    ((Map<String, Object>) response.get("response")).get("body");
            List<Map<String, Object>> items = (List<Map<String, Object>>)
                    ((Map<String, Object>) body.get("items")).get("item");

            for (Map<String, Object> item : items) {
                if ("T1H".equals(item.get("category"))) {
                    double val = Double.parseDouble(item.get("obsrValue").toString());
                    log.info("초단기실황 기온 ({}{}) - {}도", baseDate, baseTime, val);
                    return (int) Math.round(val);
                }
            }
        } catch (Exception e) {
            log.warn("초단기실황 API 호출 실패: {}", e.getMessage());
        }
        return 20;
    }

    @SuppressWarnings("unchecked")
    private int[] fetchPrecipitation(int[] grid) {
        try {
            String baseDate = getBaseDate();
            String baseTime = getBaseTime();

            String url = FORECAST_URL
                    + "?serviceKey=" + apiKey
                    + "&pageNo=1&numOfRows=300&dataType=JSON"
                    + "&base_date=" + baseDate
                    + "&base_time=" + baseTime
                    + "&nx=" + grid[0]
                    + "&ny=" + grid[1];

            Map<String, Object> response = restTemplate.getForObject(new java.net.URI(url), Map.class);
            Map<String, Object> body = (Map<String, Object>)
                    ((Map<String, Object>) response.get("response")).get("body");
            List<Map<String, Object>> items = (List<Map<String, Object>>)
                    ((Map<String, Object>) body.get("items")).get("item");

            String targetDate = getTargetFcstDate();
            String targetTime = getTargetFcstTime();
            int pop = 0, pty = 0;

            for (Map<String, Object> item : items) {
                if (!targetDate.equals(item.get("fcstDate"))) continue;
                if (!targetTime.equals(item.get("fcstTime"))) continue;
                String category = (String) item.get("category");
                if (!"POP".equals(category) && !"PTY".equals(category)) continue;
                try {
                    int value = (int) Math.round(Double.parseDouble(item.get("fcstValue").toString()));
                    if ("POP".equals(category)) pop = value;
                    else pty = value;
                } catch (NumberFormatException ignored) {}
            }
            log.info("단기예보 ({}{}) - 강수확률:{}%, 강수형태:{}", targetDate, targetTime, pop, pty);
            return new int[]{pop, pty};

        } catch (Exception e) {
            log.warn("단기예보 API 호출 실패: {}", e.getMessage());
            return new int[]{0, 0};
        }
    }

    // ── 에어코리아 미세먼지 ──────────────────────────────────

    private AirData fetchAirQuality(double lat, double lng) {
        try {
            String stationName = fetchNearestStation(lat, lng);
            if (stationName == null) {
                log.warn("근처 측정소를 찾지 못했습니다. 기본값 사용");
                return new AirData(30, 10, "보통", "보통");
            }
            String encodedStation = URLEncoder.encode(stationName, StandardCharsets.UTF_8);
            String url = AIR_STATION_URL + "?serviceKey=" + airStationApiKey
                    + "&returnType=json&numOfRows=1&pageNo=1"
                    + "&stationName=" + encodedStation
                    + "&dataTerm=DAILY&ver=1.0";

            Map<String, Object> response = restTemplate.getForObject(new java.net.URI(url), Map.class);
            return parseAir(stationName, response);

        } catch (Exception e) {
            log.warn("에어코리아 API 호출 실패 [{}]: {}", e.getClass().getSimpleName(), e.getMessage());
            return new AirData(30, 10, "보통", "보통");
        }
    }

    private static final double[][] STATION_COORDS = {
            {37.5665, 126.9780}, {37.5172, 127.0473}, {37.5491, 126.9168},
            {37.2636, 127.0286}, {37.4196, 127.1267}, {37.6584, 126.8320},
            {37.4563, 126.7052}, {35.1796, 129.0756}, {35.8714, 128.6014},
            {35.1595, 126.8526}, {36.3504, 127.3845}, {35.5384, 129.3114},
            {36.4800, 127.2890}, {33.4996, 126.5312}
    };
    private static final String[] STATION_NAMES = {
            "중구", "강남구", "마포구",
            "수원", "성남", "고양",
            "인천", "부산", "대구",
            "광주", "대전", "울산",
            "세종", "제주"
    };

    @SuppressWarnings("unchecked")
    private String fetchNearestStation(double lat, double lng) {
        try {
            double[] tm = toTm(lat, lng);
            String url = NEARBY_STATION_URL + "?serviceKey=" + airStationApiKey
                    + "&returnType=json&numOfRows=1&pageNo=1"
                    + "&tmX=" + tm[0]
                    + "&tmY=" + tm[1]
                    + "&ver=1.1";

            Map<String, Object> response = restTemplate.getForObject(new java.net.URI(url), Map.class);
            Map<String, Object> res  = (Map<String, Object>) response.get("response");
            Map<String, Object> body = (Map<String, Object>) res.get("body");
            List<Map<String, Object>> items = (List<Map<String, Object>>) body.get("items");

            if (items == null || items.isEmpty()) return fallbackStation(lat, lng);
            String stationName = (String) items.get(0).get("stationName");
            log.info("가장 가까운 측정소: {}", stationName);
            return stationName;

        } catch (Exception e) {
            log.warn("측정소 조회 실패 (fallback 사용): {}", e.getMessage());
            return fallbackStation(lat, lng);
        }
    }

    private String fallbackStation(double lat, double lng) {
        int nearest = 0;
        double minDist = Double.MAX_VALUE;
        for (int i = 0; i < STATION_COORDS.length; i++) {
            double d = Math.pow(lat - STATION_COORDS[i][0], 2) + Math.pow(lng - STATION_COORDS[i][1], 2);
            if (d < minDist) { minDist = d; nearest = i; }
        }
        log.info("측정소 fallback 사용: {}", STATION_NAMES[nearest]);
        return STATION_NAMES[nearest];
    }

    @SuppressWarnings("unchecked")
    private AirData parseAir(String stationName, Map<String, Object> response) {
        try {
            Map<String, Object> res  = (Map<String, Object>) response.get("response");
            Map<String, Object> body = (Map<String, Object>) res.get("body");
            List<Map<String, Object>> items = (List<Map<String, Object>>) body.get("items");

            if (items == null || items.isEmpty()) return new AirData(30, 10, "보통", "보통");

            Map<String, Object> item = items.get(0);
            int pm10 = parseAirValue(item.get("pm10Value"));
            int pm25 = parseAirValue(item.get("pm25Value"));
            log.info("미세먼지 ({}) - PM10:{}, PM2.5:{}", stationName, pm10, pm25);
            return new AirData(pm10, pm25, gradeByValue(pm10, "pm10"), gradeByValue(pm25, "pm25"));

        } catch (Exception e) {
            log.warn("미세먼지 데이터 파싱 실패: {}", e.getMessage());
            return new AirData(30, 10, "보통", "보통");
        }
    }

    // ── 2시간 예보 ────────────────────────────────────────────

    private static String precipitationLabel(int pty) {
        return switch (pty) {
            case 1 -> "비";
            case 2 -> "비/눈";
            case 3 -> "눈";
            case 4 -> "소나기";
            default -> "없음";
        };
    }

    @SuppressWarnings("unchecked")
    private List<HourlyForecast> fetchNextHourlyForecasts(int[] grid, int count) {
        try {
            String baseDate = getBaseDate();
            String baseTime = getBaseTime();

            String url = FORECAST_URL
                    + "?serviceKey=" + apiKey
                    + "&pageNo=1&numOfRows=500&dataType=JSON"
                    + "&base_date=" + baseDate
                    + "&base_time=" + baseTime
                    + "&nx=" + grid[0]
                    + "&ny=" + grid[1];

            Map<String, Object> response = restTemplate.getForObject(new java.net.URI(url), Map.class);
            Map<String, Object> body = (Map<String, Object>)
                    ((Map<String, Object>) response.get("response")).get("body");
            List<Map<String, Object>> items = (List<Map<String, Object>>)
                    ((Map<String, Object>) body.get("items")).get("item");

            ZonedDateTime now = ZonedDateTime.now(KST);
            String nowKey = now.toLocalDate().format(DateTimeFormatter.ofPattern("yyyyMMdd"))
                    + String.format("%02d00", now.getHour());

            Map<String, int[]> hourMap = new LinkedHashMap<>();
            for (Map<String, Object> item : items) {
                String fcstDate = (String) item.get("fcstDate");
                String fcstTime = (String) item.get("fcstTime");
                String category = (String) item.get("category");

                if (!"TMP".equals(category) && !"POP".equals(category) && !"PTY".equals(category)) continue;
                if ((fcstDate + fcstTime).compareTo(nowKey) < 0) continue;

                String key = fcstDate + fcstTime;
                hourMap.putIfAbsent(key, new int[]{20, 0, 0});
                int[] vals = hourMap.get(key);
                try {
                    int v = (int) Math.round(Double.parseDouble(item.get("fcstValue").toString()));
                    if ("TMP".equals(category))      vals[0] = v;
                    else if ("POP".equals(category)) vals[1] = v;
                    else if ("PTY".equals(category)) vals[2] = v;
                } catch (NumberFormatException ignored) {}
            }

            List<HourlyForecast> result = hourMap.values().stream()
                    .map(v -> new HourlyForecast(v[0], v[1], v[2]))
                    .limit(count)
                    .collect(Collectors.toList());

            return result.isEmpty()
                    ? List.of(new HourlyForecast(20, 0, 0))
                    : result;

        } catch (Exception e) {
            log.warn("시간대별 예보 조회 실패: {}", e.getMessage());
            return List.of(new HourlyForecast(20, 0, 0), new HourlyForecast(20, 0, 0), new HourlyForecast(20, 0, 0));
        }
    }

    // ── 캐시 헬퍼 ────────────────────────────────────────────

    private String cacheKey(String type, double lat, double lng) {
        // 소수점 1자리 반올림 → 약 10km 단위로 공유
        return type + ":" + Math.round(lat * 10) + ":" + Math.round(lng * 10);
    }

    @SuppressWarnings("unchecked")
    private <T> T fromCache(String key) {
        Object[] entry = cache.get(key);
        if (entry == null) return null;
        long expiresAt = (long) entry[1];
        if (System.currentTimeMillis() > expiresAt) {
            cache.remove(key);
            return null;
        }
        return (T) entry[0];
    }

    private void toCache(String key, Object value) {
        cache.put(key, new Object[]{value, System.currentTimeMillis() + CACHE_TTL_MS});
    }

    // ── CompletableFuture 헬퍼 ───────────────────────────────

    private <T> T safeGet(CompletableFuture<T> future, T fallback) {
        try {
            return future.get(12, TimeUnit.SECONDS);
        } catch (Exception e) {
            log.warn("병렬 날씨 호출 실패 (fallback 사용): {}", e.getMessage());
            return fallback;
        }
    }

    // ── 좌표 변환 ────────────────────────────────────────────

    private double[] toTm(double lat, double lng) {
        double a   = 6378137.0;
        double f   = 1.0 / 298.257222101;
        double k0  = 1.0;
        double lon0 = Math.toRadians(127.0);
        double lat0 = Math.toRadians(38.0);
        double E0  = 200000.0;
        double N0  = 500000.0;

        double e2  = 2 * f - f * f;
        double ep2 = e2 / (1 - e2);

        double latR = Math.toRadians(lat);
        double lonR = Math.toRadians(lng);

        double N  = a / Math.sqrt(1 - e2 * Math.sin(latR) * Math.sin(latR));
        double T  = Math.tan(latR) * Math.tan(latR);
        double C  = ep2 * Math.cos(latR) * Math.cos(latR);
        double A  = Math.cos(latR) * (lonR - lon0);

        double e4 = e2 * e2, e6 = e4 * e2;
        double M  = a * (
                (1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * latR
                - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * Math.sin(2 * latR)
                + (15 * e4 / 256 + 45 * e6 / 1024) * Math.sin(4 * latR)
                - (35 * e6 / 3072) * Math.sin(6 * latR));
        double M0 = a * (
                (1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * lat0
                - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * Math.sin(2 * lat0)
                + (15 * e4 / 256 + 45 * e6 / 1024) * Math.sin(4 * lat0)
                - (35 * e6 / 3072) * Math.sin(6 * lat0));

        double A2 = A * A, A3 = A2 * A, A4 = A3 * A, A5 = A4 * A, A6 = A5 * A;
        double x  = E0 + k0 * N * (A + (1 - T + C) * A3 / 6
                + (5 - 18 * T + T * T + 72 * C - 58 * ep2) * A5 / 120);
        double y  = N0 + k0 * (M - M0 + N * Math.tan(latR) * (A2 / 2
                + (5 - T + 9 * C + 4 * C * C) * A4 / 24
                + (61 - 58 * T + T * T + 600 * C - 330 * ep2) * A6 / 720));

        return new double[]{x, y};
    }

    // ── 등급 계산 ─────────────────────────────────────────────

    private String gradeByValue(int value, String type) {
        if ("pm10".equals(type)) {
            if (value <= 30)  return "좋음";
            if (value <= 80)  return "보통";
            if (value <= 150) return "나쁨";
            return "매우나쁨";
        } else {
            if (value <= 15)  return "좋음";
            if (value <= 35)  return "보통";
            if (value <= 75)  return "나쁨";
            return "매우나쁨";
        }
    }

    private int parseAirValue(Object val) {
        if (val == null || "-".equals(val.toString())) return 30;
        try { return Integer.parseInt(val.toString()); }
        catch (NumberFormatException e) { return 30; }
    }

    // ── 시간 헬퍼 ─────────────────────────────────────────────

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");

    private String getBaseDate() {
        ZonedDateTime now = ZonedDateTime.now(KST);
        if (now.toLocalTime().isBefore(LocalTime.of(2, 10))) {
            return now.minusDays(1).toLocalDate().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
        }
        return now.toLocalDate().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
    }

    private String getObsBaseTime() {
        ZonedDateTime now = ZonedDateTime.now(KST);
        int hour = now.getHour();
        if (now.getMinute() < 10) hour = (hour - 1 + 24) % 24;
        return String.format("%02d00", hour);
    }

    private String getBaseTime() {
        LocalTime now = ZonedDateTime.now(KST).toLocalTime();
        if (now.isBefore(LocalTime.of(2, 10)))  return "2300";
        if (now.isBefore(LocalTime.of(5, 10)))  return "0200";
        if (now.isBefore(LocalTime.of(8, 10)))  return "0500";
        if (now.isBefore(LocalTime.of(11, 10))) return "0800";
        if (now.isBefore(LocalTime.of(14, 10))) return "1100";
        if (now.isBefore(LocalTime.of(17, 10))) return "1400";
        if (now.isBefore(LocalTime.of(20, 10))) return "1700";
        return "2000";
    }

    private String getTargetFcstDate() {
        return ZonedDateTime.now(KST).toLocalDate().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
    }

    private String getTargetFcstTime() {
        LocalTime now = ZonedDateTime.now(KST).toLocalTime();
        if (now.isBefore(LocalTime.of(3, 0)))  return "0000";
        if (now.isBefore(LocalTime.of(6, 0)))  return "0300";
        if (now.isBefore(LocalTime.of(9, 0)))  return "0600";
        if (now.isBefore(LocalTime.of(12, 0))) return "0900";
        if (now.isBefore(LocalTime.of(15, 0))) return "1200";
        if (now.isBefore(LocalTime.of(18, 0))) return "1500";
        if (now.isBefore(LocalTime.of(21, 0))) return "1800";
        return "2100";
    }

    // ── 내부 데이터 클래스 ────────────────────────────────────

    record WeatherData(int tmp, int pop, int pty) {}
    record AirData(int pm10, int pm25, String pm10Grade, String pm25Grade) {}
    record HourlyForecast(int tmp, int pop, int pty) {}
}
