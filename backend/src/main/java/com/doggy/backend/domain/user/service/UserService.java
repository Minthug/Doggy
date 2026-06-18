package com.doggy.backend.domain.user.service;

import com.doggy.backend.domain.user.dto.*;
import com.doggy.backend.domain.user.entity.PushSetting;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.entity.UserAuth;
import com.doggy.backend.domain.user.entity.UserAuth.AuthType;
import com.doggy.backend.domain.user.repository.PushSettingRepository;
import com.doggy.backend.domain.user.repository.UserAuthRepository;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.image.ImageStorageService;
import com.doggy.backend.global.security.jwt.JwtProvider;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserService {

    private static final List<AuthType> SOCIAL_AUTH_TYPES =
            List.of(AuthType.KAKAO, AuthType.GOOGLE, AuthType.NAVER, AuthType.APPLE);

    private final UserRepository userRepository;
    private final UserAuthRepository userAuthRepository;
    private final PushSettingRepository pushSettingRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtProvider jwtProvider;
    private final ImageStorageService imageStorageService;

    @Transactional
    public TokenResponse signUp(SignUpRequest request) {
        if (userAuthRepository.existsByAuthTypeAndEmail(AuthType.LOCAL, request.email())) {
            throw BusinessException.badRequest("이미 사용 중인 이메일입니다");
        }

        User user = userRepository.save(
                User.builder()
                        .nickname(request.nickname())
                        .phone(request.phone())
                        .address(request.address())
                        .birthDate(request.birthDate())
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
        String oldImage = user.getProfileImage();
        user.updateProfile(request.nickname(), request.profileImage());
        if (oldImage != null && !oldImage.equals(request.profileImage())) {
            imageStorageService.delete(oldImage);
        }
        return UserProfileResponse.from(user);
    }

    /* Firebase Cloud Messaging */
    @Transactional
    public void updateFcmToken(Long userId, String fcmToken) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
        user.updateFcmToken(fcmToken);
    }

    @Transactional
    public PushSettingResponse getPushSetting(Long userId) {
        PushSetting setting = pushSettingRepository.findByUserId(userId)
                .orElseGet(() -> createDefaultPushSetting(userId));
        return PushSettingResponse.from(setting);
    }

    @Transactional
    public PushSettingResponse updatePushSetting(Long userId, UpdatePushSettingRequest request) {
        PushSetting setting = pushSettingRepository.findByUserId(userId)
                .orElseGet(() -> createDefaultPushSetting(userId));
        setting.update(request.walkReminderEnabled(), request.reminderIntervalHours(),
                request.weatherAlertEnabled(), request.weatherAlertHour(), request.weatherAlertMinute(),
                request.birthdayAlertEnabled(), request.healthCheckupAlertEnabled());
        return PushSettingResponse.from(setting);
    }

    private PushSetting createDefaultPushSetting(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
        return pushSettingRepository.save(PushSetting.builder().user(user).build());
    }

    public LinkedSocialResponse getLinkedSocial(Long userId) {
        return userAuthRepository.findByUser_IdAndAuthTypeIn(userId, SOCIAL_AUTH_TYPES)
                .map(LinkedSocialResponse::from)
                .orElseThrow(() -> BusinessException.notFound("연결된 소셜 계정이 없습니다"));
    }

    @Transactional
    public void linkSocialAccount(Long userId, LinkSocialRequest request) {
        if (userAuthRepository.existsByUser_IdAndAuthTypeIn(userId, SOCIAL_AUTH_TYPES)) {
            throw BusinessException.badRequest("이미 연결된 소셜 계정이 있습니다");
        }
        if (userAuthRepository.findByAuthTypeAndProviderId(request.authType(), request.providerId()).isPresent()) {
            throw BusinessException.badRequest("이미 다른 계정에 연결된 소셜 계정입니다");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
        userAuthRepository.save(
                UserAuth.builder()
                        .user(user)
                        .authType(request.authType())
                        .providerId(request.providerId())
                        .email(request.email())
                        .build()
        );
    }

    @Transactional
    public void unlinkSocialAccount(Long userId) {
        UserAuth socialAuth = userAuthRepository.findByUser_IdAndAuthTypeIn(userId, SOCIAL_AUTH_TYPES)
                .orElseThrow(() -> BusinessException.notFound("연결된 소셜 계정이 없습니다"));
        userAuthRepository.delete(socialAuth);
    }

    private TokenResponse issueTokens(Long userId) {
        return new TokenResponse(
                jwtProvider.generateAccessToken(userId),
                jwtProvider.generateRefreshToken(userId)
        );
    }
}
