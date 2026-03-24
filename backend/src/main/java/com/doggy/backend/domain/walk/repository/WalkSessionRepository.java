package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface WalkSessionRepository extends JpaRepository<WalkSession, Long> {

    List<WalkSession> findAllByUserIdOrderByStartedAtDesc(Long userId, Pageable pageable);

    Optional<WalkSession> findByIdAndUserId(Long id, Long userId);

    Optional<WalkSession> findTopByUserIdOrderByStartedAtDesc(Long userId);

    @Query("SELECT w FROM WalkSession w WHERE w.user.id = :userId AND w.status = :status")
    Optional<WalkSession> findActiveSession(@Param("userId") Long userId, @Param("status") Status status);
}
