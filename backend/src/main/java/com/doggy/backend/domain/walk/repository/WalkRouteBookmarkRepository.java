package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.WalkRouteBookmark;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface WalkRouteBookmarkRepository extends JpaRepository<WalkRouteBookmark, Long> {
    Optional<WalkRouteBookmark> findBySessionIdAndUserId(Long sessionId, Long userId);
    boolean existsBySessionIdAndUserId(Long sessionId, Long userId);
}
