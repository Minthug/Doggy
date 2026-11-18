package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.domain.walk.entity.WalkPoint;
import com.doggy.backend.domain.walk.entity.WalkSession;
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

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(QueryDslConfig.class)
@TestPropertySource(properties = "spring.jpa.hibernate.ddl-auto=validate")
@EnabledIfEnvironmentVariable(
        named = "DOGGY_MARKING_TEST_DB_URL",
        matches = "jdbc:postgresql://(localhost|127\\.0\\.0\\.1):[0-9]+/doggy_marking_feedback_test")
class WalkPointSegmentsDatabaseTest {

    @DynamicPropertySource
    static void database(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> System.getenv("DOGGY_MARKING_TEST_DB_URL"));
        registry.add("spring.datasource.username", () -> "doggy");
        registry.add("spring.datasource.password", () -> "doggy");
    }

    @Autowired UserRepository userRepository;
    @Autowired WalkSessionRepository walkSessionRepository;
    @Autowired WalkPointRepository walkPointRepository;

    @Test
    void pauseGapIsNeitherRenderedAsALineNorDiscoveredAsAnotherWalk() {
        LocalDateTime now = LocalDateTime.now();
        WalkSession target = session("paused-target", now, false);
        points(target, now,
                new double[][]{{37.0, 127.0}, {37.0, 127.001},
                        {37.01, 127.01}, {37.01, 127.011}}, 2);

        String route = walkPointRepository.findRouteGeoJsonBySessionId(target.getId());
        assertThat(route).contains("MultiLineString");
        assertThat(walkPointRepository.findRouteGeoJsonBySessionIds(List.of(target.getId())))
                .hasSize(1);

        WalkSession gapOnly = session("gap-only", now.minusMinutes(1), true);
        points(gapOnly, now.minusMinutes(1),
                new double[][]{{37.005, 127.005}, {37.005, 127.0052}}, -1);
        WalkSession nearSegment = session("near-segment", now.minusMinutes(1), true);
        points(nearSegment, now.minusMinutes(1),
                new double[][]{{37.0, 127.0002}, {37.0, 127.0004}}, -1);

        List<Long> discoveries = walkPointRepository.findNearbyPublicTraceSessionIds(target.getId(), 80.0, 30);
        assertThat(discoveries).contains(nearSegment.getId()).doesNotContain(gapOnly.getId());
    }

    private WalkSession session(String nickname, LocalDateTime startedAt, boolean published) {
        User user = userRepository.save(User.builder().nickname(nickname).build());
        WalkSession session = WalkSession.builder().user(user).startedAt(startedAt).build();
        session.complete(startedAt.plusMinutes(5), 100, 300);
        if (published) session.makePublic(nickname);
        return walkSessionRepository.save(session);
    }

    private void points(WalkSession session, LocalDateTime firstAt, double[][] coordinates, int newSegmentIndex) {
        for (int i = 0; i < coordinates.length; i++) {
            walkPointRepository.save(WalkPoint.builder()
                    .session(session)
                    .recordedAt(firstAt.plusSeconds(i * 10L))
                    .lat(coordinates[i][0])
                    .lng(coordinates[i][1])
                    .accuracy(5f)
                    .segmentStart(i == newSegmentIndex)
                    .build());
        }
        walkPointRepository.flush();
    }
}
