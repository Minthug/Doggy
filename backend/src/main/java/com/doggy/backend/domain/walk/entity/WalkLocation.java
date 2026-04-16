package com.doggy.backend.domain.walk.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "walk_locations")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class WalkLocation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "walk_session_id", nullable = false, unique = true)
    private WalkSession walkSession;

    @Column(nullable = false)
    private Double lat;

    @Column(nullable = false)
    private Double lng;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    @Builder
    public WalkLocation(WalkSession walkSession, Double lat, Double lng) {
        this.walkSession = walkSession;
        this.lat = lat;
        this.lng = lng;
        this.updatedAt = LocalDateTime.now();
    }

    public void update(Double lat, Double lng) {
        this.lat = lat;
        this.lng = lng;
        this.updatedAt = LocalDateTime.now();
    }
}
