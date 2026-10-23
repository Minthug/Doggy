package com.doggy.backend.domain.walk.service;

import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.repository.WalkPointRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class RouteCompressionSchedulerTest {

    @Mock WalkSessionRepository walkSessionRepository;
    @Mock WalkPointRepository walkPointRepository;
    @Mock WalkTracePathService walkTracePathService;
    @InjectMocks RouteCompressionScheduler scheduler;

    @Test
    void purgesGpsButKeepsCompactTracePathForArchivedWalk() {
        WalkSession session = WalkSession.builder()
                .user(User.builder().nickname("tester").build())
                .startedAt(LocalDateTime.now().minusDays(8))
                .build();
        ReflectionTestUtils.setField(session, "id", 10L);
        ReflectionTestUtils.setField(session, "status", WalkSession.Status.COMPLETED);
        ReflectionTestUtils.setField(session, "isArchived", true);
        session.saveRouteGeoJson(
                "{\"type\":\"LineString\",\"coordinates\":[[127.1,37.5],[127.2,37.6]]}");

        given(walkSessionRepository
                .findTop100ByStatusAndStartedAtBeforeAndDetailsPurgedAtIsNullOrderByStartedAtAsc(
                        any(WalkSession.Status.class), any(LocalDateTime.class)))
                .willReturn(List.of(session), List.of());
        given(walkTracePathService.createPathData(any())).willReturn("v1|70,530;860,-460");

        scheduler.purgeExpiredWalkDetails();

        verify(walkPointRepository).deleteAllBySessionId(10L);
        assertThat(session.getRouteGeoJson()).isNull();
        assertThat(session.getDetailsPurgedAt()).isNotNull();
        assertThat(session.getTracePathData()).isEqualTo("v1|70,530;860,-460");
        assertThat(session.isPublic()).isFalse();
    }
}
