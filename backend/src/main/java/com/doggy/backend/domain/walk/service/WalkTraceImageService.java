package com.doggy.backend.domain.walk.service;

import com.doggy.backend.global.exception.BusinessException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

@Service
@RequiredArgsConstructor
public class WalkTraceImageService {

    private static final int WIDTH = 600;
    private static final int HEIGHT = 360;
    private static final int PADDING = 42;
    private static final int MAX_POINTS = 180;

    private final ObjectMapper objectMapper;

    public String createSvg(String routeGeoJson) {
        List<Point> points = parsePoints(routeGeoJson);
        if (points.size() < 2) {
            throw BusinessException.badRequest("보관할 산책 경로가 없습니다");
        }

        List<Point> sampled = sample(points);
        double minX = sampled.stream().mapToDouble(Point::x).min().orElseThrow();
        double maxX = sampled.stream().mapToDouble(Point::x).max().orElseThrow();
        double minY = sampled.stream().mapToDouble(Point::y).min().orElseThrow();
        double maxY = sampled.stream().mapToDouble(Point::y).max().orElseThrow();
        double rangeX = Math.max(maxX - minX, 0.000001);
        double rangeY = Math.max(maxY - minY, 0.000001);
        double scale = Math.min(
                (WIDTH - PADDING * 2.0) / rangeX,
                (HEIGHT - PADDING * 2.0) / rangeY);
        double contentWidth = rangeX * scale;
        double contentHeight = rangeY * scale;
        double offsetX = (WIDTH - contentWidth) / 2.0;
        double offsetY = (HEIGHT - contentHeight) / 2.0;

        List<Point> normalized = sampled.stream()
                .map(point -> new Point(
                        offsetX + (point.x - minX) * scale,
                        HEIGHT - (offsetY + (point.y - minY) * scale)))
                .toList();

        StringBuilder path = new StringBuilder();
        for (int i = 0; i < normalized.size(); i++) {
            Point point = normalized.get(i);
            path.append(i == 0 ? "M" : " L")
                    .append(format(point.x)).append(' ').append(format(point.y));
        }

        Point start = normalized.get(0);
        Point end = normalized.get(normalized.size() - 1);
        return """
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 360" role="img" aria-label="보관한 산책 흔적길">
                  <defs>
                    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
                      <stop offset="0" stop-color="#FFF8EE"/>
                      <stop offset="1" stop-color="#EEF8F1"/>
                    </linearGradient>
                  </defs>
                  <rect width="600" height="360" rx="30" fill="url(#bg)"/>
                  <path d="M45 92 C140 35 228 73 310 48 S475 45 555 105" fill="none" stroke="#DDEBDD" stroke-width="20" stroke-linecap="round" opacity="0.7"/>
                  <path d="M30 292 C135 245 218 330 330 286 S492 248 570 300" fill="none" stroke="#F2DFC5" stroke-width="24" stroke-linecap="round" opacity="0.65"/>
                  <path d="%s" transform="translate(0 4)" fill="none" stroke="#315B43" stroke-width="15" stroke-linecap="round" stroke-linejoin="round" opacity="0.16"/>
                  <path d="%s" fill="none" stroke="#5F9D75" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>
                  <path d="%s" fill="none" stroke="#DDF1E4" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
                  <circle cx="%s" cy="%s" r="12" fill="#FFFDF8" stroke="#5F9D75" stroke-width="6"/>
                  <circle cx="%s" cy="%s" r="14" fill="#F5A96B" stroke="#FFFDF8" stroke-width="6"/>
                  <g transform="translate(526 282) rotate(-12)" fill="#89B99A" opacity="0.45">
                    <ellipse cx="18" cy="25" rx="15" ry="18"/>
                    <circle cx="4" cy="8" r="7"/><circle cx="17" cy="3" r="7"/><circle cx="30" cy="8" r="7"/>
                  </g>
                </svg>
                """.formatted(
                path, path, path,
                format(start.x), format(start.y),
                format(end.x), format(end.y));
    }

    private List<Point> parsePoints(String geoJson) {
        if (geoJson == null || geoJson.isBlank()) return List.of();
        try {
            JsonNode coordinates = objectMapper.readTree(geoJson).path("coordinates");
            if (!coordinates.isArray()) return List.of();
            List<Point> points = new ArrayList<>();
            for (JsonNode coordinate : coordinates) {
                if (coordinate.isArray() && coordinate.size() >= 2
                        && coordinate.get(0).isNumber() && coordinate.get(1).isNumber()) {
                    points.add(new Point(coordinate.get(0).asDouble(), coordinate.get(1).asDouble()));
                }
            }
            return points;
        } catch (Exception e) {
            throw BusinessException.badRequest("산책 경로 이미지를 만들 수 없습니다");
        }
    }

    private List<Point> sample(List<Point> points) {
        if (points.size() <= MAX_POINTS) return points;
        List<Point> sampled = new ArrayList<>(MAX_POINTS);
        for (int i = 0; i < MAX_POINTS; i++) {
            int index = (int) Math.round(i * (points.size() - 1.0) / (MAX_POINTS - 1.0));
            sampled.add(points.get(index));
        }
        return sampled;
    }

    private String format(double value) {
        return String.format(Locale.ROOT, "%.1f", value);
    }

    private record Point(double x, double y) {}
}
