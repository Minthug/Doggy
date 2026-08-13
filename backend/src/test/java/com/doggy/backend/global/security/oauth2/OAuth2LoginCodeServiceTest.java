package com.doggy.backend.global.security.oauth2;

import com.doggy.backend.domain.user.dto.TokenResponse;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.security.jwt.JwtProvider;
import com.doggy.backend.global.security.jwt.RefreshTokenRepository;
import com.doggy.backend.global.security.jwt.RefreshTokenService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;

@ExtendWith(MockitoExtension.class)
class OAuth2LoginCodeServiceTest {

    @Mock OAuth2LoginCodeRepository codeRepository;
    @Mock UserRepository userRepository;
    @Mock RefreshTokenRepository refreshTokenRepository;

    private JwtProvider jwtProvider;
    private OAuth2LoginCodeService service;

    @BeforeEach
    void setUp() {
        jwtProvider = new JwtProvider(
                Base64.getEncoder().encodeToString("0123456789abcdef0123456789abcdef".getBytes(StandardCharsets.UTF_8)),
                3_600_000L,
                2_592_000_000L
        );
        RefreshTokenService refreshTokenService = new RefreshTokenService(jwtProvider, refreshTokenRepository, userRepository);
        service = new OAuth2LoginCodeService(codeRepository, userRepository, refreshTokenService);
    }

    @Test
    void exchangeValidCodeIssuesTokensAndMarksCodeUsed() {
        User user = User.builder().nickname("oauth").build();
        ReflectionTestUtils.setField(user, "id", 1L);

        AtomicReference<OAuth2LoginCode> savedCode = new AtomicReference<>();
        given(userRepository.findById(1L)).willReturn(Optional.of(user));
        given(codeRepository.save(any(OAuth2LoginCode.class))).willAnswer(invocation -> {
            OAuth2LoginCode code = invocation.getArgument(0);
            savedCode.set(code);
            return code;
        });

        String rawCode = service.createCode(1L);
        given(codeRepository.findByCodeHash(anyString())).willReturn(Optional.of(savedCode.get()));

        TokenResponse tokens = service.exchange(rawCode, "ios-device");

        assertThat(jwtProvider.validateAccessToken(tokens.accessToken())).isTrue();
        assertThat(jwtProvider.validateRefreshToken(tokens.refreshToken())).isTrue();
        assertThat(savedCode.get().getUsedAt()).isNotNull();
    }

    @Test
    void exchangeRejectsAlreadyUsedCode() {
        User user = User.builder().nickname("oauth").build();
        ReflectionTestUtils.setField(user, "id", 1L);

        AtomicReference<OAuth2LoginCode> savedCode = new AtomicReference<>();
        given(userRepository.findById(1L)).willReturn(Optional.of(user));
        given(codeRepository.save(any(OAuth2LoginCode.class))).willAnswer(invocation -> {
            OAuth2LoginCode code = invocation.getArgument(0);
            savedCode.set(code);
            return code;
        });

        String rawCode = service.createCode(1L);
        given(codeRepository.findByCodeHash(anyString())).willReturn(Optional.of(savedCode.get()));

        service.exchange(rawCode, null);

        assertThatThrownBy(() -> service.exchange(rawCode, null))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("이미 사용");
    }
}
