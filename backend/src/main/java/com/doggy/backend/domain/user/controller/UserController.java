package com.doggy.backend.domain.user.controller;

import com.doggy.backend.domain.user.dto.*;
import com.doggy.backend.domain.user.service.UserService;
import com.doggy.backend.global.ratelimit.RateLimitService;
import com.doggy.backend.global.security.UserPrincipal;
import com.doggy.backend.global.security.oauth2.OAuth2LoginCodeService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@Slf4j
public class UserController {

    private final UserService userService;
    private final com.doggy.backend.domain.user.service.AddressSearchService addressSearchService;
    private final OAuth2LoginCodeService oAuth2LoginCodeService;
    private final RateLimitService rateLimitService;

    @PostMapping("/api/auth/signup")
    public ResponseEntity<TokenResponse> signUp(
            HttpServletRequest servletRequest,
            @Valid @RequestBody SignUpRequest request) {
        rateLimitService.checkSignup(servletRequest);
        long started = System.nanoTime();
        TokenResponse tokens = userService.signUp(request, deviceId(servletRequest));
        log.info("signup_transaction_timing durationMs={}", (System.nanoTime() - started) / 1_000_000);
        return ResponseEntity.status(HttpStatus.CREATED).body(tokens);
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
        return ResponseEntity.ok(oAuth2LoginCodeService.exchange(request.code(), request.verifier(), deviceId(servletRequest)));
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

    @GetMapping("/api/users/me/address-search")
    public java.util.List<com.doggy.backend.domain.user.service.AddressSearchService.AddressResult> searchAddress(
            @AuthenticationPrincipal UserPrincipal principal,
            HttpServletRequest request,
            @RequestParam String query) {
        rateLimitService.checkAddressSearch(principal.getId(), request);
        return addressSearchService.search(query);
    }

    @PutMapping("/api/users/me/neighborhood")
    public ResponseEntity<UserProfileResponse> updateNeighborhood(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody UpdateNeighborhoodRequest request) {
        return ResponseEntity.ok(userService.updateNeighborhood(principal.getId(), request));
    }

    @PatchMapping("/api/users/me/fcm-token")
    public ResponseEntity<Void> updateFcmToken(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody String fcmToken) {
        userService.updateFcmToken(principal.getId(), fcmToken);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/api/users/me/fcm-token/unregister")
    public ResponseEntity<Void> clearFcmToken(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody String fcmToken) {
        userService.clearFcmToken(principal.getId(), fcmToken);
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
