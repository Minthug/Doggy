package com.doggy.backend.domain.place.repository;

import com.doggy.backend.domain.place.entity.PlaceVote;
import com.doggy.backend.domain.place.entity.PlaceVote.VoteType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PlaceVoteRepository extends JpaRepository<PlaceVote, Long> {

    Optional<PlaceVote> findByPlaceIdAndUserId(Long placeId, Long userId);

    long countByPlaceIdAndVoteType(Long placeId, VoteType voteType);

    @Query("""
            SELECT COUNT(v) FROM PlaceVote v
            WHERE v.place.id = :placeId AND v.voteType = 'HELPFUL'
            """)
    long countHelpfulByPlaceId(@Param("placeId") Long placeId);

    // 여러 장소의 HELPFUL 카운트를 한 번에 조회 (N+1 방지)
    @Query(value = """
            SELECT place_id, COUNT(*) FROM place_votes
            WHERE vote_type = 'HELPFUL' AND place_id IN (:placeIds)
            GROUP BY place_id
            """, nativeQuery = true)
    List<Object[]> countHelpfulByPlaceIds(@Param("placeIds") List<Long> placeIds);
}
