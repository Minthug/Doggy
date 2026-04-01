package com.doggy.backend.global.weather;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/weather")
@RequiredArgsConstructor
public class WeatherController {

    private final WeatherService weatherService;

    @GetMapping("/walk-index")
    public WalkIndexResponse getWalkIndex(
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng) {
        if (lat != null && lng != null) {
            return weatherService.getWalkIndex(lat, lng, resolveSido(lat, lng));
        }
        return weatherService.getWalkIndex();
    }

    // 위도/경도로 시도명 추정 (기상청 에어코리아 API용)
    private String resolveSido(double lat, double lng) {
        if (lat >= 37.4 && lat <= 37.7 && lng >= 126.7 && lng <= 127.2) return "서울";
        if (lat >= 37.3 && lat <= 37.6 && lng >= 126.6 && lng <= 127.0) return "경기";
        if (lat >= 35.0 && lat <= 35.3 && lng >= 128.9 && lng <= 129.3) return "부산";
        if (lat >= 35.8 && lat <= 36.1 && lng >= 128.4 && lng <= 128.8) return "대구";
        if (lat >= 37.4 && lat <= 37.6 && lng >= 126.5 && lng <= 126.8) return "인천";
        if (lat >= 35.1 && lat <= 35.3 && lng >= 126.7 && lng <= 127.0) return "광주";
        if (lat >= 36.3 && lat <= 36.5 && lng >= 127.3 && lng <= 127.6) return "대전";
        if (lat >= 35.5 && lat <= 35.6 && lng >= 129.2 && lng <= 129.4) return "울산";
        if (lat >= 36.4 && lat <= 36.6 && lng >= 127.2 && lng <= 127.6) return "세종";
        if (lat >= 33.0 && lat <= 33.6 && lng >= 126.1 && lng <= 126.9) return "제주";
        return "서울"; // 매칭 안 되면 서울 기본값
    }
}
