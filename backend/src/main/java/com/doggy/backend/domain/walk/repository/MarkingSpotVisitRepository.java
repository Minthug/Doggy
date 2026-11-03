package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.MarkingSpotVisit;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface MarkingSpotVisitRepository extends JpaRepository<MarkingSpotVisit, Long> {

    boolean existsBySpotIdAndSessionIdAndDogId(Long spotId, Long sessionId, Long dogId);

    @Query("SELECT COUNT(DISTINCT v.spot.id) FROM MarkingSpotVisit v WHERE v.session.id = :sessionId")
    long countDistinctSpotsBySessionId(@Param("sessionId") Long sessionId);

    @Query("SELECT CASE WHEN COUNT(v) > 0 THEN true ELSE false END FROM MarkingSpotVisit v "
            + "WHERE v.session.id = :sessionId AND v.spot.gridKey = :gridKey")
    boolean existsBySessionIdAndSpotGridKey(@Param("sessionId") Long sessionId, @Param("gridKey") String gridKey);

    @EntityGraph(attributePaths = {"dog"})
    List<MarkingSpotVisit> findAllBySpotIdOrderByCreatedAtDesc(Long spotId, Pageable pageable);

    @EntityGraph(attributePaths = {"spot"})
    List<MarkingSpotVisit> findAllBySessionIdOrderByCreatedAtDesc(Long sessionId);
}
