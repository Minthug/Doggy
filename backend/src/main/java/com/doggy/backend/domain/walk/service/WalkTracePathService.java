package com.doggy.backend.domain.walk.service;

import com.doggy.backend.global.exception.BusinessException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class WalkTracePathService {

    static final int WIDTH = 1000;
    static final int HEIGHT = 600;
    private static final int PADDING = 70;
    private static final int MAX_POINTS = 72;
    private static final String VERSION = "v1|";

    private final ObjectMapper objectMapper;

    /**
     * 실제 위치를 복원할 수 없도록 경로를 상대 좌표로 정규화하고 델타 인코딩한다.
     * 형식: v1|첫X,첫Y;deltaX,deltaY;... (단일 구간)
     *       v2|구간1|구간2... (일시정지로 나뉜 구간)
     */
    public String createPathData(String routeGeoJson) {
        List<List<Point>> segments = parseSegments(routeGeoJson).stream()
                .filter(segment -> segment.size() >= 2)
                .map(this::sample)
                .toList();
        List<Point> points = segments.stream().flatMap(List::stream).toList();
        if (points.size() < 2) {
            throw BusinessException.badRequest("보관할 산책 경로가 없습니다");
        }

        double minX = points.stream().mapToDouble(Point::x).min().orElseThrow();
        double maxX = points.stream().mapToDouble(Point::x).max().orElseThrow();
        double minY = points.stream().mapToDouble(Point::y).min().orElseThrow();
        double maxY = points.stream().mapToDouble(Point::y).max().orElseThrow();
        double rangeX = Math.max(maxX - minX, 0.000001);
        double rangeY = Math.max(maxY - minY, 0.000001);
        double scale = Math.min(
                (WIDTH - PADDING * 2.0) / rangeX,
                (HEIGHT - PADDING * 2.0) / rangeY);
        double offsetX = (WIDTH - rangeX * scale) / 2.0;
        double offsetY = (HEIGHT - rangeY * scale) / 2.0;

        StringBuilder encoded = new StringBuilder(segments.size() == 1 ? VERSION : "v2|");
        for (int segmentIndex = 0; segmentIndex < segments.size(); segmentIndex++) {
            if (segmentIndex > 0) encoded.append('|');
            IntPoint previous = null;
            for (Point point : segments.get(segmentIndex)) {
                IntPoint current = new IntPoint(
                        (int) Math.round(offsetX + (point.x - minX) * scale),
                        (int) Math.round(HEIGHT - (offsetY + (point.y - minY) * scale)));
                if (previous == null) encoded.append(current.x).append(',').append(current.y);
                else encoded.append(';').append(current.x - previous.x).append(',').append(current.y - previous.y);
                previous = current;
            }
        }
        return encoded.toString();
    }

    private List<List<Point>> parseSegments(String geoJson) {
        if (geoJson == null || geoJson.isBlank()) return List.of();
        try {
            JsonNode root = objectMapper.readTree(geoJson);
            JsonNode coordinates = root.path("coordinates");
            if (!coordinates.isArray()) return List.of();
            if ("LineString".equals(root.path("type").asText())) {
                return List.of(readPoints(coordinates));
            }
            if (!"MultiLineString".equals(root.path("type").asText())) return List.of();
            List<List<Point>> segments = new ArrayList<>();
            for (JsonNode coordinate : coordinates) {
                segments.add(readPoints(coordinate));
            }
            return segments;
        } catch (Exception e) {
            throw BusinessException.badRequest("산책 흔적 데이터를 만들 수 없습니다");
        }
    }

    private List<Point> readPoints(JsonNode coordinates) {
        List<Point> points = new ArrayList<>();
        for (JsonNode coordinate : coordinates) {
            if (coordinate.isArray() && coordinate.size() >= 2
                    && coordinate.get(0).isNumber() && coordinate.get(1).isNumber()) {
                points.add(new Point(coordinate.get(0).asDouble(), coordinate.get(1).asDouble()));
            }
        }
        return points;
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

    private record Point(double x, double y) {}

    private record IntPoint(int x, int y) {}
}
