package com.doggy.backend.domain.walk.entity;

import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "marking_spots", indexes = {
        @Index(name = "idx_marking_spots_last_visited", columnList = "last_visited_at DESC")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MarkingSpot extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private double lat;

    @Column(nullable = false)
    private double lng;

    @Column(nullable = false, unique = true, length = 50)
    private String gridKey;

    @Column(nullable = false)
    private int visitCount = 0;

    private LocalDateTime lastVisitedAt;

    @Builder
    public MarkingSpot(double lat, double lng, String gridKey) {
        this.lat = lat;
        this.lng = lng;
        this.gridKey = gridKey;
    }

    public void recordVisit(LocalDateTime visitedAt) {
        this.visitCount += 1;
        if (lastVisitedAt == null || visitedAt.isAfter(lastVisitedAt)) {
            this.lastVisitedAt = visitedAt;
        }
    }
}
