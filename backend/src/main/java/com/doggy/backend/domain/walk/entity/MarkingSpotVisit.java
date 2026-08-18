package com.doggy.backend.domain.walk.entity;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "marking_spot_visits", indexes = {
        @Index(name = "idx_marking_spot_visits_spot_created", columnList = "spot_id, created_at DESC"),
        @Index(name = "idx_marking_spot_visits_dog_created", columnList = "dog_id, created_at DESC")
}, uniqueConstraints = {
        @UniqueConstraint(name = "uq_marking_spot_visit", columnNames = {"spot_id", "session_id", "dog_id"})
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MarkingSpotVisit extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "spot_id", nullable = false)
    private MarkingSpot spot;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "session_id", nullable = false)
    private WalkSession session;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "dog_id", nullable = false)
    private Dog dog;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private LocalDateTime visitedAt;

    @Builder
    public MarkingSpotVisit(MarkingSpot spot, WalkSession session, Dog dog, User user, LocalDateTime visitedAt) {
        this.spot = spot;
        this.session = session;
        this.dog = dog;
        this.user = user;
        this.visitedAt = visitedAt;
    }
}
