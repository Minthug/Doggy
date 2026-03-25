package com.doggy.backend.domain.place.controller;

import com.doggy.backend.domain.place.dto.CreatePlaceRequest;
import com.doggy.backend.domain.place.dto.PlaceResponse;
import com.doggy.backend.domain.place.dto.VoteRequest;
import com.doggy.backend.domain.place.entity.Place.Category;
import com.doggy.backend.domain.place.service.PlaceService;
import com.doggy.backend.global.security.UserPrincipal;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/places")
@RequiredArgsConstructor
public class PlaceController {

    private final PlaceService placeService;

    @GetMapping
    public ResponseEntity<List<PlaceResponse>> findNearby(
            @RequestParam double lat,
            @RequestParam double lng,
            @RequestParam(required = false) Double radiusMeters,
            @RequestParam(required = false) Category category) {
        List<PlaceResponse> result = category != null
                ? placeService.findNearbyByCategory(lat, lng, radiusMeters, category)
                : placeService.findNearby(lat, lng, radiusMeters);
        return ResponseEntity.ok(result);
    }

    @GetMapping("/{placeId}")
    public ResponseEntity<PlaceResponse> getPlace(@PathVariable Long placeId) {
        return ResponseEntity.ok(placeService.getPlace(placeId));
    }

    @PostMapping
    public ResponseEntity<PlaceResponse> create(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody CreatePlaceRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(placeService.create(principal.getId(), request));
    }

    @PostMapping("/{placeId}/vote")
    public ResponseEntity<Void> vote(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long placeId,
            @Valid @RequestBody VoteRequest request) {
        placeService.vote(principal.getId(), placeId, request);
        return ResponseEntity.noContent().build();
    }
}
