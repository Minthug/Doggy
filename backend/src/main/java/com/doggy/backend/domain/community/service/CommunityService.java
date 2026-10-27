package com.doggy.backend.domain.community.service;

import com.doggy.backend.domain.community.dto.CommunityPostResponse;
import com.doggy.backend.domain.community.dto.CommunityPostSummaryResponse;
import com.doggy.backend.domain.community.dto.CreatePostRequest;
import com.doggy.backend.domain.community.entity.CommunityPost;
import com.doggy.backend.domain.community.entity.CommunityPost.PostStatus;
import com.doggy.backend.domain.community.entity.CommunityPost.PostType;
import com.doggy.backend.domain.community.repository.CommunityPostRepository;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.common.RequestLimits;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.image.ImageStorageProperties;
import com.doggy.backend.global.image.ImageStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CommunityService {

    private static final Set<PostType> REVIEW_TYPES = Set.of(PostType.FOOD_REVIEW, PostType.SUPPLY_REVIEW);
    private static final Set<PostType> DOG_POST_TYPES = Set.of(PostType.LOST, PostType.FOUND, PostType.ADOPTION);
    private static final int MAX_IMAGES = 5;

    private final CommunityPostRepository postRepository;
    private final UserRepository userRepository;
    private final ImageStorageService imageStorageService;
    private final ImageStorageProperties imageStorageProperties;

    public List<CommunityPostSummaryResponse> getPosts(PostType type, int page, int size) {
        var pageable = PageRequest.of(RequestLimits.clampPage(page), RequestLimits.clampPageSize(size));
        List<CommunityPost> posts = type == null
                ? postRepository.findAllWithUser(pageable)
                : postRepository.findByTypeWithUser(type, pageable);
        return posts.stream().map(CommunityPostSummaryResponse::from).toList();
    }

    public CommunityPostResponse getPost(Long postId) {
        CommunityPost post = findPost(postId);
        return CommunityPostResponse.from(post);
    }

    @Transactional(readOnly = false)
    public CommunityPostResponse create(Long userId, CreatePostRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
        validateReview(request);
        Long relatedPostId = validateRelatedPost(request);
        boolean isDogPost = DOG_POST_TYPES.contains(request.type());
        boolean hasSightingTime = request.type() == PostType.LOST || request.type() == PostType.FOUND;
        boolean isReview = REVIEW_TYPES.contains(request.type());
        List<String> imageUrls = sanitizeImageUrls(request.imageUrls());

        CommunityPost post = postRepository.save(
                CommunityPost.builder()
                        .user(user)
                        .type(request.type())
                        .title(request.title())
                        .content(request.content())
                        .dogName(isDogPost ? request.dogName() : null)
                        .breed(isDogPost ? request.breed() : null)
                        .lastSeenArea(isDogPost ? request.lastSeenArea() : null)
                        .lastSeenAt(hasSightingTime ? request.lastSeenAt() : null)
                        .lat(isDogPost ? request.lat() : null)
                        .lng(isDogPost ? request.lng() : null)
                        .contactInfo(isDogPost ? request.contactInfo() : null)
                        .productName(isReview ? request.productName() : null)
                        .ratingPercent(isReview ? request.ratingPercent() : null)
                        .reviewSummary(isReview ? request.reviewSummary() : null)
                        .pros(isReview ? request.pros() : null)
                        .cons(isReview ? request.cons() : null)
                        .relatedPostId(relatedPostId)
                        .imageUrls(imageUrls)
                        .build()
        );
        return CommunityPostResponse.from(post);
    }

    private void validateReview(CreatePostRequest request) {
        if (!REVIEW_TYPES.contains(request.type())) {
            return;
        }
        if (request.productName() == null || request.productName().isBlank()) {
            throw BusinessException.badRequest("리뷰 제품명을 입력해 주세요");
        }
        if (request.ratingPercent() == null || request.ratingPercent() < 0 || request.ratingPercent() > 100) {
            throw BusinessException.badRequest("리뷰 점수는 0부터 100 사이여야 합니다");
        }
        if (request.reviewSummary() == null || request.reviewSummary().isBlank()) {
            throw BusinessException.badRequest("리뷰 한줄평을 입력해 주세요");
        }
    }

    private Long validateRelatedPost(CreatePostRequest request) {
        if (request.relatedPostId() == null) {
            return null;
        }
        if (request.type() != PostType.FOUND) {
            throw BusinessException.badRequest("목격 글만 실종 글에 연결할 수 있습니다");
        }

        CommunityPost relatedPost = findPost(request.relatedPostId());
        if (relatedPost.getType() != PostType.LOST) {
            throw BusinessException.badRequest("실종 글에만 목격 제보를 연결할 수 있습니다");
        }
        if (relatedPost.getStatus() != PostStatus.OPEN) {
            throw BusinessException.badRequest("이미 해결된 실종 글에는 목격 제보를 추가할 수 없습니다");
        }
        return relatedPost.getId();
    }

    private List<String> sanitizeImageUrls(List<String> imageUrls) {
        if (imageUrls == null || imageUrls.isEmpty()) {
            return List.of();
        }
        if (imageUrls.size() > MAX_IMAGES) {
            throw BusinessException.badRequest("사진은 최대 5장까지 첨부할 수 있습니다");
        }

        Set<String> uniqueUrls = new LinkedHashSet<>();
        for (String imageUrl : imageUrls) {
            String cleanUrl = imageUrl == null ? "" : imageUrl.trim();
            if (cleanUrl.isEmpty()
                    || cleanUrl.length() > 2048
                    || imageStorageProperties.stripPublicPrefix(cleanUrl) == null) {
                throw BusinessException.badRequest("잘못된 첨부 이미지입니다");
            }
            uniqueUrls.add(cleanUrl);
        }
        return new ArrayList<>(uniqueUrls);
    }

    @Transactional(readOnly = false)
    public CommunityPostResponse resolve(Long userId, Long postId) {
        CommunityPost post = findPost(postId);
        if (!post.getUser().getId().equals(userId)) {
            throw BusinessException.badRequest("본인 게시글만 해결 처리할 수 있습니다");
        }
        post.resolve();
        return CommunityPostResponse.from(post);
    }

    @Transactional(readOnly = false)
    public void delete(Long userId, Long postId) {
        CommunityPost post = findPost(postId);
        if (!post.getUser().getId().equals(userId)) {
            throw BusinessException.badRequest("본인 게시글만 삭제할 수 있습니다");
        }
        List<String> imageUrls = List.copyOf(post.getImageUrls());
        postRepository.clearRelatedPostId(postId);
        postRepository.delete(post);
        imageUrls.forEach(imageStorageService::delete);
    }

    public List<CommunityPostResponse> getSightings(Long postId) {
        CommunityPost post = findPost(postId);
        if (post.getType() != PostType.LOST) {
            throw BusinessException.badRequest("실종 글의 목격 제보만 조회할 수 있습니다");
        }
        return postRepository.findSightingsByRelatedPostId(postId)
                .stream().map(CommunityPostResponse::from).toList();
    }

    private CommunityPost findPost(Long postId) {
        return postRepository.findById(postId)
                .orElseThrow(() -> BusinessException.notFound("게시글을 찾을 수 없습니다"));
    }
}
