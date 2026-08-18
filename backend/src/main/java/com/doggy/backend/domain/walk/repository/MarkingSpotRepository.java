package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.MarkingSpot;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface MarkingSpotRepository extends JpaRepository<MarkingSpot, Long> {

    Optional<MarkingSpot> findByGridKey(String gridKey);

    List<MarkingSpot> findAllByGridKeyIn(Collection<String> gridKeys);
}
