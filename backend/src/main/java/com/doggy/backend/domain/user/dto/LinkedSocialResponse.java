package com.doggy.backend.domain.user.dto;

import com.doggy.backend.domain.user.entity.UserAuth;
import com.doggy.backend.domain.user.entity.UserAuth.AuthType;

public record LinkedSocialResponse(
        AuthType authType,
        String email
) {
    public static LinkedSocialResponse from(UserAuth userAuth) {
        return new LinkedSocialResponse(userAuth.getAuthType(), userAuth.getEmail());
    }
}
