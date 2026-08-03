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

            List<Coordinate> original = readCoordinates(coordinates);
            List<Coordinate> trimmed = trimPrivateEdges(original);
            if (trimmed.size() < 2) {
                return null;
            }

            List<Coordinate> simplified = limitPoints(trimmed);
            ObjectNode masked = OBJECT_MAPPER.createObjectNode();
            masked.put("type", "LineString");
            ArrayNode maskedCoordinates = masked.putArray("coordinates");
            for (Coordinate coordinate : simplified) {
                ArrayNode point = OBJECT_MAPPER.createArrayNode();
                point.add(roundCoordinate(coordinate.lng()));
                point.add(roundCoordinate(coordinate.lat()));
                maskedCoordinates.add(point);
            }
            return OBJECT_MAPPER.writeValueAsString(masked);
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
        if (coordinates.size() < 3) {
            return List.of();
        }

        int startIndex = trimStartIndex(coordinates);
        int endIndex = trimEndIndex(coordinates);
        if (endIndex <= startIndex) {
            return List.of();
        }

        return coordinates.subList(startIndex, endIndex + 1);
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
}
