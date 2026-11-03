package com.doggy.backend.domain.walk.entity;

import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "marking_candidate_feedback", uniqueConstraints =
        @UniqueConstraint(columnNames = {"session_id", "candidate_key"}))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MarkingCandidateFeedback extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "session_id", nullable = false)
    private WalkSession session;

    @Column(name = "candidate_key", nullable = false, length = 50)
    private String candidateKey;

    @Column(name = "detected_at", nullable = false)
    private LocalDateTime detectedAt;

    @Column(name = "dwell_seconds", nullable = false)
    private int dwellSeconds;

    @Column(nullable = false)
    private int score;

    @Column(nullable = false, length = 10)
    private String source;

    @Column(nullable = false)
    private boolean marked;

    public MarkingCandidateFeedback(WalkSession session, String candidateKey, LocalDateTime detectedAt,
                                    int dwellSeconds, int score, String source, boolean marked) {
        this.session = session;
        this.candidateKey = candidateKey;
        this.detectedAt = detectedAt;
        this.dwellSeconds = dwellSeconds;
        this.score = score;
        this.source = source;
        this.marked = marked;
    }
}
