package com.doggy.backend.global.security.jwt;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;

class JwtProviderTest {

    private final JwtProvider jwtProvider = new JwtProvider(
            Base64.getEncoder().encodeToString("0123456789abcdef0123456789abcdef".getBytes(StandardCharsets.UTF_8)),
            3_600_000L,
            2_592_000_000L
    );

    @Test
    void accessTokenIsOnlyValidAsAccessToken() {
        String token = jwtProvider.generateAccessToken(1L);

        assertThat(jwtProvider.validateAccessToken(token)).isTrue();
        assertThat(jwtProvider.validateRefreshToken(token)).isFalse();
        assertThat(jwtProvider.getUserId(token)).isEqualTo(1L);
    }

    @Test
    void refreshTokenIsOnlyValidAsRefreshToken() {
        String token = jwtProvider.generateRefreshToken(1L);

        assertThat(jwtProvider.validateRefreshToken(token)).isTrue();
        assertThat(jwtProvider.validateAccessToken(token)).isFalse();
        assertThat(jwtProvider.getUserId(token)).isEqualTo(1L);
    }
}
