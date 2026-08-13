package com.doggy.backend.domain.user.controller;

import com.doggy.backend.domain.user.dto.*;
import com.doggy.backend.domain.user.service.UserService;
import com.doggy.backend.global.ratelimit.RateLimitService;
import com.doggy.backend.global.security.UserPrincipal;
import com.doggy.backend.global.security.oauth2.OAuth2LoginCodeService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;
    private final OAuth2LoginCodeService oAuth2LoginCodeService;
    private final RateLimitService rateLimitService;

    @PostMapping("/api/auth/signup")
    public ResponseEntity<TokenResponse> signUp(
            HttpServletRequest servletRequest,
            @Valid @RequestBody SignUpRequest request) {
        rateLimitService.checkSignup(servletRequest);
        return ResponseEntity.status(HttpStatus.CREATED).body(userService.signUp(request, deviceId(servletRequest)));
    }

    @PostMapping("/api/auth/login")
    public ResponseEntity<TokenResponse> login(
            HttpServletRequest servletRequest,
            @Valid @RequestBody LoginRequest request) {
        rateLimitService.checkLogin(servletRequest, request.email());
        return ResponseEntity.ok(userService.login(request, deviceId(servletRequest)));
    }

    @PostMapping("/api/auth/refresh")
    public ResponseEntity<TokenResponse> refresh(
            HttpServletRequest servletRequest,
            @RequestHeader("Refresh-Token") String refreshToken) {
        rateLimitService.checkRefresh(servletRequest);
        return ResponseEntity.ok(userService.refresh(refreshToken, deviceId(servletRequest)));
    }

    @PostMapping("/api/auth/logout")
    public ResponseEntity<Void> logout(@RequestHeader(value = "Refresh-Token", required = false) String refreshToken) {
        userService.logout(refreshToken);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/api/auth/oauth2/exchange")
    public ResponseEntity<TokenResponse> exchangeOAuth2Code(
            HttpServletRequest servletRequest,
            @Valid @RequestBody OAuth2CodeExchangeRequest request) {
        rateLimitService.checkOAuth2Exchange(servletRequest);
        return ResponseEntity.ok(oAuth2LoginCodeService.exchange(request.code(), deviceId(servletRequest)));
    }

    @GetMapping("/api/users/me")
    public ResponseEntity<UserProfileResponse> getProfile(@AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(userService.getProfile(principal.getId()));
    }

    @PatchMapping("/api/users/me")
    public ResponseEntity<UserProfileResponse> updateProfile(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody UpdateProfileRequest request) {
        return ResponseEntity.ok(userService.updateProfile(principal.getId(), request));
    }

    @PatchMapping("/api/users/me/fcm-token")
    public ResponseEntity<Void> updateFcmToken(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody String fcmToken) {
        userService.updateFcmToken(principal.getId(), fcmToken);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/users/me/social")
    public ResponseEntity<LinkedSocialResponse> getLinkedSocial(@AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(userService.getLinkedSocial(principal.getId()));
    }

    @DeleteMapping("/api/users/me/social")
    public ResponseEntity<Void> unlinkSocial(@AuthenticationPrincipal UserPrincipal principal) {
        userService.unlinkSocialAccount(principal.getId());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/users/me/push-settings")
    public ResponseEntity<PushSettingResponse> getPushSetting(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(userService.getPushSetting(principal.getId()));
    }

    @PutMapping("/api/users/me/push-settings")
    public ResponseEntity<PushSettingResponse> updatePushSetting(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody UpdatePushSettingRequest request) {
        return ResponseEntity.ok(userService.updatePushSetting(principal.getId(), request));
    }

    private String deviceId(HttpServletRequest request) {
        return request.getHeader("X-Device-Id");
    }
}
