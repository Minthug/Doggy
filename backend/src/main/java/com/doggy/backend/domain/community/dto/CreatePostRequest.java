package com.doggy.backend.domain.community.dto;

import com.doggy.backend.domain.community.entity.CommunityPost.PostType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

public record CreatePostRequest(
        @NotNull PostType type,
        @NotBlank @Size(max = 100) String title,
        @NotBlank String content,
        String dogName,
        String breed,
        String lastSeenArea,
        LocalDateTime lastSeenAt,
        Double lat,
        Double lng,
        String contactInfo,
        Long relatedPostId
) {}
