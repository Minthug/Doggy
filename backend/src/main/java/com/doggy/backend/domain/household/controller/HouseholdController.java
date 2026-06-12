package com.doggy.backend.domain.household.controller;

import com.doggy.backend.domain.household.dto.CreateHouseholdRequest;
import com.doggy.backend.domain.household.dto.HouseholdResponse;
import com.doggy.backend.domain.household.dto.JoinHouseholdRequest;
import com.doggy.backend.domain.household.service.HouseholdService;
import com.doggy.backend.global.security.UserPrincipal;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/households")
@RequiredArgsConstructor
public class HouseholdController {

    private final HouseholdService householdService;

    @PostMapping
    public ResponseEntity<HouseholdResponse> create(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody CreateHouseholdRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(householdService.create(principal.getId(), request));
    }

    @GetMapping("/me")
    public ResponseEntity<HouseholdResponse> getMyHousehold(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(householdService.getMyHousehold(principal.getId()));
    }

    @PostMapping("/join")
    public ResponseEntity<HouseholdResponse> join(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody JoinHouseholdRequest request) {
        return ResponseEntity.ok(householdService.join(principal.getId(), request));
    }

    @PostMapping("/invite-code/refresh")
    public ResponseEntity<Map<String, String>> refreshInviteCode(
            @AuthenticationPrincipal UserPrincipal principal) {
        String code = householdService.refreshInviteCode(principal.getId());
        return ResponseEntity.ok(Map.of("inviteCode", code));
    }

    @DeleteMapping("/leave")
    public ResponseEntity<Void> leave(
            @AuthenticationPrincipal UserPrincipal principal) {
        householdService.leave(principal.getId());
        return ResponseEntity.noContent().build();
    }
}
