package com.doggy.backend.domain.place.repository;

import com.doggy.backend.domain.place.entity.PlaceVote;
import com.doggy.backend.domain.place.entity.PlaceVote.VoteType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface PlaceVoteRepository extends JpaRepository<PlaceVote, Long> {

    Optional<PlaceVote> findByPlaceIdAndUserId(Long placeId, Long userId);

    long countByPlaceIdAndVoteType(Long placeId, VoteType voteType);

    @Query("""
            SELECT COUNT(v) FROM PlaceVote v
            WHERE v.place.id = :placeId AND v.voteType = 'HELPFUL'
            """)
    long countHelpfulByPlaceId(@Param("placeId") Long placeId);
}
