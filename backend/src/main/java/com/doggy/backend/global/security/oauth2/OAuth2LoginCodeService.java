package com.doggy.backend.global.security.oauth2;

import com.doggy.backend.domain.user.dto.TokenResponse;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.security.jwt.JwtProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.HexFormat;

@Service
@RequiredArgsConstructor
@Slf4j
public class OAuth2LoginCodeService {

    private static final int CODE_BYTES = 32;
    private static final int CODE_TTL_MINUTES = 3;

    private final OAuth2LoginCodeRepository codeRepository;
    private final UserRepository userRepository;
    private final JwtProvider jwtProvider;
    private final SecureRandom secureRandom = new SecureRandom();

    @Transactional
    public String createCode(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));

        String code = generateRawCode();
        codeRepository.save(OAuth2LoginCode.builder()
                .user(user)
                .codeHash(hash(code))
                .expiresAt(LocalDateTime.now().plusMinutes(CODE_TTL_MINUTES))
                .build());
        return code;
    }

    @Transactional
    public TokenResponse exchange(String code) {
        OAuth2LoginCode loginCode = codeRepository.findByCodeHash(hash(code))
                .orElseThrow(() -> BusinessException.unauthorized("유효하지 않은 OAuth2 로그인 코드입니다"));

        LocalDateTime now = LocalDateTime.now();
        if (!loginCode.isUsable(now)) {
            throw BusinessException.unauthorized("만료되었거나 이미 사용된 OAuth2 로그인 코드입니다");
        }

        loginCode.markUsed(now);
        Long userId = loginCode.getUser().getId();
        return new TokenResponse(
                jwtProvider.generateAccessToken(userId),
                jwtProvider.generateRefreshToken(userId)
        );
    }

    @Transactional
    @Scheduled(cron = "0 0 * * * *")
    public void deleteExpiredCodes() {
        long deleted = codeRepository.deleteByExpiresAtBefore(LocalDateTime.now());
        if (deleted > 0) {
            log.info("만료된 OAuth2 로그인 코드 삭제: {}건", deleted);
        }
    }

    private String generateRawCode() {
        byte[] bytes = new byte[CODE_BYTES];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String hash(String code) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(code.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw BusinessException.internalError("OAuth2 로그인 코드 처리에 실패했습니다");
        }
    }
}
