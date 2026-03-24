package com.doggy.backend.domain.user.service;

import com.doggy.backend.domain.user.dto.*;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.entity.UserAuth;
import com.doggy.backend.domain.user.entity.UserAuth.AuthType;
import com.doggy.backend.domain.user.repository.UserAuthRepository;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.security.jwt.JwtProvider;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;
    private final UserAuthRepository userAuthRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtProvider jwtProvider;

    @Transactional
    public TokenResponse signUp(SignUpRequest request) {
        if (userAuthRepository.existsByAuthTypeAndEmail(AuthType.LOCAL, request.email())) {
            throw BusinessException.badRequest("이미 사용 중인 이메일입니다");
        }

        User user = userRepository.save(
                User.builder()
                        .nickname(request.nickname())
                        .build()
        );

        userAuthRepository.save(
                UserAuth.builder()
                        .user(user)
                        .authType(AuthType.LOCAL)
                        .email(request.email())
                        .passwordHash(passwordEncoder.encode(request.password()))
                        .build()
        );

        return issueTokens(user.getId());
    }

    public TokenResponse login(LoginRequest request) {
        UserAuth userAuth = userAuthRepository
                .findByAuthTypeAndEmail(AuthType.LOCAL, request.email())
                .orElseThrow(() -> BusinessException.unauthorized("이메일 또는 비밀번호가 올바르지 않습니다"));

        if (!passwordEncoder.matches(request.password(), userAuth.getPasswordHash())) {
            throw BusinessException.unauthorized("이메일 또는 비밀번호가 올바르지 않습니다");
        }

        return issueTokens(userAuth.getUser().getId());
    }

    public TokenResponse refresh(String refreshToken) {
        if (!jwtProvider.validate(refreshToken)) {
            throw BusinessException.unauthorized("유효하지 않은 리프레시 토큰입니다");
        }

        Long userId = jwtProvider.getUserId(refreshToken);
        userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));

        return issueTokens(userId);
    }

    public UserProfileResponse getProfile(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
        return UserProfileResponse.from(user);
    }

    @Transactional
    public UserProfileResponse updateProfile(Long userId, UpdateProfileRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
        user.updateProfile(request.nickname(), request.profileImage());
        return UserProfileResponse.from(user);
    }

    @Transactional
    public void updateFcmToken(Long userId, String fcmToken) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
        user.updateFcmToken(fcmToken);
    }

    private TokenResponse issueTokens(Long userId) {
        return new TokenResponse(
                jwtProvider.generateAccessToken(userId),
                jwtProvider.generateRefreshToken(userId)
        );
    }
}
