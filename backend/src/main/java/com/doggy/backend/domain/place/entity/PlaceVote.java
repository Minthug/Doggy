package com.doggy.backend.domain.place.entity;

import com.doggy.backend.domain.user.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(
    name = "place_votes",
    uniqueConstraints = @UniqueConstraint(columnNames = {"place_id", "user_id"}),
    indexes = {
        @Index(name = "idx_place_votes_place_vote_type", columnList = "place_id, vote_type")
    }
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PlaceVote {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "place_id", nullable = false)
    private Place place;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private VoteType voteType;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    private void setCreatedAt() {
        this.createdAt = LocalDateTime.now();
    }

    @Builder
    public PlaceVote(Place place, User user, VoteType voteType) {
        this.place = place;
        this.user = user;
        this.voteType = voteType;
    }

    public void updateVote(VoteType voteType) {
        this.voteType = voteType;
    }

    public enum VoteType {
        HELPFUL, NOT_HELPFUL
    }
}
