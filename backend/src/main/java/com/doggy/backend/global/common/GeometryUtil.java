package com.doggy.backend.global.common;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;

public class GeometryUtil {

    private static final GeometryFactory FACTORY = new GeometryFactory(new PrecisionModel(), 4326);

    private GeometryUtil() {}

    public static Point toPoint(double lat, double lng) {
        return FACTORY.createPoint(new Coordinate(lng, lat)); // JTS는 (x=lng, y=lat) 순서
    }
}
