package com.doggy.backend.domain.walk.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(
    name = "walk_points",
    indexes = @Index(name = "idx_walk_points_session_time", columnList = "session_id, recorded_at")
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class WalkPoint {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "session_id", nullable = false)
    private WalkSession session;

    @Column(nullable = false)
    private LocalDateTime recordedAt;

    @Column(nullable = false)
    private double lat;

    @Column(nullable = false)
    private double lng;

    private Float accuracy;

    @Builder
    public WalkPoint(WalkSession session, LocalDateTime recordedAt, double lat, double lng, Float accuracy) {
        this.session = session;
        this.recordedAt = recordedAt;
        this.lat = lat;
        this.lng = lng;
        this.accuracy = accuracy;
    }
}
