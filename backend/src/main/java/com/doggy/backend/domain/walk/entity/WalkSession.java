package com.doggy.backend.domain.walk.entity;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.BatchSize;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "walk_sessions", indexes = {
        @Index(name = "idx_walk_sessions_user_started", columnList = "user_id, started_at DESC"),
        @Index(name = "idx_walk_sessions_user_status", columnList = "user_id, status"),
        @Index(name = "idx_walk_sessions_household_status_started", columnList = "household_id, status, started_at DESC"),
        @Index(name = "idx_walk_sessions_public_status", columnList = "is_public, status")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class WalkSession extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    // 산책 당시의 가족 소속 스냅샷. 이후 강아지/사용자가 가족을 옮겨도 바뀌지 않는다.
    private Long householdId;

    @Column(nullable = false)
    private LocalDateTime startedAt;

    private LocalDateTime endedAt;

    @Column(nullable = false)
    private int distanceMeters = 0;

    @Column(nullable = false)
    private int durationSeconds = 0;

    private LocalDateTime pausedAt;

    @Column(nullable = false)
    private int totalPausedSeconds = 0;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Status status = Status.IN_PROGRESS;

    @Column(nullable = false)
    private boolean isPublic = false;

    @Column(length = 100)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String routeGeoJson;

    @Column(nullable = false)
    private boolean isArchived = false;

    private LocalDateTime archivedAt;

    @Column(columnDefinition = "TEXT")
    private String traceImageSvg;

    @Column(columnDefinition = "TEXT")
    private String tracePathData;

    private LocalDateTime detailsPurgedAt;

    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
            name = "walk_session_dogs",
            joinColumns = @JoinColumn(name = "session_id"),
            inverseJoinColumns = @JoinColumn(name = "dog_id")
    )
    @BatchSize(size = 30)
    private List<Dog> dogs = new ArrayList<>();

    @Builder
    public WalkSession(User user, Long householdId, LocalDateTime startedAt) {
        this.user = user;
        this.householdId = householdId;
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
        if (this.status == Status.PAUSED) {
            addPausedDurationUntil(endedAt);
            this.pausedAt = null;
        }
        this.endedAt = endedAt;
        this.distanceMeters = distanceMeters;
        this.durationSeconds = durationSeconds;
        this.status = Status.COMPLETED;
    }

    public void saveRouteGeoJson(String geoJson) {
        this.routeGeoJson = geoJson;
    }

    public void archive(String tracePathData) {
        this.isArchived = true;
        this.archivedAt = LocalDateTime.now();
        this.tracePathData = tracePathData;
        this.traceImageSvg = null;
    }

    public void unarchive() {
        this.isArchived = false;
        this.archivedAt = null;
        this.traceImageSvg = null;
        this.tracePathData = null;
    }

    public void purgeDetails() {
        this.routeGeoJson = null;
        this.detailsPurgedAt = LocalDateTime.now();
        makePrivate();
    }

    public void abandon() {
        LocalDateTime abandonedAt = LocalDateTime.now();
        if (this.status == Status.PAUSED) {
            addPausedDurationUntil(abandonedAt);
            this.pausedAt = null;
        }
        this.endedAt = abandonedAt;
        this.status = Status.ABANDONED;
    }

    public void pause(LocalDateTime pausedAt) {
        if (this.status != Status.IN_PROGRESS) return;
        this.pausedAt = pausedAt;
        this.status = Status.PAUSED;
    }

    public void resume(LocalDateTime resumedAt) {
        if (this.status != Status.PAUSED) return;
        addPausedDurationUntil(resumedAt);
        this.pausedAt = null;
        this.status = Status.IN_PROGRESS;
    }

    public int calculateActiveDurationSeconds(LocalDateTime endedAt) {
        long elapsedSeconds = Math.max(0, java.time.Duration.between(startedAt, endedAt).getSeconds());
        long pausedSeconds = totalPausedSeconds;
        if (status == Status.PAUSED && pausedAt != null) {
            pausedSeconds += Math.max(0, java.time.Duration.between(pausedAt, endedAt).getSeconds());
        }
        return (int) Math.min(Integer.MAX_VALUE, Math.max(0, elapsedSeconds - pausedSeconds));
    }

    private void addPausedDurationUntil(LocalDateTime resumedAt) {
        if (pausedAt == null) return;
        long seconds = Math.max(0, java.time.Duration.between(pausedAt, resumedAt).getSeconds());
        totalPausedSeconds = (int) Math.min(Integer.MAX_VALUE, (long) totalPausedSeconds + seconds);
    }

    public void setDogs(List<Dog> dogs) {
        this.dogs = dogs != null ? dogs : new ArrayList<>();
    }

    public enum Status {
        IN_PROGRESS, PAUSED, COMPLETED, ABANDONED
    }
}
