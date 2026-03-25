package com.doggy.backend.global.common;

import org.locationtech.proj4j.*;
import org.springframework.stereotype.Component;

@Component
public class CoordinateConverter {

    private final CoordinateTransform transform;

    public CoordinateConverter() {
        CRSFactory factory = new CRSFactory();

        // EPSG:5174 - 한국 TM 중부 원점 (Bessel 타원체)
        CoordinateReferenceSystem epsg5174 = factory.createFromParameters("EPSG:5174",
                "+proj=tmerc +lat_0=38 +lon_0=127.0028902777778 +k=1 +x_0=200000 +y_0=500000 " +
                "+ellps=bessel +towgs84=-145.907,505.034,685.756,-1.162,2.347,1.592,6.342 +units=m +no_defs");

        // WGS84
        CoordinateReferenceSystem wgs84 = factory.createFromParameters("WGS84",
                "+proj=longlat +datum=WGS84 +no_defs");

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
