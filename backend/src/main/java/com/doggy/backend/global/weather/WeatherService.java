package com.doggy.backend.global.weather;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class WeatherService {

    private static final String FORECAST_URL =
            "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst";
    private static final String AIR_URL =
            "https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getCtprvnRltmMesureDnsty";

    // 기본 좌표: 서울
    private static final double DEFAULT_LAT = 37.5665;
    private static final double DEFAULT_LNG = 126.9780;
    private static final String DEFAULT_SIDO = "서울";

    @Value("${weather.api.key}")
    private String apiKey;

    private final RestTemplate restTemplate = new RestTemplateBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .readTimeout(Duration.ofSeconds(10))
            .build();

    public WalkIndexResponse getWalkIndex() {
        return getWalkIndex(DEFAULT_LAT, DEFAULT_LNG, DEFAULT_SIDO);
    }

    public WalkIndexResponse getWalkIndex(double lat, double lng, String sido) {
        WeatherData weather = fetchWeather(lat, lng);
        AirData air = fetchAirQuality(sido);

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

    // ── 기상청 단기예보 ──────────────────────────────────────────

    private WeatherData fetchWeather(double lat, double lng) {
        try {
            int[] grid = KmaGridConverter.toGrid(lat, lng);
            String baseDate = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
            String baseTime = getBaseTime();

            String url = UriComponentsBuilder.fromHttpUrl(FORECAST_URL)
                    .queryParam("serviceKey", apiKey)
                    .queryParam("pageNo", 1)
                    .queryParam("numOfRows", 100)
                    .queryParam("dataType", "JSON")
                    .queryParam("base_date", baseDate)
                    .queryParam("base_time", baseTime)
                    .queryParam("nx", grid[0])
                    .queryParam("ny", grid[1])
                    .build(true)
                    .toUriString();

            Map<String, Object> response = restTemplate.getForObject(url, Map.class);
            return parseWeather(response);

        } catch (Exception e) {
            log.warn("기상청 API 호출 실패: {}", e.getMessage());
            return new WeatherData(20, 0, 0); // 실패 시 무해한 기본값
        }
    }

    @SuppressWarnings("unchecked")
    private WeatherData parseWeather(Map<String, Object> response) {
        try {
            Map<String, Object> body = (Map<String, Object>)
                    ((Map<String, Object>) response.get("response")).get("body");
            List<Map<String, Object>> items = (List<Map<String, Object>>)
                    ((Map<String, Object>) body.get("items")).get("item");

            String targetTime = getTargetFcstTime();
            int tmp = 20, pop = 0, pty = 0;

            for (Map<String, Object> item : items) {
                if (!targetTime.equals(item.get("fcstTime"))) continue;
                String category = (String) item.get("category");
                if (!category.equals("TMP") && !category.equals("POP") && !category.equals("PTY")) continue;
                int value = (int) Math.round(Double.parseDouble(item.get("fcstValue").toString()));
                switch (category) {
                    case "TMP" -> tmp = value;
                    case "POP" -> pop = value;
                    case "PTY" -> pty = value;
                }
            }
            log.info("날씨 예보 - 기온:{}도, 강수확률:{}%, 강수형태:{}", tmp, pop, pty);
            return new WeatherData(tmp, pop, pty);

        } catch (Exception e) {
            log.warn("날씨 데이터 파싱 실패: {}", e.getMessage());
            return new WeatherData(20, 0, 0);
        }
    }

    // ── 에어코리아 미세먼지 ───────────────────────────────────────

    private AirData fetchAirQuality(String sido) {
        try {
            String encodedSido = URLEncoder.encode(sido, StandardCharsets.UTF_8);
            String url = AIR_URL + "?serviceKey=" + apiKey
                    + "&returnType=json&numOfRows=20&pageNo=1&sidoName=" + encodedSido + "&ver=1.0";

            Map<String, Object> response = restTemplate.getForObject(new java.net.URI(url), Map.class);
            return parseAir(response);

        } catch (Exception e) {
            log.warn("에어코리아 API 호출 실패 [{}]: {}", e.getClass().getSimpleName(), e.getMessage());
            return new AirData(30, 10, "보통", "보통");
        }
    }

    @SuppressWarnings("unchecked")
    private AirData parseAir(Map<String, Object> response) {
        try {
            Map<String, Object> res = (Map<String, Object>) response.get("response");
            Map<String, Object> body = (Map<String, Object>) res.get("body");
            List<Map<String, Object>> items = (List<Map<String, Object>>) body.get("items");

            if (items == null || items.isEmpty()) return new AirData(30, 10, "보통", "보통");

            // 여러 측정소 평균값 사용
            int pm10Sum = 0, pm25Sum = 0, count = 0;
            int worstPm10Grade = 1, worstPm25Grade = 1;
            for (Map<String, Object> item : items) {
                int pm10v = parseAirValue(item.get("pm10Value"));
                int pm25v = parseAirValue(item.get("pm25Value"));
                if (pm10v > 0 && pm25v > 0) {
                    pm10Sum += pm10v;
                    pm25Sum += pm25v;
                    count++;
                    worstPm10Grade = Math.max(worstPm10Grade, parseGradeNum(item.get("pm10Grade")));
                    worstPm25Grade = Math.max(worstPm25Grade, parseGradeNum(item.get("pm25Grade")));
                }
            }
            if (count == 0) return new AirData(30, 10, "보통", "보통");

            int pm10 = pm10Sum / count;
            int pm25 = pm25Sum / count;
            String pm10Grade = gradeLabel(worstPm10Grade);
            String pm25Grade = gradeLabel(worstPm25Grade);

            log.info("미세먼지 ({} 측정소 평균) - PM10:{}({}), PM2.5:{}({})", count, pm10, pm10Grade, pm25, pm25Grade);
            return new AirData(pm10, pm25, pm10Grade, pm25Grade);

        } catch (Exception e) {
            log.warn("미세먼지 데이터 파싱 실패: {}", e.getMessage());
            return new AirData(30, 10, "보통", "보통");
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
    private String gradeLabel(Object grade) {
        return gradeLabel(parseGradeNum(grade));
    }

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

    private String getBaseTime() {
        LocalTime now = LocalTime.now();
        if (now.isBefore(LocalTime.of(8, 0))) return "0500";
        if (now.isBefore(LocalTime.of(11, 0))) return "0800";
        if (now.isBefore(LocalTime.of(14, 0))) return "1100";
        return "1400";
    }

    private String getTargetFcstTime() {
        LocalTime now = LocalTime.now();
        if (now.isBefore(LocalTime.of(9, 0))) return "0900";
        if (now.isBefore(LocalTime.of(12, 0))) return "1200";
        if (now.isBefore(LocalTime.of(15, 0))) return "1500";
        return "1800";
    }

    // ── 내부 데이터 클래스 ────────────────────────────────────

    record WeatherData(int tmp, int pop, int pty) {}
    record AirData(int pm10, int pm25, String pm10Grade, String pm25Grade) {}
}
