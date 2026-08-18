package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.household.service.HouseholdService;
import com.doggy.backend.domain.walk.dto.MarkingSpotCandidateResponse;
import com.doggy.backend.domain.walk.dto.WalkPointRequest;
import com.doggy.backend.domain.walk.repository.MarkingSpotRepository;
import com.doggy.backend.domain.walk.repository.MarkingSpotVisitRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.BDDMockito.given;

@ExtendWith(MockitoExtension.class)
class MarkingSpotServiceTest {

    @Mock MarkingSpotRepository spotRepository;
    @Mock MarkingSpotVisitRepository visitRepository;
    @Mock WalkSessionRepository walkSessionRepository;
    @Mock DogRepository dogRepository;
    @Mock HouseholdService householdService;

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

    private MarkingSpotService service() {
        return new MarkingSpotService(
                spotRepository,
                visitRepository,
                walkSessionRepository,
                dogRepository,
                householdService
        );
    }

    private WalkPointRequest point(LocalDateTime recordedAt, double lat, double lng) {
        return new WalkPointRequest(recordedAt, lat, lng, null);
    }
}
