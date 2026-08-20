package com.doggy.backend.domain.community.dto;

import com.doggy.backend.domain.community.entity.CommunityPost;
import com.doggy.backend.domain.community.entity.CommunityPost.PostStatus;
import com.doggy.backend.domain.community.entity.CommunityPost.PostType;

import java.time.LocalDateTime;

public record CommunityPostResponse(
        Long id,
        Long userId,
        String nickname,
        String profileImage,
        PostType type,
        String title,
        String content,
        String dogName,
        String breed,
        String lastSeenArea,
        LocalDateTime lastSeenAt,
        Double lat,
        Double lng,
        String contactInfo,
        String productName,
        Integer ratingPercent,
        String reviewSummary,
        String pros,
        String cons,
        PostStatus status,
        Long relatedPostId,
        LocalDateTime createdAt
) {
    public static CommunityPostResponse from(CommunityPost post) {
        return new CommunityPostResponse(
                post.getId(),
                post.getUser().getId(),
                post.getUser().getNickname(),
                post.getUser().getProfileImage(),
                post.getType(),
                post.getTitle(),
                post.getContent(),
                post.getDogName(),
                post.getBreed(),
                post.getLastSeenArea(),
                post.getLastSeenAt(),
                post.getLat(),
                post.getLng(),
                post.getContactInfo(),
                post.getProductName(),
                post.getRatingPercent(),
                post.getReviewSummary(),
                post.getPros(),
                post.getCons(),
                post.getStatus(),
                post.getRelatedPostId(),
                post.getCreatedAt()
        );
    }
}
