package com.doggy.backend.domain.walk.dto;

import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;

import java.time.LocalDateTime;
import java.util.List;

public record WalkSessionResponse(
        Long id,
        LocalDateTime startedAt,
        LocalDateTime endedAt,
        int distanceMeters,
        int durationSeconds,
        Status status,
        List<DogInfo> dogs
) {
    public record DogInfo(Long id, String name, String breed, String profileImage) {}

    public static WalkSessionResponse from(WalkSession session) {
        List<DogInfo> dogInfos = session.getDogs().stream()
                .map(d -> new DogInfo(d.getId(), d.getName(), d.getBreed(), d.getProfileImage()))
                .toList();
        return new WalkSessionResponse(
                session.getId(),
                session.getStartedAt(),
                session.getEndedAt(),
                session.getDistanceMeters(),
                session.getDurationSeconds(),
                session.getStatus(),
                dogInfos
        );
    }
}
