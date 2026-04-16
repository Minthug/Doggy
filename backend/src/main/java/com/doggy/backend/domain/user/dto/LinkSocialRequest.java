package com.doggy.backend.domain.user.dto;

import com.doggy.backend.domain.user.entity.UserAuth.AuthType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record LinkSocialRequest(
        @NotNull
        AuthType authType,

        @NotBlank
        String providerId,

        String email
) {}
