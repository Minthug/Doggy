package com.doggy.backend.global.weather;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class RainObservationService {
    private final JdbcTemplate jdbc;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(int nx, int ny, LocalDateTime observedAt) {
        jdbc.update("""
                INSERT INTO weather_rain_observations(nx, ny, observed_at) VALUES (?, ?, ?)
                ON CONFLICT(nx, ny) DO UPDATE
                SET observed_at = GREATEST(weather_rain_observations.observed_at, EXCLUDED.observed_at)
                """, nx, ny, observedAt);
    }

    public LocalDateTime lastRain(double lat, double lng) {
        int[] grid = KmaGridConverter.toGrid(lat, lng);
        var observations = jdbc.query("SELECT observed_at FROM weather_rain_observations WHERE nx=? AND ny=?",
                (row, index) -> row.getTimestamp(1).toLocalDateTime(), grid[0], grid[1]);
        return observations.isEmpty() ? null : observations.getFirst();
    }
}
