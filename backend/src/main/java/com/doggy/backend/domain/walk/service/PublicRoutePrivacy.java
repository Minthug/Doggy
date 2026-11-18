package com.doggy.backend.domain.walk.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

import java.util.ArrayList;
import java.util.List;

final class PublicRoutePrivacy {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final double PRIVATE_EDGE_METERS = 200.0;
    private static final double ROUNDING_MARGIN_METERS = 80.0;
    private static final double COORDINATE_SCALE = 1_000.0;
    private static final int MAX_PUBLIC_POINTS = 200;

    private PublicRoutePrivacy() {
    }

    static String minimizeGeoJson(String routeGeoJson) {
        if (routeGeoJson == null || routeGeoJson.isBlank()) {
            return null;
        }

        try {
            JsonNode root = OBJECT_MAPPER.readTree(routeGeoJson);
            JsonNode coordinates = root.get("coordinates");
            if (coordinates == null || !coordinates.isArray()) {
                return null;
            }
            boolean multiple = "MultiLineString".equals(root.path("type").asText());
            if (!multiple && !"LineString".equals(root.path("type").asText())) return null;
            List<List<Coordinate>> visible = new ArrayList<>();
            if (multiple) {
                for (JsonNode segment : coordinates) {
                    List<Coordinate> trimmed = trimPrivateEdges(readCoordinates(segment));
                    if (trimmed.size() >= 2) visible.add(limitPoints(trimmed));
                }
            } else {
                List<Coordinate> trimmed = trimPrivateEdges(readCoordinates(coordinates));
                if (trimmed.size() >= 2) visible.add(limitPoints(trimmed));
            }
            if (visible.isEmpty()) return null;
            ObjectNode masked = OBJECT_MAPPER.createObjectNode();
            masked.put("type", multiple ? "MultiLineString" : "LineString");
            ArrayNode maskedCoordinates = masked.putArray("coordinates");
            for (List<Coordinate> segment : visible) {
                ArrayNode target = multiple ? maskedCoordinates.addArray() : maskedCoordinates;
                for (Coordinate coordinate : segment) {
                    ArrayNode point = target.addArray();
                    point.add(roundCoordinate(coordinate.lng()));
                    point.add(roundCoordinate(coordinate.lat()));
                }
            }
            return OBJECT_MAPPER.writeValueAsString(masked);
        } catch (Exception ignored) {
            return null;
        }
    }

    static SearchPoint searchPoint(String routeGeoJson) {
        String publicRoute = minimizeGeoJson(routeGeoJson);
        if (publicRoute == null) return null;
        try {
            JsonNode root = OBJECT_MAPPER.readTree(publicRoute);
            JsonNode coordinates = root.get("coordinates");
            JsonNode first = "MultiLineString".equals(root.path("type").asText())
                    ? coordinates.get(0).get(0) : coordinates.get(0);
            return new SearchPoint(first.get(1).asDouble(), first.get(0).asDouble());
        } catch (Exception ignored) {
            return null;
        }
    }

    private static List<Coordinate> readCoordinates(JsonNode coordinates) {
        List<Coordinate> result = new ArrayList<>();
        for (JsonNode coordinate : coordinates) {
            if (!coordinate.isArray() || coordinate.size() < 2) {
                continue;
            }
            JsonNode lng = coordinate.get(0);
            JsonNode lat = coordinate.get(1);
            if (lng.isNumber() && lat.isNumber()) {
                result.add(new Coordinate(lat.asDouble(), lng.asDouble()));
            }
        }
        return result;
    }

    private static List<Coordinate> trimPrivateEdges(List<Coordinate> coordinates) {
        if (coordinates.size() < 2) {
            return List.of();
        }
        if (coordinates.size() == 2) {
            Coordinate start = coordinates.getFirst();
            Coordinate end = coordinates.getLast();
            double distance = distanceMeters(start, end);
            double privateEdge = PRIVATE_EDGE_METERS + ROUNDING_MARGIN_METERS;
            if (distance <= 2 * privateEdge) return List.of();
            double fraction = privateEdge / distance;
            return List.of(interpolate(start, end, fraction), interpolate(end, start, fraction));
        }

        int startIndex = trimStartIndex(coordinates);
        int endIndex = trimEndIndex(coordinates);
        if (endIndex <= startIndex) {
            return List.of();
        }

        return coordinates.subList(startIndex, endIndex + 1);
    }

    private static Coordinate interpolate(Coordinate from, Coordinate to, double fraction) {
        return new Coordinate(from.lat() + (to.lat() - from.lat()) * fraction,
                from.lng() + (to.lng() - from.lng()) * fraction);
    }

    private static int trimStartIndex(List<Coordinate> coordinates) {
        double distance = 0.0;
        for (int i = 1; i < coordinates.size(); i++) {
            distance += distanceMeters(coordinates.get(i - 1), coordinates.get(i));
            if (distance >= PRIVATE_EDGE_METERS) {
                return i;
            }
        }
        return coordinates.size();
    }

    private static int trimEndIndex(List<Coordinate> coordinates) {
        double distance = 0.0;
        for (int i = coordinates.size() - 2; i >= 0; i--) {
            distance += distanceMeters(coordinates.get(i + 1), coordinates.get(i));
            if (distance >= PRIVATE_EDGE_METERS) {
                return i;
            }
        }
        return -1;
    }

    private static List<Coordinate> limitPoints(List<Coordinate> coordinates) {
        if (coordinates.size() <= MAX_PUBLIC_POINTS) {
            return coordinates;
        }

        int step = (int) Math.ceil((double) coordinates.size() / MAX_PUBLIC_POINTS);
        List<Coordinate> result = new ArrayList<>();
        for (int i = 0; i < coordinates.size(); i += step) {
            result.add(coordinates.get(i));
        }
        Coordinate last = coordinates.get(coordinates.size() - 1);
        if (!result.get(result.size() - 1).equals(last)) {
            result.add(last);
        }
        return result;
    }

    private static double roundCoordinate(double coordinate) {
        return Math.round(coordinate * COORDINATE_SCALE) / COORDINATE_SCALE;
    }

    private static double distanceMeters(Coordinate a, Coordinate b) {
        final int earthRadiusMeters = 6_371_000;
        double dLat = Math.toRadians(b.lat() - a.lat());
        double dLng = Math.toRadians(b.lng() - a.lng());
        double haversine = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(a.lat())) * Math.cos(Math.toRadians(b.lat()))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return earthRadiusMeters * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
    }

    private record Coordinate(double lat, double lng) {
    }

    record SearchPoint(double lat, double lng) {
    }
}
