package com.doggy.backend.domain.walk.controller;

import com.doggy.backend.domain.walk.dto.*;
import com.doggy.backend.domain.walk.service.WalkMeetService;
import com.doggy.backend.domain.walk.service.WalkPingService;
import com.doggy.backend.domain.walk.service.WalkService;
import com.doggy.backend.global.security.UserPrincipal;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/walks")
@RequiredArgsConstructor
public class WalkController {

    private final WalkService walkService;
    private final WalkPingService walkPingService;
    private final WalkMeetService walkMeetService;

    @PostMapping
    public ResponseEntity<WalkSessionResponse> start(@AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(walkService.start(principal.getId()));
    }

    @PostMapping("/{sessionId}/complete")
    public ResponseEntity<WalkDetailResponse> complete(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long sessionId,
            @Valid @RequestBody CompleteWalkRequest request) {
        return ResponseEntity.ok(walkService.complete(principal.getId(), sessionId, request));
    }

    @PatchMapping("/{sessionId}/pause")
    public ResponseEntity<WalkSessionResponse> pause(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long sessionId) {
        return ResponseEntity.ok(walkService.pause(principal.getId(), sessionId));
    }

    @PatchMapping("/{sessionId}/resume")
    public ResponseEntity<WalkSessionResponse> resume(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long sessionId) {
        return ResponseEntity.ok(walkService.resume(principal.getId(), sessionId));
    }

    @GetMapping
    public ResponseEntity<List<WalkSessionResponse>> getHistory(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(walkService.getHistory(principal.getId(), page, size));
    }

    @GetMapping("/{sessionId}")
    public ResponseEntity<WalkDetailResponse> getDetail(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long sessionId) {
        return ResponseEntity.ok(walkService.getDetail(principal.getId(), sessionId));
    }

    @PatchMapping("/{sessionId}/publish")
    public ResponseEntity<WalkDetailResponse> publish(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long sessionId,
            @Valid @RequestBody PublishRouteRequest request) {
        return ResponseEntity.ok(walkService.publish(principal.getId(), sessionId, request));
    }

    @PatchMapping("/{sessionId}/unpublish")
    public ResponseEntity<Void> unpublish(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long sessionId) {
        walkService.unpublish(principal.getId(), sessionId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/public")
    public ResponseEntity<List<PublicRouteResponse>> getPublicRoutes(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng) {
        Long userId = principal != null ? principal.getId() : null;
        return ResponseEntity.ok(walkService.getPublicRoutes(userId, lat, lng, page, size));
    }

    @PatchMapping("/{sessionId}/location")
    public ResponseEntity<Void> updateLocation(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long sessionId,
            @Valid @RequestBody UpdateLocationRequest request) {
        walkPingService.updateLocationAndPing(principal.getId(), sessionId, request.lat(), request.lng());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{sessionId}/meets")
    public ResponseEntity<List<WalkMeetResponse>> getMeets(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long sessionId) {
        return ResponseEntity.ok(walkMeetService.getMeets(principal.getId(), sessionId));
    }

    @PostMapping("/{sessionId}/like")
    public ResponseEntity<Void> toggleLike(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long sessionId) {
        walkService.toggleLike(principal.getId(), sessionId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{sessionId}/bookmark")
    public ResponseEntity<Void> toggleBookmark(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long sessionId) {
        walkService.toggleBookmark(principal.getId(), sessionId);
        return ResponseEntity.noContent().build();
    }
}
