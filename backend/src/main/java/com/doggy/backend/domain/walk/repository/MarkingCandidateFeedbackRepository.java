package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.MarkingCandidateFeedback;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface MarkingCandidateFeedbackRepository extends JpaRepository<MarkingCandidateFeedback, Long> {
    boolean existsBySessionId(Long sessionId);
    List<MarkingCandidateFeedback> findAllBySessionId(Long sessionId);

    // shortcut: 후보 키의 답변을 요청 시 집계한다. 인기 위치에서 느려지면 키별 집계를 저장한다.
    @Query(value = """
            SELECT candidate_key AS "candidateKey",
                   COUNT(*) FILTER (WHERE marked) AS "positiveCount",
                   COUNT(*) AS "totalCount"
            FROM (
                SELECT DISTINCT ON (f.candidate_key, s.user_id)
                       f.candidate_key, s.user_id, f.marked
                FROM marking_candidate_feedback f
                JOIN walk_sessions s ON s.id = f.session_id
                WHERE f.candidate_key IN (:keys) AND s.marking_eligible = TRUE
                ORDER BY f.candidate_key, s.user_id, f.id DESC
            ) latest_votes
            GROUP BY candidate_key
            """, nativeQuery = true)
    List<CandidateVoteCount> findVoteCounts(@Param("keys") Collection<String> keys);

    interface CandidateVoteCount {
        String getCandidateKey();
        long getPositiveCount();
        long getTotalCount();
    }
}
