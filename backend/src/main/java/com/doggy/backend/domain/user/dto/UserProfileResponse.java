package com.doggy.backend.domain.user.dto;

import com.doggy.backend.domain.user.entity.User;

public record UserProfileResponse(
        Long id,
        String nickname,
        String profileImage,
        String phone,
        String address,
        java.time.LocalDate birthDate,
        boolean nicknameChanged
) {
    public static UserProfileResponse from(User user) {
        return new UserProfileResponse(
                user.getId(),
                user.getNickname(),
                user.getProfileImage(),
                user.getPhone(),
                user.getAddress(),
                user.getBirthDate(),
                user.isNicknameChanged()
        );
    }
}
