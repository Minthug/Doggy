package com.doggy.backend.global.common;

import com.doggy.backend.global.exception.BusinessException;

public final class RequestLimits {

    public static final int MAX_PAGE_SIZE = 100;
    public static final int MAX_PAGE = 10_000;
    public static final int MAX_WALK_POINTS = 5_000;
    public static final double DEFAULT_RADIUS_METERS = 1_000.0;
    public static final double MIN_RADIUS_METERS = 100.0;
    public static final double MAX_RADIUS_METERS = 10_000.0;

    private RequestLimits() {}

    public static int clampPage(int page) {
        return Math.min(Math.max(page, 0), MAX_PAGE);
    }

    public static int clampPageSize(int size) {
        return Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
    }

    public static double clampRadiusMeters(Double radiusMeters) {
        if (radiusMeters == null) {
            return DEFAULT_RADIUS_METERS;
        }
        if (!Double.isFinite(radiusMeters)) {
            throw BusinessException.badRequest("올바른 반경 값이 아닙니다");
        }
        return Math.min(Math.max(radiusMeters, MIN_RADIUS_METERS), MAX_RADIUS_METERS);
    }

    public static void validateLatLng(Double lat, Double lng) {
        if (lat == null || lng == null
                || !Double.isFinite(lat) || !Double.isFinite(lng)
                || lat < -90.0 || lat > 90.0
                || lng < -180.0 || lng > 180.0) {
            throw BusinessException.badRequest("올바른 좌표 범위가 아닙니다");
        }
    }
}
