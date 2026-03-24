package com.doggy.backend.domain.place.dto;

import com.doggy.backend.domain.place.entity.Place;
import com.doggy.backend.domain.place.entity.Place.Category;
import com.doggy.backend.domain.place.entity.Place.Source;

public record PlaceResponse(
        Long id,
        String name,
        Category category,
        String address,
        double lat,
        double lng,
        String phone,
        boolean isOpen24h,
        boolean isEmergency,
        boolean allowsDogs,
        Source source,
        boolean isVerified,
        long helpfulCount
) {
    public static PlaceResponse of(Place place, long helpfulCount) {
        return new PlaceResponse(
                place.getId(),
                place.getName(),
                place.getCategory(),
                place.getAddress(),
                place.getLat(),
                place.getLng(),
                place.getPhone(),
                place.isOpen24h(),
                place.isEmergency(),
                place.isAllowsDogs(),
                place.getSource(),
                place.isVerified(),
                helpfulCount
        );
    }
}
