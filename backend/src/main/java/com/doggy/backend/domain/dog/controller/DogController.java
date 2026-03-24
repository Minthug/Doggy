package com.doggy.backend.domain.dog.controller;

import com.doggy.backend.domain.dog.dto.CreateDogRequest;
import com.doggy.backend.domain.dog.dto.DogResponse;
import com.doggy.backend.domain.dog.dto.UpdateDogRequest;
import com.doggy.backend.domain.dog.service.DogService;
import com.doggy.backend.global.security.UserPrincipal;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/dogs")
@RequiredArgsConstructor
public class DogController {

    private final DogService dogService;

    @PostMapping
    public ResponseEntity<DogResponse> create(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody CreateDogRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(dogService.create(principal.getId(), request));
    }

    @GetMapping
    public ResponseEntity<List<DogResponse>> getMyDogs(@AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(dogService.getMyDogs(principal.getId()));
    }

    @GetMapping("/{dogId}")
    public ResponseEntity<DogResponse> getDog(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long dogId) {
        return ResponseEntity.ok(dogService.getDog(principal.getId(), dogId));
    }

    @PatchMapping("/{dogId}")
    public ResponseEntity<DogResponse> update(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long dogId,
            @Valid @RequestBody UpdateDogRequest request) {
        return ResponseEntity.ok(dogService.update(principal.getId(), dogId, request));
    }

    @DeleteMapping("/{dogId}")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long dogId) {
        dogService.delete(principal.getId(), dogId);
        return ResponseEntity.noContent().build();
    }
}
