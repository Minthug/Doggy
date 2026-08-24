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
import java.util.function.Supplier;
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

    private static final double DEFAULT_LAT = 37.218392;
    private static final double DEFAULT_LNG = 126.944858;
    private static final Duration WALK_INDEX_CACHE_TTL = Duration.ofMinutes(5);
    private static final Duration WALK_FORECAST_CACHE_TTL = Duration.ofMinutes(5);

    @Value("${weather.api.key}")
    private String apiKey;

    @Value("${air.station.api.key}")
    private String airStationApiKey;

    private final RestTemplate restTemplate = new RestTemplateBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .readTimeout(Duration.ofSeconds(5))
            .build();

    // 병렬 외부 API 호출용 스레드풀
    private final ExecutorService executor = Executors.newFixedThreadPool(4);

    private final ConcurrentMap<String, CacheEntry<WalkIndexResponse>> walkIndexCache = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, CacheEntry<WalkForecastResponse>> walkForecastCache = new ConcurrentHashMap<>();

    // ── 공개 API ────────────────────────────────────────────────

    public WalkIndexResponse getWalkIndex() {
        return doGetWalkIndex(DEFAULT_LAT, DEFAULT_LNG);
    }

    public WalkIndexResponse getWalkIndex(double lat, double lng, String sido) {
        return doGetWalkIndex(lat, lng);
    }

    public WalkIndexResponse getWalkIndex(double lat, double lng) {
        return doGetWalkIndex(lat, lng);
    }

    private WalkIndexResponse doGetWalkIndex(double lat, double lng) {
        return getCached(
                walkIndexCache,
                weatherCacheKey("walk-index", lat, lng),
                WALK_INDEX_CACHE_TTL,
                () -> fetchWalkIndex(lat, lng)
        );
    }

    private WalkIndexResponse fetchWalkIndex(double lat, double lng) {
        int[] grid = KmaGridConverter.toGrid(lat, lng);

        CompletableFuture<WeatherData> weatherFuture =
                CompletableFuture.supplyAsync(() -> fetchWeather(grid), executor);
        CompletableFuture<AirData> airFuture =
                CompletableFuture.supplyAsync(() -> fetchAirQuality(lat, lng), executor);

        WeatherData weather = safeGet(weatherFuture, null);
        AirData air        = safeGet(airFuture,     new AirData(30, 10, "보통", "보통"));

        if (weather == null) {
            return WalkIndexResponse.of(
                    WalkIndex.CAUTION, 20, 0, 0,
                    air.pm10(), air.pm25(), air.pm10Grade(), air.pm25Grade());
        }

        WalkIndex index = calculateIndex(weather, air);
        return WalkIndexResponse.of(
                index, weather.tmp(), weather.pop(), weather.pty(),
                air.pm10(), air.pm25(), air.pm10Grade(), air.pm25Grade());
    }

    public WalkForecastResponse getWalkForecast() {
        return doGetWalkForecast(DEFAULT_LAT, DEFAULT_LNG);
    }

    public WalkForecastResponse getWalkForecast(double lat, double lng) {
        return doGetWalkForecast(lat, lng);
    }

    private WalkForecastResponse doGetWalkForecast(double lat, double lng) {
        return getCached(
                walkForecastCache,
                weatherCacheKey("walk-forecast", lat, lng),
                WALK_FORECAST_CACHE_TTL,
                () -> fetchWalkForecast(lat, lng)
        );
    }

    private WalkForecastResponse fetchWalkForecast(double lat, double lng) {
        int[] grid = KmaGridConverter.toGrid(lat, lng);

        CompletableFuture<AirData> airFuture =
                CompletableFuture.supplyAsync(() -> fetchAirQuality(lat, lng), executor);
        CompletableFuture<List<HourlyForecast>> hourlyFuture =
                CompletableFuture.supplyAsync(() -> fetchNextHourlyForecasts(grid, 3), executor);
        CompletableFuture<WeatherData> nowFuture =
                CompletableFuture.supplyAsync(() -> fetchObservation(grid), executor);

        AirData air = safeGet(airFuture, new AirData(30, 10, "보통", "보통"));
        List<HourlyForecast> hourly = safeGet(hourlyFuture,
                List.of(new HourlyForecast(20, 0, 0), new HourlyForecast(20, 0, 0), new HourlyForecast(20, 0, 0)));
        WeatherData nowWeather = safeGet(nowFuture, null);

        String[] labels = {"지금", "+30분", "+1시간", "+1시간30분", "+2시간"};
        int[] hourIdx       = {0, 0, 1, 1, 2};
        int[] offsetMinutes = {0, 30, 60, 90, 120};

        ZonedDateTime now = ZonedDateTime.now(KST);

        List<WalkForecastSlot> slots = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            int idx = Math.min(hourIdx[i], hourly.size() - 1);
            HourlyForecast f = hourly.get(idx);

            int tmp = (i < 2 && nowWeather != null) ? nowWeather.tmp() : f.tmp();
            int pty = (i < 2 && nowWeather != null) ? nowWeather.pty() : f.pty();

            ZonedDateTime slotTime = now.plusMinutes(offsetMinutes[i]);
            boolean isNight = isNight(lat, slotTime);

            WalkIndex index = calculateIndex(new WeatherData(tmp, f.pop(), pty), air);
            slots.add(new WalkForecastSlot(
                    labels[i], index, index.label, index.emoji,
                    tmp, f.pop(), precipitationLabel(pty), pty != 0, isNight));
        }

        return new WalkForecastResponse(slots);
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

    // ── 기상청 초단기실황 (기온 + 강수형태 한 번에) ────────────

    private WeatherData fetchWeather(int[] grid) {
        return fetchObservation(grid);
    }

    @SuppressWarnings("unchecked")
    private WeatherData fetchObservation(int[] grid) {
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

            int tmp = 20, pty = 0;
            for (Map<String, Object> item : items) {
                String category = (String) item.get("category");
                try {
                    double val = Double.parseDouble(item.get("obsrValue").toString());
                    if ("T1H".equals(category)) tmp = (int) Math.round(val);
                    else if ("PTY".equals(category)) pty = (int) val;
                } catch (NumberFormatException ignored) {}
            }
            log.info("초단기실황 ({}{}) - 기온:{}도 강수형태:{}", baseDate, baseTime, tmp, pty);
            return new WeatherData(tmp, 0, pty);

        } catch (Exception e) {
            log.warn("초단기실황 API 호출 실패: {}", e.getMessage());
            return null;
        }
    }

    // ── 에어코리아 미세먼지 ──────────────────────────────────

    private AirData fetchAirQuality(double lat, double lng) {
        try {
            // 측정소 조회 API 대신 좌표 기반 fallback으로 즉시 결정 (API 호출 1개 절약)
            String stationName = fallbackStation(lat, lng);
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


    // ── CompletableFuture 헬퍼 ───────────────────────────────

    private <T> T safeGet(CompletableFuture<T> future, T fallback) {
        try {
            return future.get(6, TimeUnit.SECONDS);
        } catch (Exception e) {
            log.warn("병렬 날씨 호출 실패 (fallback 사용): {}", e.getMessage());
            return fallback;
        }
    }

    private <T> T getCached(
            ConcurrentMap<String, CacheEntry<T>> cache,
            String key,
            Duration ttl,
            Supplier<T> supplier
    ) {
        long now = System.currentTimeMillis();
        CacheEntry<T> cached = cache.get(key);
        if (cached != null && cached.isFresh(now)) {
            return cached.value();
        }

        synchronized (cache) {
            cached = cache.get(key);
            if (cached != null && cached.isFresh(now)) {
                return cached.value();
            }
            T value = supplier.get();
            cache.put(key, new CacheEntry<>(value, now + ttl.toMillis()));
            return value;
        }
    }

    private String weatherCacheKey(String prefix, double lat, double lng) {
        return prefix + ":" + Math.round(lat * 100.0) + ":" + Math.round(lng * 100.0);
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

    /**
     * 위도·슬롯 시각 기준으로 야간 여부를 반환한다.
     * 태양 적위 공식(Spencer): 일출/일몰 시각을 ±15분 이내 정확도로 계산.
     */
    private boolean isNight(double lat, ZonedDateTime slotTime) {
        int N = slotTime.getDayOfYear();
        // 태양 적위 (라디안)
        double decl = Math.toRadians(
                -23.45 * Math.cos(Math.toRadians(360.0 / 365.0 * (N + 10))));
        double latRad = Math.toRadians(lat);

        double cosH = -Math.tan(latRad) * Math.tan(decl);
        if (cosH >= 1)  return true;   // 극야
        if (cosH <= -1) return false;  // 백야

        double H = Math.toDegrees(Math.acos(cosH)); // 시간각 (도)
        double sunriseHour = 12.0 - H / 15.0;
        double sunsetHour  = 12.0 + H / 15.0;

        double slotHour = slotTime.getHour() + slotTime.getMinute() / 60.0;
        return slotHour < sunriseHour || slotHour >= sunsetHour;
    }

    // ── 내부 데이터 클래스 ────────────────────────────────────

    record WeatherData(int tmp, int pop, int pty) {}
    record AirData(int pm10, int pm25, String pm10Grade, String pm25Grade) {}
    record HourlyForecast(int tmp, int pop, int pty) {}
    record CacheEntry<T>(T value, long expiresAtMillis) {
        boolean isFresh(long nowMillis) {
            return nowMillis < expiresAtMillis;
        }
    }
}
