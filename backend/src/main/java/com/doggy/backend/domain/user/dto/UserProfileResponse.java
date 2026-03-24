package com.doggy.backend.domain.user.dto;

import com.doggy.backend.domain.user.entity.User;

public record UserProfileResponse(
        Long id,
        String nickname,
        String profileImage
) {
    public static UserProfileResponse from(User user) {
        return new UserProfileResponse(
                user.getId(),
                user.getNickname(),
                user.getProfileImage()
        );
    }
}
