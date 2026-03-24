package com.doggy.backend.domain.user.dto;

public record TokenResponse(
        String accessToken,
        String refreshToken
) {}
