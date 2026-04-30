package com.doggy.backend.domain.walk.entity;

import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "walk_sessions")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class WalkSession extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private LocalDateTime startedAt;

    private LocalDateTime endedAt;

    @Column(nullable = false)
    private int distanceMeters = 0;

    @Column(nullable = false)
    private int durationSeconds = 0;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Status status = Status.IN_PROGRESS;

    @Column(nullable = false)
    private boolean isPublic = false;

    @Column(length = 100)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String routeGeoJson;

    @Builder
    public WalkSession(User user, LocalDateTime startedAt) {
        this.user = user;
        this.startedAt = startedAt;
    }

    public void makePublic(String title) {
        this.isPublic = true;
        this.title = title;
    }

    public void makePrivate() {
        this.isPublic = false;
        this.title = null;
    }

    public void complete(LocalDateTime endedAt, int distanceMeters, int durationSeconds) {
        this.endedAt = endedAt;
        this.distanceMeters = distanceMeters;
        this.durationSeconds = durationSeconds;
        this.status = Status.COMPLETED;
    }

    public void saveRouteGeoJson(String geoJson) {
        this.routeGeoJson = geoJson;
    }

    public void abandon() {
        this.endedAt = LocalDateTime.now();
        this.status = Status.COMPLETED;
    }

    public void pause() {
        this.status = Status.PAUSED;
    }

    public void resume() {
        this.status = Status.IN_PROGRESS;
    }

    public enum Status {
        IN_PROGRESS, PAUSED, COMPLETED
    }
}
