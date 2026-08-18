package com.doggy.backend.domain.walk.dto;

import com.doggy.backend.domain.walk.entity.MarkingSpotVisit;

import java.time.LocalDateTime;

public record MarkingSpotVisitResponse(
        Long id,
        LocalDateTime visitedAt,
        DogInfo dog
) {
    public record DogInfo(Long id, String name, String breed, String profileImage) {}

    public static MarkingSpotVisitResponse from(MarkingSpotVisit visit) {
        return new MarkingSpotVisitResponse(
                visit.getId(),
                visit.getVisitedAt(),
                new DogInfo(
                        visit.getDog().getId(),
                        visit.getDog().getName(),
                        visit.getDog().getBreed(),
                        visit.getDog().getProfileImage()
                )
        );
    }
}
