package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.household.service.HouseholdService;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.PushSettingRepository;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.domain.walk.dto.CompleteWalkRequest;
import com.doggy.backend.domain.walk.dto.PublishRouteRequest;
import com.doggy.backend.domain.walk.dto.StartWalkRequest;
import com.doggy.backend.domain.walk.dto.WalkPointRequest;
import com.doggy.backend.domain.walk.dto.WalkSessionResponse;
import com.doggy.backend.domain.walk.entity.WalkRouteLike;
import com.doggy.backend.domain.walk.entity.WalkRouteBookmark;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;
import com.doggy.backend.domain.walk.repository.WalkPointRepository;
import com.doggy.backend.domain.walk.repository.WalkRouteBookmarkRepository;
import com.doggy.backend.domain.walk.repository.WalkRouteLikeRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.common.RequestLimits;
import com.doggy.backend.global.fcm.FcmService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class WalkServiceTest {

    @Mock WalkSessionRepository walkSessionRepository;
    @Mock WalkPointRepository walkPointRepository;
    @Mock WalkRouteLikeRepository likeRepository;
    @Mock WalkRouteBookmarkRepository bookmarkRepository;
    @Mock UserRepository userRepository;
    @Mock DogRepository dogRepository;
    @Mock HouseholdService householdService;
    @Mock PushSettingRepository pushSettingRepository;
    @Mock FcmService fcmService;
    @Mock WalkPingService walkPingService;
    @Mock JdbcTemplate jdbcTemplate;

    @InjectMocks WalkService walkService;

    private User makeUser(Long id) {
        User user = User.builder().nickname("user" + id).build();
        ReflectionTestUtils.setField(user, "id", id);
        return user;
    }

    private WalkSession makeSession(Long id, User user, Status status) {
        WalkSession session = WalkSession.builder()
                .user(user)
                .startedAt(LocalDateTime.now().minusMinutes(10))
                .build();
        ReflectionTestUtils.setField(session, "id", id);
        ReflectionTestUtils.setField(session, "status", status);
        return session;
    }

    @Nested
    @DisplayName("start")
    class Start {

        @Test
        @DisplayName("기존 IN_PROGRESS 세션은 자동으로 abandon 처리")
        void autoAbandon_existingInProgressSession() {
            User user = makeUser(1L);
            WalkSession staleSession = makeSession(99L, user, Status.IN_PROGRESS);

            given(walkSessionRepository.findActiveSession(1L, Status.IN_PROGRESS))
                    .willReturn(Optional.of(staleSession));
            given(walkSessionRepository.findActiveSession(1L, Status.PAUSED))
                    .willReturn(Optional.empty());
            given(userRepository.findById(1L)).willReturn(Optional.of(user));
            given(walkSessionRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            walkService.start(1L, new StartWalkRequest(List.of()));

            verify(walkSessionRepository).saveAndFlush(staleSession);
            assertThat(staleSession.getStatus()).isEqualTo(Status.ABANDONED);
        }

        @Test
        @DisplayName("강아지 없이 시작하면 빈 세션 생성")
        void success_startWithNoDogs() {
            User user = makeUser(1L);
            given(walkSessionRepository.findActiveSession(1L, Status.IN_PROGRESS)).willReturn(Optional.empty());
            given(walkSessionRepository.findActiveSession(1L, Status.PAUSED)).willReturn(Optional.empty());
            given(userRepository.findById(1L)).willReturn(Optional.of(user));
            given(walkSessionRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            WalkSessionResponse response = walkService.start(1L, new StartWalkRequest(List.of()));

            assertThat(response.status()).isEqualTo(Status.IN_PROGRESS);
            assertThat(response.dogs()).isEmpty();
        }
    }

    @Nested
    @DisplayName("complete")
    class Complete {

        @Test
        @DisplayName("이미 완료된 세션은 재완료 불가")
        void fail_alreadyCompleted() {
            User user = makeUser(1L);
            WalkSession session = makeSession(10L, user, Status.COMPLETED);

            given(walkSessionRepository.findByIdAndUserId(10L, 1L)).willReturn(Optional.of(session));

            CompleteWalkRequest request = new CompleteWalkRequest(LocalDateTime.now(), List.of());
            assertThatThrownBy(() -> walkService.complete(1L, 10L, request))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("이미 완료된 산책입니다");
        }

        @Test
        @DisplayName("경로 포인트가 너무 많으면 완료 요청 거부")
        void fail_tooManyPoints() {
            WalkPointRequest point = new WalkPointRequest(LocalDateTime.now(), 37.5, 127.0, null);
            CompleteWalkRequest request = new CompleteWalkRequest(
                    LocalDateTime.now(),
                    Collections.nCopies(RequestLimits.MAX_WALK_POINTS + 1, point));

            assertThatThrownBy(() -> walkService.complete(1L, 10L, request))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("포인트");

            verify(walkSessionRepository, never()).findByIdAndUserId(any(), any());
        }

        @Test
        @DisplayName("잘못된 좌표가 있으면 완료 요청 거부")
        void fail_invalidPointCoordinate() {
            CompleteWalkRequest request = new CompleteWalkRequest(
                    LocalDateTime.now(),
                    List.of(new WalkPointRequest(LocalDateTime.now(), 91.0, 127.0, null)));

            assertThatThrownBy(() -> walkService.complete(1L, 10L, request))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("좌표");

            verify(walkSessionRepository, never()).findByIdAndUserId(any(), any());
        }
    }

    @Nested
    @DisplayName("pause / resume")
    class PauseResume {

        @Test
        @DisplayName("IN_PROGRESS 세션을 일시정지하면 PAUSED 상태")
        void pause_changesStatusToPaused() {
            User user = makeUser(1L);
            WalkSession session = makeSession(10L, user, Status.IN_PROGRESS);

            given(walkSessionRepository.findByIdAndUserId(10L, 1L)).willReturn(Optional.of(session));

            WalkSessionResponse response = walkService.pause(1L, 10L);

            assertThat(response.status()).isEqualTo(Status.PAUSED);
        }

        @Test
        @DisplayName("PAUSED 세션을 재개하면 IN_PROGRESS 상태")
        void resume_changesStatusToInProgress() {
            User user = makeUser(1L);
            WalkSession session = makeSession(10L, user, Status.PAUSED);

            given(walkSessionRepository.findByIdAndUserId(10L, 1L)).willReturn(Optional.of(session));

            WalkSessionResponse response = walkService.resume(1L, 10L);

            assertThat(response.status()).isEqualTo(Status.IN_PROGRESS);
        }
    }

    @Nested
    @DisplayName("publish")
    class Publish {

        @Test
        @DisplayName("경로 공개 안내 동의가 없으면 공개 불가")
        void fail_withoutDisclosureAcceptance() {
            User user = makeUser(1L);
            WalkSession session = makeSession(10L, user, Status.COMPLETED);

            given(walkSessionRepository.findByIdAndUserId(10L, 1L)).willReturn(Optional.of(session));

            assertThatThrownBy(() -> walkService.publish(1L, 10L, new PublishRouteRequest("공개 코스", false)))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("공개 안내");

            assertThat(session.isPublic()).isFalse();
            verify(walkPointRepository, never()).findRouteGeoJsonBySessionId(any());
        }

        @Test
        @DisplayName("경로 공개 안내에 동의하면 공개 처리")
        void success_withDisclosureAcceptance() {
            User user = makeUser(1L);
            WalkSession session = makeSession(10L, user, Status.COMPLETED);

            given(walkSessionRepository.findByIdAndUserId(10L, 1L)).willReturn(Optional.of(session));
            given(walkPointRepository.findRouteGeoJsonBySessionId(10L)).willReturn(null);

            walkService.publish(1L, 10L, new PublishRouteRequest("공개 코스", true));

            assertThat(session.isPublic()).isTrue();
            assertThat(session.getTitle()).isEqualTo("공개 코스");
        }
    }

    @Nested
    @DisplayName("toggleLike")
    class ToggleLike {

        @Test
        @DisplayName("좋아요 없을 때 토글하면 좋아요 추가 (true 반환)")
        void toggle_addLike() {
            User user = makeUser(1L);
            WalkSession session = makeSession(10L, user, Status.COMPLETED);

            given(userRepository.findById(1L)).willReturn(Optional.of(user));
            given(walkSessionRepository.findById(10L)).willReturn(Optional.of(session));
            given(likeRepository.findBySessionIdAndUserId(10L, 1L)).willReturn(Optional.empty());
            given(likeRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            boolean result = walkService.toggleLike(1L, 10L);

            assertThat(result).isTrue();
            verify(likeRepository).save(any(WalkRouteLike.class));
        }

        @Test
        @DisplayName("이미 좋아요 있을 때 토글하면 좋아요 취소 (false 반환)")
        void toggle_removeLike() {
            User user = makeUser(1L);
            WalkSession session = makeSession(10L, user, Status.COMPLETED);
            WalkRouteLike like = WalkRouteLike.builder().session(session).user(user).build();

            given(userRepository.findById(1L)).willReturn(Optional.of(user));
            given(walkSessionRepository.findById(10L)).willReturn(Optional.of(session));
            given(likeRepository.findBySessionIdAndUserId(10L, 1L)).willReturn(Optional.of(like));

            boolean result = walkService.toggleLike(1L, 10L);

            assertThat(result).isFalse();
            verify(likeRepository).delete(like);
        }
    }

    @Nested
    @DisplayName("toggleBookmark")
    class ToggleBookmark {

        @Test
        @DisplayName("북마크 없을 때 토글하면 북마크 추가 (true 반환)")
        void toggle_addBookmark() {
            User user = makeUser(1L);
            WalkSession session = makeSession(10L, user, Status.COMPLETED);

            given(userRepository.findById(1L)).willReturn(Optional.of(user));
            given(walkSessionRepository.findById(10L)).willReturn(Optional.of(session));
            given(bookmarkRepository.findBySessionIdAndUserId(10L, 1L)).willReturn(Optional.empty());
            given(bookmarkRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            boolean result = walkService.toggleBookmark(1L, 10L);

            assertThat(result).isTrue();
            verify(bookmarkRepository).save(any(WalkRouteBookmark.class));
        }

        @Test
        @DisplayName("이미 북마크 있을 때 토글하면 북마크 취소 (false 반환)")
        void toggle_removeBookmark() {
            User user = makeUser(1L);
            WalkSession session = makeSession(10L, user, Status.COMPLETED);
            WalkRouteBookmark bookmark = WalkRouteBookmark.builder().session(session).user(user).build();

            given(userRepository.findById(1L)).willReturn(Optional.of(user));
            given(walkSessionRepository.findById(10L)).willReturn(Optional.of(session));
            given(bookmarkRepository.findBySessionIdAndUserId(10L, 1L)).willReturn(Optional.of(bookmark));

            boolean result = walkService.toggleBookmark(1L, 10L);

            assertThat(result).isFalse();
            verify(bookmarkRepository).delete(bookmark);
        }
    }
}
