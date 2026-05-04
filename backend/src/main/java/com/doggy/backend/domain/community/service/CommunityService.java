package com.doggy.backend.domain.community.service;

import com.doggy.backend.domain.community.dto.CommunityPostResponse;
import com.doggy.backend.domain.community.dto.CreatePostRequest;
import com.doggy.backend.domain.community.entity.CommunityPost;
import com.doggy.backend.domain.community.entity.CommunityPost.PostType;
import com.doggy.backend.domain.community.repository.CommunityPostRepository;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CommunityService {

    private final CommunityPostRepository postRepository;
    private final UserRepository userRepository;

    public List<CommunityPostResponse> getPosts(PostType type, int page, int size) {
        var pageable = PageRequest.of(page, size);
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
                        .build()
        );
        return CommunityPostResponse.from(post);
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

    private CommunityPost findPost(Long postId) {
        return postRepository.findById(postId)
                .orElseThrow(() -> BusinessException.notFound("게시글을 찾을 수 없습니다"));
    }
}
