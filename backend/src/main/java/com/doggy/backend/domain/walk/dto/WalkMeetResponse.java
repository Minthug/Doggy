package com.doggy.backend.domain.walk.dto;

import com.doggy.backend.domain.dog.entity.Dog;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

public record WalkMeetResponse(
        LocalDateTime metAt,
        UserInfo user,
        List<DogInfo> dogs
) {
    public record UserInfo(
            Long id,
            String nickname,
            String profileImage
    ) {}

    public record DogInfo(
            Long id,
            String name,
            String breed,
            String profileImage,
            Set<Dog.DogWarning> warnings
    ) {}
}
