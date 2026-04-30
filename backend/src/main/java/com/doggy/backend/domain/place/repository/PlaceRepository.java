package com.doggy.backend.domain.place.repository;

import com.doggy.backend.domain.place.entity.Place;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface PlaceRepository extends JpaRepository<Place, Long> {

    @Query(value = """
            SELECT * FROM places
            WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :radiusMeters)
            ORDER BY ST_Distance(location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)
            LIMIT 100
            """, nativeQuery = true)
    List<Place> findNearby(@Param("lat") double lat,
                           @Param("lng") double lng,
                           @Param("radiusMeters") double radiusMeters);

    @Query(value = """
            SELECT * FROM places
            WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :radiusMeters)
            AND category = :category
            ORDER BY ST_Distance(location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)
            LIMIT 100
            """, nativeQuery = true)
    List<Place> findNearbyByCategory(@Param("lat") double lat,
                                     @Param("lng") double lng,
                                     @Param("radiusMeters") double radiusMeters,
                                     @Param("category") String category);
}
