package com.doggy.backend.domain.walk.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "walk_ping_logs",
        uniqueConstraints = @UniqueConstraint(columnNames = {"session_a_id", "session_b_id"}))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class WalkPingLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // 항상 sessionAId < sessionBId 로 저장 (쌍 중복 방지)
    @Column(name = "session_a_id", nullable = false)
    private Long sessionAId;

    @Column(name = "session_b_id", nullable = false)
    private Long sessionBId;

    @Column(nullable = false)
    private LocalDateTime pingedAt;

    @Builder
    public WalkPingLog(Long sessionAId, Long sessionBId) {
        this.sessionAId = sessionAId;
        this.sessionBId = sessionBId;
        this.pingedAt = LocalDateTime.now();
    }

    public void refresh() {
        this.pingedAt = LocalDateTime.now();
    }
}
