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
import java.util.List;
import java.util.Map;

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

    // 기본 좌표 (경기 봉담)
    private static final double DEFAULT_LAT = 37.218392;
    private static final double DEFAULT_LNG = 126.944858;

    @Value("${weather.api.key}")
    private String apiKey;

    @Value("${air.station.api.key}")
    private String airStationApiKey;

    private final RestTemplate restTemplate = new RestTemplateBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .readTimeout(Duration.ofSeconds(10))
            .build();

    public WalkIndexResponse getWalkIndex() {
        return getWalkIndex(DEFAULT_LAT, DEFAULT_LNG);
    }

    public WalkIndexResponse getWalkIndex(double lat, double lng, String sido) {
        return getWalkIndex(lat, lng);
    }

    public WalkIndexResponse getWalkIndex(double lat, double lng) {
        WeatherData weather = fetchWeather(lat, lng);
        AirData air = fetchAirQuality(lat, lng);

        WalkIndex index = calculateIndex(weather, air);
        return WalkIndexResponse.of(index, weather.tmp, weather.pop, weather.pty, air.pm10, air.pm25, air.pm10Grade(), air.pm25Grade());
    }

    // ── 산책 지수 계산 ──────────────────────────────────────────

    private WalkIndex calculateIndex(WeatherData w, AirData a) {
        // 자제 조건: 하나라도 해당하면 AVOID
        if (w.tmp < 0 || w.tmp > 32) return WalkIndex.AVOID;
        if (w.pty != 0) return WalkIndex.AVOID;           // 비/눈/소나기
        if (w.pop >= 60) return WalkIndex.AVOID;
        if ("매우나쁨".equals(a.pm10Grade()) || "매우나쁨".equals(a.pm25Grade())) return WalkIndex.AVOID;

        // 주의 조건
        if (w.tmp < 5 || w.tmp > 27) return WalkIndex.CAUTION;
        if (w.pop >= 30) return WalkIndex.CAUTION;
        if ("나쁨".equals(a.pm10Grade()) || "나쁨".equals(a.pm25Grade())) return WalkIndex.CAUTION;

        // 좋음: 기온 5~27도, 강수확률 30% 미만, 미세먼지 보통 이하
        return WalkIndex.GOOD;
    }

    // ── 기상청 날씨 (기온: 초단기실황, 강수확률: 단기예보) ──────────────

    private WeatherData fetchWeather(double lat, double lng) {
        int[] grid = KmaGridConverter.toGrid(lat, lng);
        int tmp = fetchObservedTemperature(grid);
        int[] popPty = fetchPrecipitation(grid);
        return new WeatherData(tmp, popPty[0], popPty[1]);
    }

    /** 초단기실황 → 기온(T1H), 강수형태(PTY) */
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

    /** 단기예보 → 강수확률(POP), 강수형태(PTY) */
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
                } catch (NumberFormatException ignored) {
                    // "강수없음" 등 비숫자 값은 0 유지
                }
            }
            log.info("단기예보 ({}{}) - 강수확률:{}%, 강수형태:{}", targetDate, targetTime, pop, pty);
            return new int[]{pop, pty};

        } catch (Exception e) {
            log.warn("단기예보 API 호출 실패: {}", e.getMessage());
            return new int[]{0, 0};
        }
    }

    // ── 에어코리아 미세먼지 ───────────────────────────────────────

    private AirData fetchAirQuality(double lat, double lng) {
        try {
            String stationName = fetchNearestStation(lat, lng);
            if (stationName == null) {
                log.warn("근처 측정소를 찾지 못했습니다. 기본값 사용");
                return new AirData(30, 10, "보통", "보통");
            }
            String encodedStation = URLEncoder.encode(stationName, StandardCharsets.UTF_8);
            String url = AIR_STATION_URL + "?serviceKey=" + apiKey
                    + "&returnType=json&numOfRows=1&pageNo=1"
                    + "&stationName=" + encodedStation
                    + "&dataTerm=HOUR&ver=1.0";

            Map<String, Object> response = restTemplate.getForObject(new java.net.URI(url), Map.class);
            return parseAir(stationName, response);

        } catch (Exception e) {
            log.warn("에어코리아 API 호출 실패 [{}]: {}", e.getClass().getSimpleName(), e.getMessage());
            return new AirData(30, 10, "보통", "보통");
        }
    }

    // 주요 도시 대표 측정소 (API 403 시 fallback)
    private static final double[][] STATION_COORDS = {
            {37.5665, 126.9780}, {37.5172, 127.0473}, {37.5491, 126.9168}, // 서울 중구/강남/마포
            {37.2636, 127.0286}, {37.4196, 127.1267}, {37.6584, 126.8320}, // 수원/성남/고양
            {37.4563, 126.7052}, {35.1796, 129.0756}, {35.8714, 128.6014}, // 인천/부산/대구
            {35.1595, 126.8526}, {36.3504, 127.3845}, {35.5384, 129.3114}, // 광주/대전/울산
            {36.4800, 127.2890}, {33.4996, 126.5312}                        // 세종/제주
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
            Map<String, Object> res = (Map<String, Object>) response.get("response");
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
            Map<String, Object> res = (Map<String, Object>) response.get("response");
            Map<String, Object> body = (Map<String, Object>) res.get("body");
            List<Map<String, Object>> items = (List<Map<String, Object>>) body.get("items");

            if (items == null || items.isEmpty()) return new AirData(30, 10, "보통", "보통");

            Map<String, Object> item = items.get(0);
            int pm10 = parseAirValue(item.get("pm10Value"));
            int pm25 = parseAirValue(item.get("pm25Value"));
            String pm10Grade = gradeByValue(pm10, "pm10");
            String pm25Grade = gradeByValue(pm25, "pm25");

            log.info("미세먼지 ({}) - PM10:{}({}), PM2.5:{}({})", stationName, pm10, pm10Grade, pm25, pm25Grade);
            return new AirData(pm10, pm25, pm10Grade, pm25Grade);

        } catch (Exception e) {
            log.warn("미세먼지 데이터 파싱 실패: {}", e.getMessage());
            return new AirData(30, 10, "보통", "보통");
        }
    }

    /** WGS84 위경도 → 에어코리아 TM 좌표 변환 (GRS80, 중부원점 127°E) */
    private double[] toTm(double lat, double lng) {
        double a = 6378137.0;
        double f = 1.0 / 298.257222101;
        double k0 = 1.0;
        double lon0 = Math.toRadians(127.0);
        double lat0 = Math.toRadians(38.0);
        double E0 = 200000.0;
        double N0 = 500000.0;

        double e2 = 2 * f - f * f;
        double ep2 = e2 / (1 - e2);

        double latR = Math.toRadians(lat);
        double lonR = Math.toRadians(lng);

        double N = a / Math.sqrt(1 - e2 * Math.sin(latR) * Math.sin(latR));
        double T = Math.tan(latR) * Math.tan(latR);
        double C = ep2 * Math.cos(latR) * Math.cos(latR);
        double A = Math.cos(latR) * (lonR - lon0);

        double e4 = e2 * e2, e6 = e4 * e2;
        double M = a * (
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
        double x = E0 + k0 * N * (A + (1 - T + C) * A3 / 6
                + (5 - 18 * T + T * T + 72 * C - 58 * ep2) * A5 / 120);
        double y = N0 + k0 * (M - M0 + N * Math.tan(latR) * (A2 / 2
                + (5 - T + 9 * C + 4 * C * C) * A4 / 24
                + (61 - 58 * T + T * T + 600 * C - 330 * ep2) * A6 / 720));

        return new double[]{x, y};
    }

    /** pm10/pm25 수치로 등급 직접 계산 (에어코리아 기준) */
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

    private int parseGradeNum(Object grade) {
        if (grade == null) return 1;
        try { return Integer.parseInt(grade.toString()); }
        catch (NumberFormatException e) { return 1; }
    }

    // 에어코리아 grade: 1=좋음, 2=보통, 3=나쁨, 4=매우나쁨
    private String gradeLabel(int grade) {
        return switch (grade) {
            case 1 -> "좋음";
            case 2 -> "보통";
            case 3 -> "나쁨";
            case 4 -> "매우나쁨";
            default -> "보통";
        };
    }

    // ── 시간 헬퍼 ─────────────────────────────────────────────

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");

    /**
     * 기상청 단기예보 base_date.
     * 새벽 02:10 이전은 전날 2300 발표분을 사용해야 하므로 전날 날짜 반환.
     */
    private String getBaseDate() {
        ZonedDateTime now = ZonedDateTime.now(KST);
        if (now.toLocalTime().isBefore(LocalTime.of(2, 10))) {
            return now.minusDays(1).toLocalDate().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
        }
        return now.toLocalDate().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
    }

    /**
     * 초단기실황 base_time.
     * 매시 10분 이후 갱신되므로, 10분 미만이면 이전 시간 사용.
     */
    private String getObsBaseTime() {
        ZonedDateTime now = ZonedDateTime.now(KST);
        int hour = now.getHour();
        if (now.getMinute() < 10) {
            hour = (hour - 1 + 24) % 24;
        }
        return String.format("%02d00", hour);
    }

    /**
     * 기상청 단기예보 base_time.
     * KMA 발표 주기: 0200, 0500, 0800, 1100, 1400, 1700, 2000, 2300 (발표 후 약 10분 뒤 조회 가능)
     */
    private String getBaseTime() {
        LocalTime now = ZonedDateTime.now(KST).toLocalTime();
        if (now.isBefore(LocalTime.of(2, 10)))  return "2300"; // 전날 2300 발표분
        if (now.isBefore(LocalTime.of(5, 10)))  return "0200";
        if (now.isBefore(LocalTime.of(8, 10)))  return "0500";
        if (now.isBefore(LocalTime.of(11, 10))) return "0800";
        if (now.isBefore(LocalTime.of(14, 10))) return "1100";
        if (now.isBefore(LocalTime.of(17, 10))) return "1400";
        if (now.isBefore(LocalTime.of(20, 10))) return "1700";
        return "2000";
    }

    /** 조회 대상 예보 날짜 (항상 오늘) */
    private String getTargetFcstDate() {
        return ZonedDateTime.now(KST).toLocalDate().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
    }

    /**
     * 조회 대상 예보 시각 (3시간 단위, POP 제공 주기에 맞춤).
     * 앱을 켠 현재 시각이 속하는 3시간 블록 반환 (미래가 아닌 지금 날씨).
     */
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
}
