package com.doggy.backend.global.weather;

import com.doggy.backend.domain.walk.repository.MarkingSpotRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.HashSet;
import java.util.HashMap;
import java.util.Map;

@Component
@Slf4j
@RequiredArgsConstructor
@ConditionalOnProperty(name = "weather.marking-rain.enabled", havingValue = "true", matchIfMissing = true)
public class MarkingRainScheduler {
    private record Grid(int nx, int ny) {}
    private final MarkingSpotRepository spots;
    private final WeatherService weather;
    private final Map<Grid, LocalDateTime> checked = new HashMap<>();

    @Scheduled(cron = "0 15,45 * * * *", zone = "Asia/Seoul")
    public void refresh() {
        refreshAt(LocalDateTime.now(ZoneId.of("Asia/Seoul")));
    }

    synchronized void refreshAt(LocalDateTime now) {
        var grids = new HashSet<Grid>();
        for (var spot : spots.findRainTargets(now.minusDays(3))) {
            int[] grid = KmaGridConverter.toGrid(spot.getLat(), spot.getLng());
            grids.add(new Grid(grid[0], grid[1]));
        }
        checked.keySet().retainAll(grids);
        var latest = now.minusMinutes(40).truncatedTo(ChronoUnit.HOURS);
        for (var grid : grids) {
            // Overlap two observation hours to retry delayed publications and short outages.
            for (var time = latest.minusHours(1); !time.isAfter(latest); time = time.plusHours(1)) {
                var lastChecked = checked.get(grid);
                if (lastChecked != null && !time.isAfter(lastChecked)) continue;
                try {
                    if (!weather.observeRain(grid.nx(), grid.ny(), time)) break;
                    checked.put(grid, time);
                } catch (Exception exception) {
                    log.warn("마킹 지역 강수 갱신 실패 nx={} ny={}", grid.nx(), grid.ny());
                    break;
                }
            }
        }
    }
}
