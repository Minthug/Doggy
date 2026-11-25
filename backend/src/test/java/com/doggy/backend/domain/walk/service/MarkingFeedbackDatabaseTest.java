package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.household.dto.HouseholdIdCache;
import com.doggy.backend.domain.household.entity.Household;
import com.doggy.backend.domain.household.repository.HouseholdRepository;
import com.doggy.backend.domain.household.service.HouseholdService;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.domain.walk.dto.MarkingCandidateAnswer;
import com.doggy.backend.domain.walk.dto.MarkingCandidateFeedbackRequest;
import com.doggy.backend.domain.walk.dto.MarkingSpotCandidateResponse;
import com.doggy.backend.domain.walk.entity.MarkingCandidateFeedback;
import com.doggy.backend.domain.walk.entity.MarkingSpot;
import com.doggy.backend.domain.walk.entity.MarkingSpotVisit;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.repository.MarkingCandidateFeedbackRepository;
import com.doggy.backend.domain.walk.repository.MarkingCandidateFeedbackRepository.CandidateVoteCount;
import com.doggy.backend.domain.walk.repository.MarkingSpotVisitRepository;
import com.doggy.backend.domain.walk.repository.MarkingSpotRepository;
import com.doggy.backend.domain.walk.repository.TrafficMapFeatureRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import com.doggy.backend.global.config.QueryDslConfig;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import({MarkingSpotService.class, QueryDslConfig.class})
@TestPropertySource(properties = "spring.jpa.hibernate.ddl-auto=validate")
@Transactional(propagation = Propagation.NOT_SUPPORTED)
@EnabledIfEnvironmentVariable(
        named = "DOGGY_MARKING_TEST_DB_URL",
        matches = "jdbc:postgresql://(localhost|127\\.0\\.0\\.1):[0-9]+/doggy_marking_feedback_test")
class MarkingFeedbackDatabaseTest {

    @DynamicPropertySource
    static void database(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> System.getenv("DOGGY_MARKING_TEST_DB_URL"));
        registry.add("spring.datasource.username", () -> "doggy");
        registry.add("spring.datasource.password", () -> "doggy");
    }

    @Autowired UserRepository userRepository;
    @Autowired DogRepository dogRepository;
    @Autowired HouseholdRepository householdRepository;
    @Autowired WalkSessionRepository walkSessionRepository;
    @Autowired MarkingCandidateFeedbackRepository feedbackRepository;
    @Autowired MarkingSpotVisitRepository visitRepository;
    @Autowired MarkingSpotRepository spotRepository;
    @Autowired MarkingSpotService service;
    @MockitoBean HouseholdService householdService;
    @MockitoBean TrafficMapFeatureRepository trafficMapFeatureRepository;

    @Test
    void popularSpotCountsDistinctDogsWithinTwoKilometers() {
        User user = userRepository.save(User.builder().nickname("popular-spot-test").build());
        double lat = 35 + (user.getId() % 100) * 0.1;
        Dog firstDog = dogRepository.save(Dog.builder().user(user).name("보리").build());
        Dog secondDog = dogRepository.save(Dog.builder().user(user).name("두부").build());
        Dog thirdDog = dogRepository.save(Dog.builder().user(user).name("콩이").build());
        Dog fourthDog = dogRepository.save(Dog.builder().user(user).name("호두").build());
        LocalDateTime time = LocalDateTime.of(2026, 11, 3, 12, 0);
        WalkSession firstWalk = walkSessionRepository.save(WalkSession.builder().user(user).startedAt(time).build());
        WalkSession secondWalk = walkSessionRepository.save(WalkSession.builder().user(user).startedAt(time.plusDays(1)).build());
        MarkingSpot twoDogs = spotRepository.save(MarkingSpot.builder()
                .lat(lat).lng(126.945).gridKey(UUID.randomUUID().toString()).build());
        MarkingSpot repeatDog = spotRepository.save(MarkingSpot.builder()
                .lat(lat + 0.001).lng(126.945).gridKey(UUID.randomUUID().toString()).build());
        MarkingSpot farAway = spotRepository.save(MarkingSpot.builder()
                .lat(lat + 0.032).lng(126.945).gridKey(UUID.randomUUID().toString()).build());

        visitRepository.save(MarkingSpotVisit.builder().spot(twoDogs).session(firstWalk)
                .dog(firstDog).user(user).visitedAt(time).build());
        visitRepository.save(MarkingSpotVisit.builder().spot(twoDogs).session(firstWalk)
                .dog(secondDog).user(user).visitedAt(time).build());
        visitRepository.save(MarkingSpotVisit.builder().spot(repeatDog).session(firstWalk)
                .dog(firstDog).user(user).visitedAt(time).build());
        visitRepository.save(MarkingSpotVisit.builder().spot(repeatDog).session(secondWalk)
                .dog(firstDog).user(user).visitedAt(time.plusDays(1)).build());
        visitRepository.save(MarkingSpotVisit.builder().spot(farAway).session(firstWalk)
                .dog(firstDog).user(user).visitedAt(time).build());
        visitRepository.save(MarkingSpotVisit.builder().spot(farAway).session(firstWalk)
                .dog(thirdDog).user(user).visitedAt(time).build());
        visitRepository.save(MarkingSpotVisit.builder().spot(farAway).session(firstWalk)
                .dog(fourthDog).user(user).visitedAt(time).build());

        var popular = service.getMostMarkedNear(lat, 126.945).orElseThrow();
        assertThat(popular.id()).isEqualTo(twoDogs.getId());
        assertThat(popular.dogCount()).isEqualTo(2);
    }

    @Test
    void positiveAndNegativeAnswersCommitButOnlyPositiveCreatesSpot() {
        User user = userRepository.save(User.builder().nickname("marking-feedback-test").build());
        Dog dog = dogRepository.save(Dog.builder().user(user).name("보리").build());
        LocalDateTime time = LocalDateTime.of(2026, 11, 3, 12, 0);
        WalkSession session = WalkSession.builder().user(user).startedAt(time).build();
        session.complete(time.plusMinutes(20), 1000, 1200);
        session.setMarkingRouteQuality("a".repeat(64), true);
        walkSessionRepository.save(session);
        double lat = 37.0 + (user.getId() % 1000) * 0.001;
        double lng = 126.0 + (user.getId() / 1000 % 1000) * 0.001;
        assertThat(walkSessionRepository.existsByUserIdAndRouteFingerprintAndStatusAndIdNot(
                user.getId(), "a".repeat(64), WalkSession.Status.COMPLETED, -1L)).isTrue();
        assertThat(walkSessionRepository.existsByUserIdAndRouteFingerprintAndStatusAndIdNot(
                user.getId(), "a".repeat(64), WalkSession.Status.COMPLETED, session.getId())).isFalse();
        given(householdService.findHouseholdIdByUserId(user.getId()))
                .willReturn(new HouseholdIdCache(null, null));

        var yes = new MarkingSpotCandidateResponse("a", lat, lng, time.plusMinutes(5), 15, 0, 6, "STAY");
        var no = new MarkingSpotCandidateResponse("b", lat + 0.01, lng, time.plusMinutes(10), 30, 0, 4, "GAP");
        var request = new MarkingCandidateFeedbackRequest(
                List.of(new MarkingCandidateAnswer("a", true), new MarkingCandidateAnswer("b", false)),
                List.of(dog.getId()));
        service.submitFeedback(user.getId(), session.getId(), request, List.of(yes, no));
        service.submitFeedback(user.getId(), session.getId(), request, List.of());

        List<MarkingCandidateFeedback> feedback = feedbackRepository.findAllBySessionId(session.getId());
        assertThat(feedback).hasSize(2);
        assertThat(feedback).extracting(MarkingCandidateFeedback::isMarked).containsExactlyInAnyOrder(true, false);
        var visits = visitRepository.findAllBySessionIdOrderByCreatedAtDesc(session.getId());
        assertThat(visits).hasSize(1);
        assertThat(visits.getFirst().getSpot().getVisitCount()).isEqualTo(1);
    }

    @Test
    void voteCountsUseLatestAnswerPerUserAndIgnoreIneligibleWalks() {
        String key = "vote-" + UUID.randomUUID();
        User repeatUser = userRepository.save(User.builder().nickname("repeat-voter").build());
        User secondUser = userRepository.save(User.builder().nickname("second-voter").build());
        User thirdUser = userRepository.save(User.builder().nickname("third-voter").build());
        User ineligibleUser = userRepository.save(User.builder().nickname("ineligible-voter").build());
        saveVote(repeatUser, key, true, true);
        saveVote(repeatUser, key, false, true);
        saveVote(secondUser, key, true, true);
        saveVote(thirdUser, key, true, true);
        saveVote(ineligibleUser, key, true, false);

        List<CandidateVoteCount> counts = feedbackRepository.findVoteCounts(List.of(key));

        assertThat(counts).hasSize(1);
        assertThat(counts.getFirst().getPositiveCount()).isEqualTo(2);
        assertThat(counts.getFirst().getTotalCount()).isEqualTo(3);
    }

    @Test
    void walkAccessQueryHandlesMissingHouseholdAndJoinTime() {
        User owner = userRepository.save(User.builder().nickname("walk-query-owner").build());
        User member = userRepository.save(User.builder().nickname("walk-query-member").build());
        Household household = householdRepository.save(Household.builder().name("walk-query-household").build());
        LocalDateTime startedAt = LocalDateTime.now();
        WalkSession session = WalkSession.builder().user(owner).householdId(household.getId()).startedAt(startedAt).build();
        session.complete(startedAt.plusMinutes(5), 300, 300);
        walkSessionRepository.save(session);

        assertThat(walkSessionRepository.findAccessibleById(session.getId(), owner.getId(),
                null, null, startedAt.minusDays(1), WalkSession.Status.COMPLETED)).isPresent();
        assertThat(walkSessionRepository.findAccessibleById(session.getId(), member.getId(),
                household.getId(), startedAt.minusMinutes(1), startedAt.minusDays(1), WalkSession.Status.COMPLETED)).isPresent();
        assertThat(walkSessionRepository.findAccessibleById(session.getId(), member.getId(),
                household.getId(), startedAt.plusMinutes(1), startedAt.minusDays(1), WalkSession.Status.COMPLETED)).isEmpty();
    }

    private void saveVote(User user, String key, boolean marked, boolean eligible) {
        LocalDateTime time = LocalDateTime.of(2026, 11, 3, 12, 0);
        WalkSession session = WalkSession.builder().user(user).startedAt(time).build();
        session.complete(time.plusMinutes(20), 1000, 1200);
        session.setMarkingRouteQuality(null, eligible);
        walkSessionRepository.save(session);
        feedbackRepository.save(new MarkingCandidateFeedback(session, key, time.plusMinutes(5),
                15, 6, "STAY", marked));
    }
}
