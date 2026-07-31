package com.doggy.backend.domain.user.dto;

import jakarta.validation.constraints.NotBlank;

public record OAuth2CodeExchangeRequest(
        @NotBlank String code
) {}
