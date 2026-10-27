package com.doggy.backend.domain.community.service;

import com.doggy.backend.domain.community.dto.CommunityPostSummaryResponse;
import com.doggy.backend.domain.community.dto.CreatePostRequest;
import com.doggy.backend.domain.community.entity.CommunityPost;
import com.doggy.backend.domain.community.entity.CommunityPost.PostType;
import com.doggy.backend.domain.community.repository.CommunityPostRepository;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.image.ImageStorageProperties;
import com.doggy.backend.global.image.ImageStorageService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class CommunityServiceTest {

    @Mock CommunityPostRepository postRepository;
    @Mock UserRepository userRepository;
    @Mock ImageStorageService imageStorageService;
    @Mock ImageStorageProperties imageStorageProperties;

    @InjectMocks CommunityService communityService;

    @Test
    void reviewDoesNotStoreHiddenDogFields() {
        User user = user(1L);
        given(userRepository.findById(1L)).willReturn(Optional.of(user));
        given(postRepository.save(any(CommunityPost.class))).willAnswer(invocation -> invocation.getArgument(0));

        CreatePostRequest request = new CreatePostRequest(
                PostType.FOOD_REVIEW,
                "사료 리뷰",
                "상세 내용",
                "숨겨진 이름",
                "숨겨진 견종",
                "숨겨진 지역",
                LocalDateTime.now(),
                37.1,
                127.1,
                "010-0000-0000",
                "제품명",
                85,
                "한줄평",
                "장점",
                "단점",
                null,
                null
        );

        communityService.create(1L, request);

        ArgumentCaptor<CommunityPost> captor = ArgumentCaptor.forClass(CommunityPost.class);
        verify(postRepository).save(captor.capture());
        CommunityPost saved = captor.getValue();
        assertThat(saved.getDogName()).isNull();
        assertThat(saved.getBreed()).isNull();
        assertThat(saved.getLastSeenArea()).isNull();
        assertThat(saved.getLastSeenAt()).isNull();
        assertThat(saved.getLat()).isNull();
        assertThat(saved.getLng()).isNull();
        assertThat(saved.getContactInfo()).isNull();
        assertThat(saved.getProductName()).isEqualTo("제품명");
    }

    @Test
    void onlyFoundPostCanLinkToLostPost() {
        User user = user(1L);
        given(userRepository.findById(1L)).willReturn(Optional.of(user));
        CreatePostRequest request = basicRequest(PostType.ADOPTION, 10L);

        assertThatThrownBy(() -> communityService.create(1L, request))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("목격 글만");

        verify(postRepository, never()).save(any(CommunityPost.class));
    }

    @Test
    void foundPostCanLinkOnlyToOpenLostPost() {
        User user = user(1L);
        CommunityPost lostPost = post(10L, user, PostType.LOST);
        given(userRepository.findById(1L)).willReturn(Optional.of(user));
        given(postRepository.findById(10L)).willReturn(Optional.of(lostPost));
        given(postRepository.save(any(CommunityPost.class))).willAnswer(invocation -> invocation.getArgument(0));

        communityService.create(1L, basicRequest(PostType.FOUND, 10L));

        ArgumentCaptor<CommunityPost> captor = ArgumentCaptor.forClass(CommunityPost.class);
        verify(postRepository).save(captor.capture());
        assertThat(captor.getValue().getRelatedPostId()).isEqualTo(10L);
    }

    @Test
    void foundPostRejectsLinkToNonLostPost() {
        User user = user(1L);
        CommunityPost adoptionPost = post(10L, user, PostType.ADOPTION);
        given(userRepository.findById(1L)).willReturn(Optional.of(user));
        given(postRepository.findById(10L)).willReturn(Optional.of(adoptionPost));

        assertThatThrownBy(() -> communityService.create(1L, basicRequest(PostType.FOUND, 10L)))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("실종 글에만");

        verify(postRepository, never()).save(any(CommunityPost.class));
    }

    @Test
    void resolvedLostPostRejectsNewSighting() {
        User user = user(1L);
        CommunityPost lostPost = post(10L, user, PostType.LOST);
        lostPost.resolve();
        given(userRepository.findById(1L)).willReturn(Optional.of(user));
        given(postRepository.findById(10L)).willReturn(Optional.of(lostPost));

        assertThatThrownBy(() -> communityService.create(1L, basicRequest(PostType.FOUND, 10L)))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("이미 해결된");

        verify(postRepository, never()).save(any(CommunityPost.class));
    }

    @Test
    void deletingPostUnlinksSightingsBeforeDelete() {
        User user = user(1L);
        CommunityPost post = post(10L, user, PostType.LOST);
        ReflectionTestUtils.setField(
                post,
                "imageUrls",
                List.of("http://localhost:8080/images/community.jpg")
        );
        given(postRepository.findById(10L)).willReturn(Optional.of(post));

        communityService.delete(1L, 10L);

        InOrder order = inOrder(postRepository);
        order.verify(postRepository).clearRelatedPostId(10L);
        order.verify(postRepository).delete(post);
        verify(imageStorageService).delete("http://localhost:8080/images/community.jpg");
    }

    @Test
    void storesOnlyImagesIssuedByImageStorage() {
        User user = user(1L);
        String imageUrl = "http://localhost:8080/images/community.jpg";
        given(userRepository.findById(1L)).willReturn(Optional.of(user));
        given(imageStorageProperties.stripPublicPrefix(imageUrl)).willReturn("community.jpg");
        given(postRepository.save(any(CommunityPost.class))).willAnswer(invocation -> invocation.getArgument(0));

        communityService.create(1L, basicRequest(PostType.LOST, null, List.of(imageUrl)));

        ArgumentCaptor<CommunityPost> captor = ArgumentCaptor.forClass(CommunityPost.class);
        verify(postRepository).save(captor.capture());
        assertThat(captor.getValue().getImageUrls()).containsExactly(imageUrl);
    }

    @Test
    void rejectsExternalImageUrl() {
        User user = user(1L);
        String imageUrl = "https://tracker.example/image.jpg";
        given(userRepository.findById(1L)).willReturn(Optional.of(user));
        given(imageStorageProperties.stripPublicPrefix(imageUrl)).willReturn(null);

        assertThatThrownBy(() -> communityService.create(
                1L,
                basicRequest(PostType.LOST, null, List.of(imageUrl))))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("잘못된 첨부 이미지");

        verify(postRepository, never()).save(any(CommunityPost.class));
    }

    @Test
    void listSummaryDoesNotExposeDetailContactOrCoordinates() {
        assertThat(Arrays.stream(CommunityPostSummaryResponse.class.getRecordComponents())
                .map(component -> component.getName()))
                .doesNotContain("contactInfo", "lat", "lng", "lastSeenAt");
    }

    private CreatePostRequest basicRequest(PostType type, Long relatedPostId) {
        return basicRequest(type, relatedPostId, null);
    }

    private CreatePostRequest basicRequest(PostType type, Long relatedPostId, List<String> imageUrls) {
        return new CreatePostRequest(
                type,
                "제목",
                "내용",
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                relatedPostId,
                imageUrls
        );
    }

    private User user(Long id) {
        User user = User.builder().nickname("user" + id).build();
        ReflectionTestUtils.setField(user, "id", id);
        return user;
    }

    private CommunityPost post(Long id, User user, PostType type) {
        CommunityPost post = CommunityPost.builder()
                .user(user)
                .type(type)
                .title("제목")
                .content("내용")
                .build();
        ReflectionTestUtils.setField(post, "id", id);
        return post;
    }
}
