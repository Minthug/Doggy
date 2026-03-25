package com.doggy.backend.global.common;

import org.locationtech.proj4j.*;
import org.springframework.stereotype.Component;

@Component
public class CoordinateConverter {

    private final CoordinateTransform transform;

    public CoordinateConverter() {
        CRSFactory factory = new CRSFactory();
        CoordinateReferenceSystem epsg5174 = factory.createFromName("EPSG:5174");
        CoordinateReferenceSystem wgs84 = factory.createFromName("EPSG:4326");
        this.transform = new BasicCoordinateTransform(epsg5174, wgs84);
    }

    /**
     * EPSG:5174 (TM중부) → WGS84 변환
     * @return double[] { lat, lng }
     */
    public double[] toWgs84(double tmX, double tmY) {
        ProjCoordinate src = new ProjCoordinate(tmX, tmY);
        ProjCoordinate dst = new ProjCoordinate();
        transform.transform(src, dst);
        return new double[]{ dst.y, dst.x }; // lat, lng
    }
}
