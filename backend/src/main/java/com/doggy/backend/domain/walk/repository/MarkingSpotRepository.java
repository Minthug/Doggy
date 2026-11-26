package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.MarkingSpot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface MarkingSpotRepository extends JpaRepository<MarkingSpot, Long> {

    interface RainTarget {
        double getLat();
        double getLng();
    }

    @Query("SELECT DISTINCT s.lat AS lat, s.lng AS lng FROM MarkingSpot s WHERE s.lastVisitedAt >= :since")
    List<RainTarget> findRainTargets(@Param("since") java.time.LocalDateTime since);

    interface PopularSpot {
        Long getId();
        Double getLat();
        Double getLng();
        Long getDogCount();
        java.time.LocalDateTime getLastVisitedAt();
    }

    @Query(value = """
            SELECT s.id AS id, s.lat AS lat, s.lng AS lng,
                   COUNT(DISTINCT v.dog_id) AS "dogCount", MAX(v.visited_at) AS "lastVisitedAt"
            FROM marking_spots s
            JOIN marking_spot_visits v ON v.spot_id = s.id
            WHERE ST_DWithin(
                ST_SetSRID(ST_MakePoint(s.lng, s.lat), 4326)::geography,
                ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                2000
            )
            GROUP BY s.id
            ORDER BY COUNT(DISTINCT v.dog_id) DESC, s.id ASC
            LIMIT 1
            """, nativeQuery = true)
    Optional<PopularSpot> findMostMarkedNear(@Param("lat") double lat, @Param("lng") double lng);

    Optional<MarkingSpot> findByGridKey(String gridKey);

    List<MarkingSpot> findAllByGridKeyIn(Collection<String> gridKeys);
}
