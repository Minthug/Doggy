package com.doggy.backend.domain.walk.dto;

import java.util.List;

public record WalkTraceDiscoveryResponse(
        Long sessionId,
        Recency recency,
        String routeGeoJson,
        List<DogInfo> dogs
) {
    public enum Recency {
        TODAY,
        WITHIN_THREE_DAYS
    }

    public record DogInfo(
            Long id,
            String name,
            String breed,
            String profileImage
    ) {}
}
