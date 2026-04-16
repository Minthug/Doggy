package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.WalkPingLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.Optional;

public interface WalkPingLogRepository extends JpaRepository<WalkPingLog, Long> {

    Optional<WalkPingLog> findBySessionAIdAndSessionBId(Long sessionAId, Long sessionBId);

    boolean existsBySessionAIdAndSessionBIdAndPingedAtAfter(
            Long sessionAId, Long sessionBId, LocalDateTime pingedAt);
}
