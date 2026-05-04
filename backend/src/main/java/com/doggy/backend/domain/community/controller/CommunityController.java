package com.doggy.backend.domain.community.controller;

import com.doggy.backend.domain.community.dto.CommunityPostResponse;
import com.doggy.backend.domain.community.dto.CreatePostRequest;
import com.doggy.backend.domain.community.entity.CommunityPost.PostType;
import com.doggy.backend.domain.community.service.CommunityService;
import com.doggy.backend.global.security.UserPrincipal;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/community")
@RequiredArgsConstructor
public class CommunityController {

    private final CommunityService communityService;

    @GetMapping
    public ResponseEntity<List<CommunityPostResponse>> getPosts(
            @RequestParam(required = false) PostType type,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(communityService.getPosts(type, page, size));
    }

    @GetMapping("/{postId}")
    public ResponseEntity<CommunityPostResponse> getPost(@PathVariable Long postId) {
        return ResponseEntity.ok(communityService.getPost(postId));
    }

    @PostMapping
    public ResponseEntity<CommunityPostResponse> create(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody CreatePostRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(communityService.create(principal.getId(), request));
    }

    @PatchMapping("/{postId}/resolve")
    public ResponseEntity<CommunityPostResponse> resolve(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long postId) {
        return ResponseEntity.ok(communityService.resolve(principal.getId(), postId));
    }

    @DeleteMapping("/{postId}")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable Long postId) {
        communityService.delete(principal.getId(), postId);
        return ResponseEntity.noContent().build();
    }
}
