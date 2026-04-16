package com.doggy.backend.domain.user.controller;

import com.doggy.backend.domain.user.dto.*;
import com.doggy.backend.domain.user.service.UserService;
import com.doggy.backend.global.security.UserPrincipal;
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

    @PostMapping("/api/auth/signup")
    public ResponseEntity<TokenResponse> signUp(@Valid @RequestBody SignUpRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(userService.signUp(request));
    }

    @PostMapping("/api/auth/login")
    public ResponseEntity<TokenResponse> login(@Valid @RequestBody LoginRequest request) {
        return ResponseEntity.ok(userService.login(request));
    }

    @PostMapping("/api/auth/refresh")
    public ResponseEntity<TokenResponse> refresh(@RequestHeader("Refresh-Token") String refreshToken) {
        return ResponseEntity.ok(userService.refresh(refreshToken));
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

    @PostMapping("/api/users/me/social")
    public ResponseEntity<Void> linkSocial(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody LinkSocialRequest request) {
        userService.linkSocialAccount(principal.getId(), request);
        return ResponseEntity.noContent().build();
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
}
