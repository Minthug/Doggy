package com.doggy.backend.domain.community.dto;

import com.doggy.backend.domain.community.entity.CommunityPost;
import com.doggy.backend.domain.community.entity.CommunityPost.PostStatus;
import com.doggy.backend.domain.community.entity.CommunityPost.PostType;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 목록에서 실제로 표시하는 정보만 반환한다.
 * 연락처와 정확한 좌표 같은 상세 정보는 상세 조회에서만 제공한다.
 */
public record CommunityPostSummaryResponse(
        Long id,
        Long userId,
        String nickname,
        String profileImage,
        PostType type,
        String title,
        String content,
        String dogName,
        String lastSeenArea,
        String productName,
        Integer ratingPercent,
        String reviewSummary,
        List<String> imageUrls,
        PostStatus status,
        LocalDateTime createdAt
) {
    public static CommunityPostSummaryResponse from(CommunityPost post) {
        return new CommunityPostSummaryResponse(
                post.getId(),
                post.getUser().getId(),
                post.getUser().getNickname(),
                post.getUser().getProfileImage(),
                post.getType(),
                post.getTitle(),
                post.getContent(),
                post.getDogName(),
                post.getLastSeenArea(),
                post.getProductName(),
                post.getRatingPercent(),
                post.getReviewSummary(),
                List.copyOf(post.getImageUrls()),
                post.getStatus(),
                post.getCreatedAt()
        );
    }
}
