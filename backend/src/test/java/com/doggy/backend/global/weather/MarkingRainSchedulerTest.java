package com.doggy.backend.global.weather;

import com.doggy.backend.domain.walk.repository.MarkingSpotRepository;
import org.junit.jupiter.api.Test;
import java.time.LocalDateTime;
import java.util.List;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class MarkingRainSchedulerTest {
    private MarkingSpotRepository.RainTarget target(double lat, double lng) {
        var target = mock(MarkingSpotRepository.RainTarget.class);
        when(target.getLat()).thenReturn(lat);
        when(target.getLng()).thenReturn(lng);
        return target;
    }

    @Test
    void groupsNearbySpotsAndDoesNotRefetchSuccessfulObservation() {
        var spots = mock(MarkingSpotRepository.class);
        var weather = mock(WeatherService.class);
        var targets = List.of(target(37.2214,126.9456), target(37.2215,126.9457));
        when(spots.findRainTargets(any())).thenReturn(targets);
        when(weather.observeRain(anyInt(),anyInt(),any())).thenReturn(true);
        var scheduler = new MarkingRainScheduler(spots, weather);
        var now = LocalDateTime.of(2026,11,26,12,45);
        scheduler.refreshAt(now);
        scheduler.refreshAt(now.plusMinutes(5));
        verify(weather,times(2)).observeRain(anyInt(),anyInt(),any());
        scheduler.refreshAt(now.plusHours(1));
        verify(weather,times(3)).observeRain(anyInt(),anyInt(),any());
    }

    @Test
    void retriesFailuresAndContinuesWithOtherRegions() {
        var spots = mock(MarkingSpotRepository.class);
        var weather = mock(WeatherService.class);
        var targets = List.of(target(37.22,126.94), target(35.18,129.07));
        when(spots.findRainTargets(any())).thenReturn(targets);
        when(weather.observeRain(anyInt(),anyInt(),any())).thenReturn(false);
        var scheduler = new MarkingRainScheduler(spots, weather);
        var now = LocalDateTime.of(2026,11,26,12,45);
        scheduler.refreshAt(now);
        scheduler.refreshAt(now.plusMinutes(5));
        verify(weather,times(4)).observeRain(anyInt(),anyInt(),any());
    }
}
