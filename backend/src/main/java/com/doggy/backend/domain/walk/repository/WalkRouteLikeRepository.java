package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.WalkRouteLike;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface WalkRouteLikeRepository extends JpaRepository<WalkRouteLike, Long> {
    Optional<WalkRouteLike> findBySessionIdAndUserId(Long sessionId, Long userId);
    long countBySessionId(Long sessionId);
    boolean existsBySessionIdAndUserId(Long sessionId, Long userId);
}
