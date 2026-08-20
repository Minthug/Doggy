package com.doggy.backend.domain.community.service;

import com.doggy.backend.domain.community.dto.CommunityPostResponse;
import com.doggy.backend.domain.community.dto.CreatePostRequest;
import com.doggy.backend.domain.community.entity.CommunityPost;
import com.doggy.backend.domain.community.entity.CommunityPost.PostType;
import com.doggy.backend.domain.community.repository.CommunityPostRepository;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.common.RequestLimits;
import com.doggy.backend.global.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CommunityService {

    private static final Set<PostType> REVIEW_TYPES = Set.of(PostType.FOOD_REVIEW, PostType.SUPPLY_REVIEW);

    private final CommunityPostRepository postRepository;
    private final UserRepository userRepository;

    public List<CommunityPostResponse> getPosts(PostType type, int page, int size) {
        var pageable = PageRequest.of(RequestLimits.clampPage(page), RequestLimits.clampPageSize(size));
        List<CommunityPost> posts = type == null
                ? postRepository.findAllWithUser(pageable)
                : postRepository.findByTypeWithUser(type, pageable);
        return posts.stream().map(CommunityPostResponse::from).toList();
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

        CommunityPost post = postRepository.save(
                CommunityPost.builder()
                        .user(user)
                        .type(request.type())
                        .title(request.title())
                        .content(request.content())
                        .dogName(request.dogName())
                        .breed(request.breed())
                        .lastSeenArea(request.lastSeenArea())
                        .lastSeenAt(request.lastSeenAt())
                        .lat(request.lat())
                        .lng(request.lng())
                        .contactInfo(request.contactInfo())
                        .productName(request.productName())
                        .ratingPercent(request.ratingPercent())
                        .reviewSummary(request.reviewSummary())
                        .pros(request.pros())
                        .cons(request.cons())
                        .relatedPostId(request.relatedPostId())
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
        postRepository.delete(post);
    }

    public List<CommunityPostResponse> getSightings(Long postId) {
        return postRepository.findSightingsByRelatedPostId(postId)
                .stream().map(CommunityPostResponse::from).toList();
    }

    private CommunityPost findPost(Long postId) {
        return postRepository.findById(postId)
                .orElseThrow(() -> BusinessException.notFound("게시글을 찾을 수 없습니다"));
    }
}
