package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.MarkingSpotVisit;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MarkingSpotVisitRepository extends JpaRepository<MarkingSpotVisit, Long> {

    boolean existsBySpotIdAndSessionIdAndDogId(Long spotId, Long sessionId, Long dogId);

    @EntityGraph(attributePaths = {"dog"})
    List<MarkingSpotVisit> findAllBySpotIdOrderByCreatedAtDesc(Long spotId, Pageable pageable);

    @EntityGraph(attributePaths = {"spot"})
    List<MarkingSpotVisit> findAllBySessionIdOrderByCreatedAtDesc(Long sessionId);
}
