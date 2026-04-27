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
            return weatherService.getWalkIndex(lat, lng);
        }
        return weatherService.getWalkIndex();
    }

    @GetMapping("/walk-forecast")
    public WalkForecastResponse getWalkForecast(
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng) {
        if (lat != null && lng != null) {
            return weatherService.getWalkForecast(lat, lng);
        }
        return weatherService.getWalkForecast();
    }
}
