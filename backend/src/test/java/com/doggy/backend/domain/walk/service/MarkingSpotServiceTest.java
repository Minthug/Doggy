package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.household.dto.HouseholdIdCache;
import com.doggy.backend.domain.household.service.HouseholdService;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.walk.dto.MarkingSpotCandidateResponse;
import com.doggy.backend.domain.walk.dto.MarkingCandidateAnswer;
import com.doggy.backend.domain.walk.dto.MarkingCandidateFeedbackRequest;
import com.doggy.backend.domain.walk.dto.MarkingSpotResponse;
import com.doggy.backend.domain.walk.dto.CreateMarkingSpotVisitRequest;
import com.doggy.backend.domain.walk.dto.WalkPointRequest;
import com.doggy.backend.domain.walk.entity.MarkingCandidateFeedback;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.repository.MarkingSpotRepository;
import com.doggy.backend.domain.walk.repository.MarkingCandidateFeedbackRepository;
import com.doggy.backend.domain.walk.repository.MarkingCandidateFeedbackRepository.CandidateVoteCount;
import com.doggy.backend.domain.walk.repository.MarkingSpotVisitRepository;
import com.doggy.backend.domain.walk.repository.TrafficMapFeatureRepository;
import com.doggy.backend.domain.walk.repository.TrafficMapFeatureRepository.TrafficCoordinate;
import com.doggy.backend.domain.walk.repository.TrafficMapFeatureRepository.TrafficContext;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.ArgumentCaptor;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.spy;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class MarkingSpotServiceTest {

    @Mock MarkingSpotRepository spotRepository;
    @Mock MarkingCandidateFeedbackRepository feedbackRepository;
    @Mock MarkingSpotVisitRepository visitRepository;
    @Mock WalkSessionRepository walkSessionRepository;
    @Mock DogRepository dogRepository;
    @Mock HouseholdService householdService;
    @Mock TrafficMapFeatureRepository trafficMapFeatureRepository;

    @Test
    void detectsCandidateWhenRouteStopsAndMovesAgain() {
        MarkingSpotService service = service();
        given(spotRepository.findAllByGridKeyIn(anyCollection())).willReturn(List.of());
        LocalDateTime base = LocalDateTime.now();

        List<WalkPointRequest> points = List.of(
                point(base, 37.218000, 126.944000),
                point(base.plusSeconds(5), 37.218160, 126.944000),
                point(base.plusSeconds(10), 37.218170, 126.944005),
                point(base.plusSeconds(18), 37.218172, 126.944004),
                point(base.plusSeconds(28), 37.218171, 126.944006),
                point(base.plusSeconds(36), 37.218330, 126.944000)
        );

        List<MarkingSpotCandidateResponse> candidates = service.detectCandidates(points);

        assertThat(candidates).hasSize(1);
        assertThat(candidates.get(0).dwellSeconds()).isGreaterThanOrEqualTo(12);
    }

    @Test
    void doesNotDetectCandidateWhenRouteOnlyMoves() {
        MarkingSpotService service = service();
        LocalDateTime base = LocalDateTime.now();

        List<WalkPointRequest> points = List.of(
                point(base, 37.218000, 126.944000),
                point(base.plusSeconds(5), 37.218120, 126.944000),
                point(base.plusSeconds(10), 37.218240, 126.944000),
                point(base.plusSeconds(15), 37.218360, 126.944000)
        );

        List<MarkingSpotCandidateResponse> candidates = service.detectCandidates(points);

        assertThat(candidates).isEmpty();
    }

    @Test
    void doesNotTreatFifteenMeterGpsUpdatesEveryTenSecondsAsStops() {
        MarkingSpotService service = service();
        LocalDateTime base = LocalDateTime.of(2026, 11, 3, 12, 0);
        List<WalkPointRequest> points = List.of(
                point(base, 37.218000, 126.944),
                point(base.plusSeconds(10), 37.218135, 126.944),
                point(base.plusSeconds(20), 37.218270, 126.944),
                point(base.plusSeconds(30), 37.218405, 126.944));

        assertThat(service.detectCandidates(points)).isEmpty();
    }

    @Test
    void slowGapBetweenMovementCanStillBeReviewed() {
        MarkingSpotService service = service();
        given(spotRepository.findAllByGridKeyIn(anyCollection())).willReturn(List.of());
        LocalDateTime base = LocalDateTime.of(2026, 11, 3, 12, 0);
        List<WalkPointRequest> points = List.of(
                point(base, 37.218000, 126.944),
                point(base.plusSeconds(5), 37.218160, 126.944),
                point(base.plusSeconds(35), 37.218295, 126.944),
                point(base.plusSeconds(40), 37.218455, 126.944));

        assertThat(service.detectCandidates(points)).hasSize(1);
    }

    @Test
    void storesBothAnswersAndCreatesVisitOnlyForConfirmedCandidate() {
        MarkingSpotService service = spy(service());
        WalkSession session = mock(WalkSession.class);
        given(session.getStatus()).willReturn(WalkSession.Status.COMPLETED);
        given(walkSessionRepository.findByIdAndUserId(7L, 9L)).willReturn(Optional.of(session));
        LocalDateTime time = LocalDateTime.of(2026, 11, 3, 12, 0);
        var yes = new MarkingSpotCandidateResponse("a", 37.218, 126.944, time, 15, 0, 6, "STAY");
        var no = new MarkingSpotCandidateResponse("b", 37.219, 126.944, time.plusMinutes(1), 30, 0, 4, "GAP");
        doReturn(new MarkingSpotResponse(1L, yes.lat(), yes.lng(), 1, time))
                .when(service).createVisit(anyLong(), anyLong(), any());

        service.submitFeedback(9L, 7L, new MarkingCandidateFeedbackRequest(List.of(
                new MarkingCandidateAnswer("a", true), new MarkingCandidateAnswer("b", false)),
                List.of(3L)), List.of(yes, no));

        ArgumentCaptor<MarkingCandidateFeedback> saved = ArgumentCaptor.forClass(MarkingCandidateFeedback.class);
        verify(feedbackRepository, times(2)).save(saved.capture());
        assertThat(saved.getAllValues()).extracting(MarkingCandidateFeedback::isMarked)
                .containsExactly(true, false);
        assertThat(saved.getAllValues()).extracting(MarkingCandidateFeedback::getSource)
                .containsExactly("STAY", "GAP");
        verify(service).createVisit(eq(9L), eq(7L), argThat(request ->
                request.lat().equals(yes.lat()) && request.lng().equals(yes.lng())
                        && request.dogIds().equals(List.of(3L))));
    }

    @Test
    void rejectsVisitOutsideSuggestedCandidates() {
        var request = new CreateMarkingSpotVisitRequest(37.218, 126.944,
                LocalDateTime.of(2026, 11, 3, 12, 0), List.of(3L));

        assertThatThrownBy(() -> service().createVisit(9L, 7L, request, List.of()))
                .hasMessageContaining("산책에서 확인된 마킹 후보가 아닙니다");
    }

    @Test
    void rejectsFourthDistinctSpotInOneWalk() {
        WalkSession session = mock(WalkSession.class);
        Dog dog = mock(Dog.class);
        User user = mock(User.class);
        given(session.getStatus()).willReturn(WalkSession.Status.COMPLETED);
        given(walkSessionRepository.findByIdAndUserId(7L, 9L)).willReturn(Optional.of(session));
        given(householdService.findHouseholdIdByUserId(9L))
                .willReturn(new HouseholdIdCache(null, null));
        given(dogRepository.findAllById(anyCollection())).willReturn(List.of(dog));
        given(dog.getUser()).willReturn(user);
        given(user.getId()).willReturn(9L);
        given(visitRepository.countDistinctSpotsBySessionId(7L)).willReturn(3L);
        var request = new CreateMarkingSpotVisitRequest(37.218, 126.944,
                LocalDateTime.of(2026, 11, 3, 12, 0), List.of(3L));

        assertThatThrownBy(() -> service().createVisit(9L, 7L, request))
                .hasMessageContaining("최대 3곳");
    }

    @Test
    void detectsShortMarkingStopFromStationarySamples() {
        MarkingSpotService service = service();
        given(spotRepository.findAllByGridKeyIn(anyCollection())).willReturn(List.of());
        LocalDateTime base = LocalDateTime.now();

        List<WalkPointRequest> points = List.of(
                point(base, 37.218000, 126.944000),
                point(base.plusSeconds(5), 37.218160, 126.944000),
                point(base.plusSeconds(10), 37.218161, 126.944001),
                point(base.plusSeconds(15), 37.218160, 126.944001),
                point(base.plusSeconds(20), 37.218320, 126.944000)
        );

        List<MarkingSpotCandidateResponse> candidates = service.detectCandidates(points);

        assertThat(candidates).hasSize(1);
        assertThat(candidates.get(0).dwellSeconds()).isBetween(8, 120);
    }

    @Test
    void nearbyStopsKeepHigherScoredShorterCandidate() {
        MarkingSpotService service = service();
        given(spotRepository.findAllByGridKeyIn(anyCollection())).willReturn(List.of());
        LocalDateTime base = LocalDateTime.of(2026, 11, 3, 12, 0);
        List<WalkPointRequest> points = List.of(
                point(base, 37.218000, 126.944),
                point(base.plusSeconds(5), 37.218160, 126.944),
                point(base.plusSeconds(20), 37.218160, 126.944),
                point(base.plusSeconds(25), 37.218340, 126.944),
                point(base.plusSeconds(125), 37.218340, 126.944),
                point(base.plusSeconds(130), 37.218500, 126.944));

        List<MarkingSpotCandidateResponse> candidates = service.detectCandidates(points);

        assertThat(candidates).hasSize(1);
        assertThat(candidates.getFirst().dwellSeconds()).isEqualTo(15);
        assertThat(candidates.getFirst().score()).isEqualTo(6);
        assertThat(candidates.getFirst().detectedAt()).isEqualTo(base.plusSeconds(12));
    }

    @Test
    void independentPositiveFeedbackAddsOnePointBeforeTopThreeSelection() {
        MarkingSpotService service = service();
        given(spotRepository.findAllByGridKeyIn(anyCollection())).willReturn(List.of());
        CandidateVoteCount votes = mock(CandidateVoteCount.class);
        given(votes.getCandidateKey()).willReturn(gridKey(37.219160, 126.944));
        given(votes.getPositiveCount()).willReturn(3L);
        given(votes.getTotalCount()).willReturn(4L);
        given(feedbackRepository.findVoteCounts(anyCollection())).willReturn(List.of(votes));
        LocalDateTime base = LocalDateTime.of(2026, 11, 3, 12, 0);

        List<MarkingSpotCandidateResponse> candidates = service.detectCandidates(twoSeparatedStops(base));

        assertThat(candidates).hasSize(2);
        assertThat(candidates.getFirst().detectedAt()).isEqualTo(base.plusSeconds(42));
        assertThat(candidates.getFirst().score()).isEqualTo(7);
        verify(feedbackRepository, times(1)).findVoteCounts(anyCollection());
    }

    @Test
    void negativeFeedbackPreventsPopularityBonus() {
        MarkingSpotService service = service();
        given(spotRepository.findAllByGridKeyIn(anyCollection())).willReturn(List.of());
        CandidateVoteCount votes = mock(CandidateVoteCount.class);
        given(votes.getCandidateKey()).willReturn(gridKey(37.219160, 126.944));
        given(votes.getPositiveCount()).willReturn(3L);
        given(votes.getTotalCount()).willReturn(6L);
        given(feedbackRepository.findVoteCounts(anyCollection())).willReturn(List.of(votes));
        LocalDateTime base = LocalDateTime.of(2026, 11, 3, 12, 0);

        List<MarkingSpotCandidateResponse> candidates = service.detectCandidates(twoSeparatedStops(base));

        assertThat(candidates).hasSize(2);
        assertThat(candidates.getFirst().detectedAt()).isEqualTo(base.plusSeconds(12));
        assertThat(candidates.get(1).score()).isEqualTo(6);
    }

    @Test
    void ignoresLongBreakAndInaccurateGpsAsMarking() {
        MarkingSpotService service = service();
        LocalDateTime base = LocalDateTime.now();

        List<WalkPointRequest> points = List.of(
                point(base, 37.218000, 126.944000),
                point(base.plusSeconds(5), 37.218160, 126.944000),
                point(base.plusSeconds(155), 37.218161, 126.944001),
                new WalkPointRequest(base.plusSeconds(160), 37.218162, 126.944002, 80f),
                point(base.plusSeconds(165), 37.218320, 126.944000)
        );

        assertThat(service.detectCandidates(points)).isEmpty();
    }

    @Test
    void returnsThreeCandidatesOnFiveKilometerRoute() {
        MarkingSpotService service = service();
        given(spotRepository.findAllByGridKeyIn(anyCollection())).willReturn(List.of());
        LocalDateTime base = LocalDateTime.now();
        List<WalkPointRequest> points = fiveKilometerRouteWithStops(base, 15);

        List<MarkingSpotCandidateResponse> candidates = service.detectCandidates(points);

        assertThat(candidates).hasSize(3);
        assertThat(candidates).allSatisfy(candidate ->
                assertThat(candidate.dwellSeconds()).isGreaterThanOrEqualTo(12));
        verify(trafficMapFeatureRepository, times(1)).findContexts(anyList());
    }

    @Test
    void trafficFacilitiesLowerRankButDoNotDiscardCandidate() {
        MarkingSpotService service = service();
        given(spotRepository.findAllByGridKeyIn(anyCollection())).willReturn(List.of());
        given(trafficMapFeatureRepository.findContexts(anyList()))
                .willReturn(List.of(new TrafficContext(true, true, true, true, false)));
        LocalDateTime base = LocalDateTime.now();

        List<WalkPointRequest> points = List.of(
                point(base, 37.218000, 126.944000),
                point(base.plusSeconds(5), 37.218160, 126.944000),
                point(base.plusSeconds(15), 37.218160, 126.944000),
                point(base.plusSeconds(20), 37.218320, 126.944000)
        );

        assertThat(service.detectCandidates(points)).hasSize(1);
    }

    @Test
    void trafficQueryFailureIsNotSilentlyTreatedAsNeutral() {
        MarkingSpotService service = service();
        given(trafficMapFeatureRepository.findContexts(anyList()))
                .willThrow(new IllegalStateException("traffic table missing"));
        LocalDateTime base = LocalDateTime.of(2026, 11, 2, 12, 0);
        List<WalkPointRequest> points = List.of(
                point(base, 37.218000, 126.944000),
                point(base.plusSeconds(5), 37.218160, 126.944000),
                point(base.plusSeconds(15), 37.218160, 126.944000),
                point(base.plusSeconds(20), 37.218320, 126.944000)
        );

        assertThatThrownBy(() -> service.detectCandidates(points))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("traffic table missing");
    }

    @Test
    void walkingAreaCandidateSurvivesWhenMoreThanThreeStopsExist() {
        MarkingSpotService service = service();
        given(spotRepository.findAllByGridKeyIn(anyCollection())).willReturn(List.of());
        given(trafficMapFeatureRepository.findContexts(anyList())).willAnswer(invocation -> {
            List<TrafficCoordinate> coordinates = invocation.getArgument(0);
            return coordinates.stream().map(coordinate -> coordinate.lat() > 37.233
                    ? new TrafficContext(false, false, false, false, true)
                    : new TrafficContext(true, true, true, true, false)).toList();
        });

        LocalDateTime time = LocalDateTime.of(2026, 11, 2, 12, 0);
        List<WalkPointRequest> points = new ArrayList<>();
        LocalDateTime parkStop = null;
        for (int i = 0; i < 16; i++) {
            double lat = 37.218 + i * 0.001;
            points.add(point(time, lat - 0.0002, 126.944));
            time = time.plusSeconds(5);
            points.add(point(time, lat, 126.944));
            if (i == 15) parkStop = time.plusSeconds(15);
            time = time.plusSeconds(i == 15 ? 30 : 10);
            points.add(point(time, lat, 126.944));
            time = time.plusSeconds(5);
            points.add(point(time, lat + 0.0002, 126.944));
            time = time.plusSeconds(5);
        }

        List<MarkingSpotCandidateResponse> candidates = service.detectCandidates(points);

        assertThat(candidates).hasSize(3);
        assertThat(candidates).extracting(MarkingSpotCandidateResponse::detectedAt)
                .contains(parkStop);
    }

    private MarkingSpotService service() {
        return new MarkingSpotService(
                spotRepository,
                feedbackRepository,
                visitRepository,
                walkSessionRepository,
                dogRepository,
                householdService,
                trafficMapFeatureRepository
        );
    }

    private WalkPointRequest point(LocalDateTime recordedAt, double lat, double lng) {
        return new WalkPointRequest(recordedAt, lat, lng, null);
    }

    private String gridKey(double lat, double lng) {
        return Math.round(lat / 0.0003) + ":" + Math.round(lng / 0.0003);
    }

    private List<WalkPointRequest> twoSeparatedStops(LocalDateTime base) {
        return List.of(
                point(base, 37.218000, 126.944),
                point(base.plusSeconds(5), 37.218160, 126.944),
                point(base.plusSeconds(20), 37.218160, 126.944),
                point(base.plusSeconds(25), 37.218320, 126.944),
                point(base.plusSeconds(30), 37.219000, 126.944),
                point(base.plusSeconds(35), 37.219160, 126.944),
                point(base.plusSeconds(50), 37.219160, 126.944),
                point(base.plusSeconds(55), 37.219320, 126.944));
    }

    private List<WalkPointRequest> fiveKilometerRouteWithStops(LocalDateTime base, int stopCount) {
        List<WalkPointRequest> points = new java.util.ArrayList<>();
        double startLat = 37.218000;
        double lng = 126.944000;
        double latStep = 0.0030; // 약 333m, 15구간이면 약 5km
        LocalDateTime t = base;

        points.add(point(t, startLat, lng));
        for (int i = 1; i <= stopCount; i++) {
            double lat = startLat + latStep * i;
            double approachLat = lat - 0.00020;
            double exitLat = lat + 0.00020;

            t = t.plusSeconds(30);
            points.add(point(t, approachLat, lng));
            t = t.plusSeconds(5);
            points.add(point(t, lat, lng));
            t = t.plusSeconds(8);
            points.add(point(t, lat + 0.00001, lng + 0.00001));
            t = t.plusSeconds(8);
            points.add(point(t, lat - 0.00001, lng - 0.00001));
            t = t.plusSeconds(5);
            points.add(point(t, exitLat, lng));
        }
        points.add(point(t.plusSeconds(30), startLat + latStep * (stopCount + 1), lng));
        return points;
    }
}
