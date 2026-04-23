package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.WalkPingLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface WalkPingLogRepository extends JpaRepository<WalkPingLog, Long> {

    Optional<WalkPingLog> findBySessionAIdAndSessionBId(Long sessionAId, Long sessionBId);

    boolean existsBySessionAIdAndSessionBIdAndPingedAtAfter(
            Long sessionAId, Long sessionBId, LocalDateTime pingedAt);

    @Query("SELECT w FROM WalkPingLog w WHERE w.sessionAId = :sessionId OR w.sessionBId = :sessionId")
    List<WalkPingLog> findAllBySessionId(@Param("sessionId") Long sessionId);
}
