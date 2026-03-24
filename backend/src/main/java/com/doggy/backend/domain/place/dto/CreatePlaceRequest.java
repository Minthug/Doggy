package com.doggy.backend.domain.place.dto;

import com.doggy.backend.domain.place.entity.Place.Category;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record CreatePlaceRequest(

        @NotBlank
        String name,

        @NotNull
        Category category,

        String address,

        @NotNull
        Double lat,

        @NotNull
        Double lng,

        String phone,
        boolean isOpen24h,
        boolean isEmergency,
        boolean allowsDogs
) {}
