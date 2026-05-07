package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.WalkRouteBookmark;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.Optional;
import java.util.Set;

public interface WalkRouteBookmarkRepository extends JpaRepository<WalkRouteBookmark, Long> {
    Optional<WalkRouteBookmark> findBySessionIdAndUserId(Long sessionId, Long userId);
    boolean existsBySessionIdAndUserId(Long sessionId, Long userId);

    @Query("SELECT b.session.id FROM WalkRouteBookmark b WHERE b.session.id IN :sessionIds AND b.user.id = :userId")
    Set<Long> findBookmarkedSessionIds(@Param("sessionIds") Collection<Long> sessionIds, @Param("userId") Long userId);
}
