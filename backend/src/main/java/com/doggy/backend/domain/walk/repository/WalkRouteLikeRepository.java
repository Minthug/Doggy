package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.WalkRouteLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.Set;

public interface WalkRouteLikeRepository extends JpaRepository<WalkRouteLike, Long> {
    Optional<WalkRouteLike> findBySessionIdAndUserId(Long sessionId, Long userId);
    long countBySessionId(Long sessionId);
    boolean existsBySessionIdAndUserId(Long sessionId, Long userId);

    @Query("SELECT l.session.id, COUNT(l) FROM WalkRouteLike l WHERE l.session.id IN :sessionIds GROUP BY l.session.id")
    List<Object[]> countBySessionIdIn(@Param("sessionIds") Collection<Long> sessionIds);

    @Query("SELECT l.session.id FROM WalkRouteLike l WHERE l.session.id IN :sessionIds AND l.user.id = :userId")
    Set<Long> findLikedSessionIds(@Param("sessionIds") Collection<Long> sessionIds, @Param("userId") Long userId);
}
