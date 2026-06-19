package com.doggy.backend.domain.supply.controller;

import com.doggy.backend.domain.supply.dto.SupplyItemResponse;
import com.doggy.backend.domain.supply.dto.UpdateSupplyRequest;
import com.doggy.backend.domain.supply.service.SupplyService;
import com.doggy.backend.global.security.UserPrincipal;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/supply")
@RequiredArgsConstructor
public class SupplyController {

    private final SupplyService supplyService;

    @GetMapping
    public ResponseEntity<List<SupplyItemResponse>> getInventory(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(supplyService.getInventory(principal.getId()));
    }

    @PutMapping("/{name}")
    public ResponseEntity<SupplyItemResponse> update(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable String name,
            @Valid @RequestBody UpdateSupplyRequest request) {
        return ResponseEntity.ok(supplyService.update(principal.getId(), name, request));
    }
}
