package com.doggy.backend.global.security.jwt;

import com.doggy.backend.domain.user.dto.TokenResponse;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.HexFormat;

@Slf4j
@Service
@RequiredArgsConstructor
public class RefreshTokenService {

    private final JwtProvider jwtProvider;
    private final RefreshTokenRepository refreshTokenRepository;
    private final UserRepository userRepository;

    @Transactional
    public TokenResponse issueTokens(User user, String deviceId) {
        String accessToken = jwtProvider.generateAccessToken(user.getId());
        String refreshToken = jwtProvider.generateRefreshToken(user.getId());
        storeRefreshToken(user, refreshToken, deviceId);
        return new TokenResponse(accessToken, refreshToken);
    }

    @Transactional
    public TokenResponse rotate(String refreshToken, String deviceId) {
        if (!jwtProvider.validateRefreshToken(refreshToken)) {
            throw BusinessException.unauthorized("유효하지 않은 리프레시 토큰입니다");
        }

        Long userId = jwtProvider.getUserId(refreshToken);
        LocalDateTime now = LocalDateTime.now();
        RefreshToken stored = refreshTokenRepository.findByTokenHash(hash(refreshToken))
                .orElse(null);
        if (stored == null || !stored.isActive(now) || !stored.getUser().getId().equals(userId)) {
            refreshTokenRepository.revokeActiveTokensByUserId(userId, now);
            log.warn("refresh_token_reuse_or_unknown userId={}", userId);
            throw BusinessException.unauthorized("유효하지 않은 리프레시 토큰입니다");
        }

        stored.markUsed(now);
        stored.revoke(now);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
        return issueTokens(user, chooseDeviceId(deviceId, stored.getDeviceId()));
    }

    @Transactional
    public void revoke(String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank() || !jwtProvider.validateRefreshToken(refreshToken)) {
            return;
        }
        LocalDateTime now = LocalDateTime.now();
        refreshTokenRepository.findByTokenHash(hash(refreshToken))
                .ifPresent(token -> token.revoke(now));
    }

    @Transactional
    @Scheduled(cron = "0 30 3 * * *")
    public void deleteExpiredTokens() {
        long deleted = refreshTokenRepository.deleteByExpiresAtBefore(LocalDateTime.now());
        if (deleted > 0) {
            log.info("만료된 refresh token 삭제: {}건", deleted);
        }
    }

    private void storeRefreshToken(User user, String refreshToken, String deviceId) {
        refreshTokenRepository.save(new RefreshToken(
                user,
                jwtProvider.getTokenId(refreshToken),
                hash(refreshToken),
                sanitizeDeviceId(deviceId),
                LocalDateTime.ofInstant(jwtProvider.getExpiration(refreshToken).toInstant(), ZoneId.systemDefault())
        ));
    }

    private String chooseDeviceId(String requestedDeviceId, String fallbackDeviceId) {
        String clean = sanitizeDeviceId(requestedDeviceId);
        return clean != null ? clean : fallbackDeviceId;
    }

    private String sanitizeDeviceId(String deviceId) {
        if (deviceId == null || deviceId.isBlank()) {
            return null;
        }
        String clean = deviceId.trim();
        return clean.length() <= 128 ? clean : clean.substring(0, 128);
    }

    private String hash(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw BusinessException.internalError("리프레시 토큰 처리에 실패했습니다");
        }
    }
}
