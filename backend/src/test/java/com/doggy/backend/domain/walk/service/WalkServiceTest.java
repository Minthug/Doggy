package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.household.dto.HouseholdIdCache;
import com.doggy.backend.domain.household.service.HouseholdService;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.PushSettingRepository;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.domain.walk.dto.CompleteWalkRequest;
import com.doggy.backend.domain.walk.dto.PublishRouteRequest;
import com.doggy.backend.domain.walk.dto.StartWalkRequest;
import com.doggy.backend.domain.walk.dto.WalkPointRequest;
import com.doggy.backend.domain.walk.dto.WalkSessionResponse;
import com.doggy.backend.domain.walk.dto.TodayWalkStatsResponse;
import com.doggy.backend.domain.walk.entity.WalkRouteLike;
import com.doggy.backend.domain.walk.entity.WalkRouteBookmark;
import com.doggy.backend.domain.walk.entity.WalkPoint;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;
import com.doggy.backend.domain.walk.repository.WalkPointRepository;
import com.doggy.backend.domain.walk.repository.WalkRouteBookmarkRepository;
import com.doggy.backend.domain.walk.repository.WalkRouteLikeRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import com.doggy.backend.domain.walk.repository.TodayWalkStatsProjection;
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
import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.*;
import org.mockito.ArgumentCaptor;

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
    @Mock MarkingSpotService markingSpotService;
    @Mock WalkTracePathService walkTracePathService;
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
            given(householdService.findHouseholdIdByUserId(1L))
                    .willReturn(new HouseholdIdCache(7L));
            given(walkSessionRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            WalkSessionResponse response = walkService.start(1L, new StartWalkRequest(List.of()));

            assertThat(response.status()).isEqualTo(Status.IN_PROGRESS);
            assertThat(response.dogs()).isEmpty();

            ArgumentCaptor<WalkSession> captor = ArgumentCaptor.forClass(WalkSession.class);
            verify(walkSessionRepository).save(captor.capture());
            assertThat(captor.getValue().getHouseholdId()).isEqualTo(7L);
        }
    }

    @Nested
    @DisplayName("family sharing")
    class FamilySharing {

        @Test
        @DisplayName("같은 가족의 완료 산책은 작성자가 아니어도 상세 조회 가능")
        void detail_allowsCompletedHouseholdWalk() {
            User writer = makeUser(2L);
            WalkSession session = makeSession(10L, writer, Status.COMPLETED);
            LocalDateTime joinedAt = LocalDateTime.now().minusDays(1);

            given(householdService.findHouseholdIdByUserId(1L))
                    .willReturn(new HouseholdIdCache(7L, joinedAt));
            given(walkSessionRepository.findAccessibleById(
                    eq(10L), eq(1L), eq(7L), eq(joinedAt),
                    any(LocalDateTime.class), eq(Status.COMPLETED)))
                    .willReturn(Optional.of(session));
            given(walkPointRepository.findRouteGeoJsonBySessionId(10L)).willReturn(null);
            given(markingSpotService.getSessionSpots(10L)).willReturn(List.of());

            var response = walkService.getDetail(1L, 10L);

            assertThat(response.id()).isEqualTo(10L);
            verify(walkSessionRepository)
                    .findAccessibleById(eq(10L), eq(1L), eq(7L), eq(joinedAt),
                            any(LocalDateTime.class), eq(Status.COMPLETED));
        }

        @Test
        @DisplayName("오늘 통계는 가족 스냅샷을 포함한 서버 집계 사용")
        void todayStats_usesServerAggregate() {
            TodayWalkStatsProjection projection = mock(TodayWalkStatsProjection.class);
            LocalDateTime joinedAt = LocalDateTime.now().minusDays(1);
            given(projection.getTotalDistanceMeters()).willReturn(1500L);
            given(projection.getTotalDurationSeconds()).willReturn(900L);
            given(projection.getWalkCount()).willReturn(2L);
            given(householdService.findHouseholdIdByUserId(1L))
                    .willReturn(new HouseholdIdCache(7L, joinedAt));
            given(walkSessionRepository.findTodayStats(
                    eq(1L), eq(7L), any(LocalDate.class)))
                    .willReturn(projection);

            TodayWalkStatsResponse response = walkService.getTodayStats(1L);

            assertThat(response.totalDistanceMeters()).isEqualTo(1500L);
            assertThat(response.totalDurationSeconds()).isEqualTo(900L);
            assertThat(response.walkCount()).isEqualTo(2L);
        }

        @Test
        @DisplayName("가족이 없는 계정은 null 가족 파라미터 없이 소유자 상세 조회")
        void detail_withoutHouseholdUsesOwnerQuery() {
            User user = makeUser(1L);
            WalkSession session = makeSession(10L, user, Status.COMPLETED);
            given(householdService.findHouseholdIdByUserId(1L)).willReturn(null);
            given(walkSessionRepository.findAccessibleByOwnerId(
                    eq(10L), eq(1L), any(LocalDateTime.class), eq(Status.COMPLETED)))
                    .willReturn(Optional.of(session));
            given(walkPointRepository.findRouteGeoJsonBySessionId(10L)).willReturn(null);
            given(markingSpotService.getSessionSpots(10L)).willReturn(List.of());

            var response = walkService.getDetail(1L, 10L);

            assertThat(response.id()).isEqualTo(10L);
            verify(walkSessionRepository, never()).findAccessibleById(
                    any(), any(), any(), any(), any(), any());
        }
    }

    @Nested
    @DisplayName("trace discoveries")
    class TraceDiscoveries {

        @Test
        @DisplayName("가까운 공개 산책은 보호자 정보 없이 강아지와 경로만 반환")
        void returnsNearbyPublicDogTrace() {
            User owner = makeUser(1L);
            User other = makeUser(2L);
            LocalDateTime walkedAt = LocalDateTime.of(2026, 10, 19, 15, 0);
            WalkSession target = WalkSession.builder().user(owner).startedAt(walkedAt).build();
            ReflectionTestUtils.setField(target, "id", 10L);
            ReflectionTestUtils.setField(target, "status", Status.COMPLETED);
            WalkSession trace = WalkSession.builder()
                    .user(other)
                    .startedAt(walkedAt.minusHours(1))
                    .build();
            ReflectionTestUtils.setField(trace, "id", 20L);
            ReflectionTestUtils.setField(trace, "status", Status.COMPLETED);
            trace.makePublic("공개 산책");
            Dog dog = Dog.builder().user(other).name("보리").breed("웰시코기").build();
            ReflectionTestUtils.setField(dog, "id", 4L);
            trace.getDogs().add(dog);
            String route = """
                    {"type":"LineString","coordinates":[
                    [127.000001,37.000001],[127.003001,37.000001],
                    [127.006001,37.000001],[127.009001,37.000001],
                    [127.012001,37.000001],[127.015001,37.000001],
                    [127.018001,37.000001]]}
                    """;

            given(householdService.findHouseholdIdByUserId(1L)).willReturn(null);
            given(walkSessionRepository.findAccessibleByOwnerId(
                    eq(10L), eq(1L), any(LocalDateTime.class), eq(Status.COMPLETED)))
                    .willReturn(Optional.of(target));
            given(walkPointRepository.findNearbyPublicTraceSessionIds(10L, 80.0, 30))
                    .willReturn(List.of(20L));
            given(walkSessionRepository.findAllByIdWithDogs(List.of(20L)))
                    .willReturn(List.of(trace));
            given(walkPointRepository.findRouteGeoJsonBySessionIds(List.of(20L)))
                    .willReturn(List.<Object[]>of(new Object[]{20L, route}));

            var response = walkService.getTraceDiscoveries(1L, 10L);

            assertThat(response).hasSize(1);
            assertThat(response.getFirst().recency().name()).isEqualTo("TODAY");
            assertThat(response.getFirst().routeGeoJson())
                    .doesNotContain("127.000001", "127.018001")
                    .contains("[127.003,37.0]");
            assertThat(response.getFirst().dogs()).extracting("name").containsExactly("보리");
        }

        @Test
        @DisplayName("원본 상세 경로가 삭제된 산책은 흔적을 조회하지 않음")
        void returnsEmptyAfterDetailsPurged() {
            User owner = makeUser(1L);
            WalkSession target = makeSession(10L, owner, Status.COMPLETED);
            target.purgeDetails();
            given(householdService.findHouseholdIdByUserId(1L)).willReturn(null);
            given(walkSessionRepository.findAccessibleByOwnerId(
                    eq(10L), eq(1L), any(LocalDateTime.class), eq(Status.COMPLETED)))
                    .willReturn(Optional.of(target));

            assertThat(walkService.getTraceDiscoveries(1L, 10L)).isEmpty();
            verify(walkPointRepository, never())
                    .findNearbyPublicTraceSessionIds(any(), anyDouble(), anyInt());
        }
    }

    @Nested
    @DisplayName("archive")
    class Archive {

        @Test
        @DisplayName("완료 산책을 좌표 없는 압축 흔적 경로로 보관")
        void archivesCompletedWalkAsCompactTracePath() {
            User user = makeUser(1L);
            WalkSession session = makeSession(10L, user, Status.COMPLETED);
            session.saveRouteGeoJson(
                    "{\"type\":\"LineString\",\"coordinates\":[[127.1,37.5],[127.2,37.6]]}");

            given(walkSessionRepository.findAccessibleByOwnerId(
                    eq(10L), eq(1L), any(LocalDateTime.class), eq(Status.COMPLETED)))
                    .willReturn(Optional.of(session));
            given(walkTracePathService.createPathData(any(String.class)))
                    .willReturn("v1|70,530;860,-460");
            given(markingSpotService.getSessionSpots(10L)).willReturn(List.of());

            var response = walkService.archive(1L, 10L);

            assertThat(response.archived()).isTrue();
            assertThat(response.ownerId()).isEqualTo(1L);
            assertThat(response.tracePathData()).isEqualTo("v1|70,530;860,-460");
            assertThat(session.isArchived()).isTrue();
        }

        @Test
        @DisplayName("같은 가구원은 공유된 완료 산책을 보관할 수 있음")
        void householdMemberCanArchive() {
            WalkSession session = makeSession(10L, makeUser(2L), Status.COMPLETED);
            ReflectionTestUtils.setField(session, "householdId", 7L);
            session.saveRouteGeoJson(
                    "{\"type\":\"LineString\",\"coordinates\":[[127.1,37.5],[127.2,37.6]]}");
            LocalDateTime joinedAt = session.getStartedAt().minusDays(1);
            given(householdService.findHouseholdIdByUserId(1L))
                    .willReturn(new HouseholdIdCache(7L, joinedAt));
            given(walkSessionRepository.findAccessibleById(
                    eq(10L), eq(1L), eq(7L), eq(joinedAt),
                    any(LocalDateTime.class), eq(Status.COMPLETED)))
                    .willReturn(Optional.of(session));
            given(walkTracePathService.createPathData(any(String.class)))
                    .willReturn("v1|70,530;860,-460");
            given(markingSpotService.getSessionSpots(10L)).willReturn(List.of());

            var response = walkService.archive(1L, 10L);

            assertThat(response.archived()).isTrue();
            assertThat(response.ownerId()).isEqualTo(2L);
        }

        @Test
        @DisplayName("가구에 속하지 않은 사용자는 다른 사람의 산책을 보관할 수 없음")
        void rejectsUnrelatedUserArchive() {
            given(walkSessionRepository.findAccessibleByOwnerId(
                    eq(10L), eq(1L), any(LocalDateTime.class), eq(Status.COMPLETED)))
                    .willReturn(Optional.empty());

            assertThatThrownBy(() -> walkService.archive(1L, 10L))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("산책 기록을 찾을 수 없습니다");
            verify(walkSessionRepository, never()).findAccessibleById(
                    any(), any(), any(), any(), any(), any());
            verifyNoInteractions(walkTracePathService);
        }
    }

    @Nested
    @DisplayName("unarchive")
    class Unarchive {

        @Test
        @DisplayName("소유자는 보관한 산책을 해제할 수 있음")
        void ownerCanUnarchive() {
            WalkSession session = makeSession(10L, makeUser(1L), Status.COMPLETED);
            session.archive("v1|70,530;860,-460");
            given(walkSessionRepository.findAccessibleByOwnerId(
                    eq(10L), eq(1L), any(LocalDateTime.class), eq(Status.COMPLETED)))
                    .willReturn(Optional.of(session));
            given(markingSpotService.getSessionSpots(10L)).willReturn(List.of());

            var response = walkService.unarchive(1L, 10L);

            assertThat(response.archived()).isFalse();
            assertThat(response.tracePathData()).isNull();
        }

        @Test
        @DisplayName("같은 가구원은 공유 산책의 보관을 해제할 수 있음")
        void householdMemberCanUnarchive() {
            WalkSession session = makeSession(10L, makeUser(2L), Status.COMPLETED);
            ReflectionTestUtils.setField(session, "householdId", 7L);
            session.archive("v1|70,530;860,-460");
            LocalDateTime joinedAt = session.getStartedAt().minusDays(1);
            given(householdService.findHouseholdIdByUserId(1L))
                    .willReturn(new HouseholdIdCache(7L, joinedAt));
            given(walkSessionRepository.findAccessibleById(
                    eq(10L), eq(1L), eq(7L), eq(joinedAt),
                    any(LocalDateTime.class), eq(Status.COMPLETED)))
                    .willReturn(Optional.of(session));
            given(markingSpotService.getSessionSpots(10L)).willReturn(List.of());

            var response = walkService.unarchive(1L, 10L);

            assertThat(response.archived()).isFalse();
            assertThat(response.ownerId()).isEqualTo(2L);
        }

        @Test
        @DisplayName("가구에 속하지 않은 사용자는 다른 사람의 산책 보관을 해제할 수 없음")
        void rejectsUnrelatedUserUnarchive() {
            given(walkSessionRepository.findAccessibleByOwnerId(
                    eq(10L), eq(1L), any(LocalDateTime.class), eq(Status.COMPLETED)))
                    .willReturn(Optional.empty());

            assertThatThrownBy(() -> walkService.unarchive(1L, 10L))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("산책 기록을 찾을 수 없습니다");
            verify(walkSessionRepository, never()).findAccessibleById(
                    any(), any(), any(), any(), any(), any());
        }
    }

    @Nested
    @DisplayName("complete")
    class Complete {

        @Test
        void completionDoesNotWaitForMarkingAnalysis() {
            WalkSession session = makeSession(10L, makeUser(1L), Status.IN_PROGRESS);
            given(walkSessionRepository.findByIdAndUserId(10L, 1L)).willReturn(Optional.of(session));

            var result = walkService.complete(1L, 10L,
                    new CompleteWalkRequest(LocalDateTime.now(), List.of()));

            assertThat(result.status()).isEqualTo(Status.COMPLETED);
            assertThat(result.markingSpotCandidates()).isEmpty();
            verifyNoInteractions(markingSpotService);
        }

        @Test
        void sustainedFastTravelDisablesMarkingWithoutDiscardingWalk() {
            WalkSession session = makeSession(10L, makeUser(1L), Status.IN_PROGRESS);
            given(walkSessionRepository.findByIdAndUserId(10L, 1L)).willReturn(Optional.of(session));
            LocalDateTime base = LocalDateTime.now().minusMinutes(2);
            List<WalkPointRequest> points = List.of(
                    new WalkPointRequest(base, 37.0, 127.0, null),
                    new WalkPointRequest(base.plusSeconds(5), 37.001, 127.0, null),
                    new WalkPointRequest(base.plusSeconds(10), 37.002, 127.0, null),
                    new WalkPointRequest(base.plusSeconds(15), 37.003, 127.0, null));

            walkService.complete(1L, 10L, new CompleteWalkRequest(LocalDateTime.now(), points));

            assertThat(session.getStatus()).isEqualTo(Status.COMPLETED);
            assertThat(session.isMarkingEligible()).isFalse();
            assertThat(walkService.getMarkingCandidates(1L, 10L)).isEmpty();
            verifyNoInteractions(markingSpotService);
        }

        @Test
        void singleGpsJumpDoesNotDisableMarking() {
            WalkSession session = makeSession(10L, makeUser(1L), Status.IN_PROGRESS);
            given(walkSessionRepository.findByIdAndUserId(10L, 1L)).willReturn(Optional.of(session));
            LocalDateTime base = LocalDateTime.now().minusMinutes(2);
            List<WalkPointRequest> points = List.of(
                    new WalkPointRequest(base, 37.0, 127.0, null),
                    new WalkPointRequest(base.plusSeconds(5), 37.001, 127.0, null),
                    new WalkPointRequest(base.plusSeconds(15), 37.00101, 127.0, null),
                    new WalkPointRequest(base.plusSeconds(25), 37.00102, 127.0, null));

            walkService.complete(1L, 10L, new CompleteWalkRequest(LocalDateTime.now(), points));

            assertThat(session.isMarkingEligible()).isTrue();
        }

        @Test
        void replayedCoordinateSequenceDisablesMarking() {
            WalkSession session = makeSession(10L, makeUser(1L), Status.IN_PROGRESS);
            given(walkSessionRepository.findByIdAndUserId(10L, 1L)).willReturn(Optional.of(session));
            given(walkSessionRepository.existsByUserIdAndRouteFingerprintAndStatusAndIdNot(
                    eq(1L), anyString(), eq(Status.COMPLETED), eq(10L))).willReturn(true);
            LocalDateTime base = LocalDateTime.now().minusMinutes(2);
            List<WalkPointRequest> points = java.util.stream.IntStream.range(0, 10)
                    .mapToObj(i -> new WalkPointRequest(base.plusSeconds(i * 15L),
                            37.0 + i * 0.00025, 127.0, null))
                    .toList();

            walkService.complete(1L, 10L, new CompleteWalkRequest(LocalDateTime.now(), points));

            assertThat(session.getRouteFingerprint()).hasSize(64);
            assertThat(session.isMarkingEligible()).isFalse();
        }

        @Test
        void walkingSameCourseAgainWithNewGpsSamplesKeepsMarking() {
            WalkSession first = makeSession(10L, makeUser(1L), Status.IN_PROGRESS);
            WalkSession second = makeSession(11L, first.getUser(), Status.IN_PROGRESS);
            given(walkSessionRepository.findByIdAndUserId(10L, 1L)).willReturn(Optional.of(first));
            given(walkSessionRepository.findByIdAndUserId(11L, 1L)).willReturn(Optional.of(second));
            LocalDateTime base = LocalDateTime.now().minusMinutes(8);
            List<WalkPointRequest> firstPoints = java.util.stream.IntStream.range(0, 10)
                    .mapToObj(i -> new WalkPointRequest(base.plusSeconds(i * 15L),
                            37.0 + i * 0.00025, 127.0, null))
                    .toList();
            walkService.complete(1L, 10L, new CompleteWalkRequest(base.plusMinutes(3), firstPoints));
            given(walkSessionRepository.existsByUserIdAndRouteFingerprintAndStatusAndIdNot(
                    eq(1L), anyString(), eq(Status.COMPLETED), eq(11L)))
                    .willAnswer(invocation -> first.getRouteFingerprint().equals(invocation.getArgument(1)));
            List<WalkPointRequest> secondPoints = java.util.stream.IntStream.range(0, 10)
                    .mapToObj(i -> new WalkPointRequest(base.plusMinutes(4).plusSeconds(i * 16L),
                            37.0 + i * 0.00025 + (i == 5 ? 0.000002 : 0), 127.0, null))
                    .toList();

            walkService.complete(1L, 11L, new CompleteWalkRequest(base.plusMinutes(7), secondPoints));

            assertThat(second.getRouteFingerprint()).isNotEqualTo(first.getRouteFingerprint());
            assertThat(second.isMarkingEligible()).isTrue();
        }

        @Test
        void candidatesAreCalculatedFromSavedPointsForOwner() {
            WalkSession session = makeSession(10L, makeUser(1L), Status.COMPLETED);
            WalkPoint point = mock(WalkPoint.class);
            given(point.getRecordedAt()).willReturn(LocalDateTime.of(2026, 11, 2, 12, 0));
            given(point.getLat()).willReturn(37.218);
            given(point.getLng()).willReturn(126.944);
            given(point.getAccuracy()).willReturn(null);
            given(walkSessionRepository.findByIdAndUserId(10L, 1L)).willReturn(Optional.of(session));
            given(walkPointRepository.findAllBySessionIdOrderByRecordedAt(10L)).willReturn(List.of(point));

            walkService.getMarkingCandidates(1L, 10L);

            verify(markingSpotService).detectCandidates(List.of(
                    new WalkPointRequest(point.getRecordedAt(), 37.218, 126.944, null)));
        }

        @Test
        void candidatesAreNotAvailableToAnotherUser() {
            assertThatThrownBy(() -> walkService.getMarkingCandidates(2L, 10L))
                    .isInstanceOf(BusinessException.class);
            verifyNoInteractions(walkPointRepository, markingSpotService);
        }

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
