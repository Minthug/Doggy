package com.doggy.backend.global.security.jwt;

import com.doggy.backend.domain.user.dto.TokenResponse;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.exception.BusinessException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class RefreshTokenServiceTest {

    @Mock RefreshTokenRepository refreshTokenRepository;
    @Mock UserRepository userRepository;

    private JwtProvider jwtProvider;
    private RefreshTokenService service;
    private User user;

    @BeforeEach
    void setUp() {
        jwtProvider = new JwtProvider(
                Base64.getEncoder().encodeToString("0123456789abcdef0123456789abcdef".getBytes(StandardCharsets.UTF_8)),
                3_600_000L,
                2_592_000_000L
        );
        service = new RefreshTokenService(jwtProvider, refreshTokenRepository, userRepository);
        user = User.builder().nickname("user").build();
        ReflectionTestUtils.setField(user, "id", 1L);
    }

    @Test
    void issueTokensStoresRefreshTokenMetadata() {
        AtomicReference<RefreshToken> saved = captureSavedToken();

        TokenResponse tokens = service.issueTokens(user, "ios-device");

        assertThat(jwtProvider.validateAccessToken(tokens.accessToken())).isTrue();
        assertThat(jwtProvider.validateRefreshToken(tokens.refreshToken())).isTrue();
        assertThat(saved.get().getUser()).isEqualTo(user);
        assertThat(saved.get().getTokenId()).isEqualTo(jwtProvider.getTokenId(tokens.refreshToken()));
        assertThat(saved.get().getTokenHash()).hasSize(64);
        assertThat(saved.get().getDeviceId()).isEqualTo("ios-device");
        assertThat(saved.get().getExpiresAt()).isAfter(LocalDateTime.now());
    }

    @Test
    void rotateRevokesOldTokenAndStoresNewToken() {
        AtomicReference<RefreshToken> saved = captureSavedToken();
        TokenResponse issued = service.issueTokens(user, "ios-device");
        RefreshToken oldToken = saved.get();

        given(refreshTokenRepository.findByTokenHash(anyString())).willReturn(Optional.of(oldToken));
        given(userRepository.findById(1L)).willReturn(Optional.of(user));

        TokenResponse rotated = service.rotate(issued.refreshToken(), null);

        assertThat(rotated.refreshToken()).isNotEqualTo(issued.refreshToken());
        assertThat(oldToken.getRevokedAt()).isNotNull();
        assertThat(oldToken.getLastUsedAt()).isNotNull();
        assertThat(saved.get().getDeviceId()).isEqualTo("ios-device");
    }

    @Test
    void rotateUnknownValidTokenRevokesAllActiveTokensForUser() {
        TokenResponse issued = service.issueTokens(user, null);
        given(refreshTokenRepository.findByTokenHash(anyString())).willReturn(Optional.empty());

        assertThatThrownBy(() -> service.rotate(issued.refreshToken(), null))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("유효하지 않은 리프레시 토큰");

        verify(refreshTokenRepository).revokeActiveTokensByUserId(eq(1L), any(LocalDateTime.class));
    }

    @Test
    void revokeMarksStoredTokenRevoked() {
        AtomicReference<RefreshToken> saved = captureSavedToken();
        TokenResponse issued = service.issueTokens(user, null);
        given(refreshTokenRepository.findByTokenHash(anyString())).willReturn(Optional.of(saved.get()));

        service.revoke(issued.refreshToken());

        assertThat(saved.get().getRevokedAt()).isNotNull();
    }

    private AtomicReference<RefreshToken> captureSavedToken() {
        AtomicReference<RefreshToken> saved = new AtomicReference<>();
        given(refreshTokenRepository.save(any(RefreshToken.class))).willAnswer(invocation -> {
            RefreshToken token = invocation.getArgument(0);
            saved.set(token);
            return token;
        });
        return saved;
    }
}
