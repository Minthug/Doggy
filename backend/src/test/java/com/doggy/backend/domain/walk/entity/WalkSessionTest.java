package com.doggy.backend.domain.walk.entity;

import com.doggy.backend.domain.user.entity.User;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;

class WalkSessionTest {

    private static final LocalDateTime STARTED_AT = LocalDateTime.of(2026, 10, 26, 14, 0);

    @Test
    @DisplayName("여러 번 일시정지한 시간을 산책 시간에서 제외한다")
    void excludesAccumulatedPausedDuration() {
        WalkSession session = newSession();

        session.pause(STARTED_AT.plusMinutes(2));
        session.resume(STARTED_AT.plusMinutes(5));
        session.pause(STARTED_AT.plusMinutes(7));
        session.resume(STARTED_AT.plusMinutes(8));

        assertThat(session.calculateActiveDurationSeconds(STARTED_AT.plusMinutes(10)))
                .isEqualTo(6 * 60);
        assertThat(session.getTotalPausedSeconds()).isEqualTo(4 * 60);
    }

    @Test
    @DisplayName("일시정지 상태에서 종료해도 진행 중인 일시정지 시간을 제외한다")
    void excludesCurrentPauseWhenCompletedWhilePaused() {
        WalkSession session = newSession();

        session.pause(STARTED_AT.plusMinutes(2));
        LocalDateTime endedAt = STARTED_AT.plusMinutes(10);
        int activeDurationSeconds = session.calculateActiveDurationSeconds(endedAt);
        session.complete(endedAt, 0, activeDurationSeconds);

        assertThat(session.getDurationSeconds()).isEqualTo(2 * 60);
        assertThat(session.getTotalPausedSeconds()).isEqualTo(8 * 60);
        assertThat(session.getPausedAt()).isNull();
    }

    @Test
    @DisplayName("중복 일시정지 요청은 일시정지 시작 시각을 덮어쓰지 않는다")
    void duplicatePauseDoesNotResetPausedAt() {
        WalkSession session = newSession();

        session.pause(STARTED_AT.plusMinutes(2));
        session.pause(STARTED_AT.plusMinutes(4));
        session.resume(STARTED_AT.plusMinutes(5));

        assertThat(session.getTotalPausedSeconds()).isEqualTo(3 * 60);
    }

    private WalkSession newSession() {
        User user = User.builder().nickname("walker").build();
        return WalkSession.builder()
                .user(user)
                .startedAt(STARTED_AT)
                .build();
    }
}
