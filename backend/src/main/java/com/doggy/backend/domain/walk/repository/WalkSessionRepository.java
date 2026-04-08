package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface WalkSessionRepository extends JpaRepository<WalkSession, Long> {

    List<WalkSession> findAllByUserIdOrderByStartedAtDesc(Long userId, Pageable pageable);

    Optional<WalkSession> findByIdAndUserId(Long id, Long userId);

    Optional<WalkSession> findTopByUserIdOrderByStartedAtDesc(Long userId);

    @Query("SELECT w FROM WalkSession w WHERE w.user.id = :userId AND w.status = :status")
    Optional<WalkSession> findActiveSession(@Param("userId") Long userId, @Param("status") Status status);

    // 공개된 경로 목록 (최신순)
    @Query("SELECT w FROM WalkSession w WHERE w.isPublic = true AND w.status = 'COMPLETED' ORDER BY w.startedAt DESC")
    List<WalkSession> findPublicRoutes(Pageable pageable);

    // 마지막 산책이 since 이전인 유저 ID 목록 (fcmToken 있는 유저만)
    @Query("""
            SELECT DISTINCT w.user.id FROM WalkSession w
            WHERE w.status = 'COMPLETED'
            AND w.user.fcmToken IS NOT NULL
            AND w.user.id NOT IN (
                SELECT w2.user.id FROM WalkSession w2
                WHERE w2.status = 'COMPLETED'
                AND w2.startedAt >= :since
            )
            """)
    List<Long> findUserIdsNotWalkedSince(@Param("since") OffsetDateTime since);

    // 특정 월의 완료된 산책 거리 합계 (미터)
    @Query("""
            SELECT COALESCE(SUM(w.distanceMeters), 0) FROM WalkSession w
            WHERE w.user.id = :userId
            AND w.status = 'COMPLETED'
            AND FUNCTION('YEAR', w.startedAt) = :year
            AND FUNCTION('MONTH', w.startedAt) = :month
            """)
    int sumDistanceByUserAndMonth(@Param("userId") Long userId,
                                   @Param("year") int year,
                                   @Param("month") int month);
}
