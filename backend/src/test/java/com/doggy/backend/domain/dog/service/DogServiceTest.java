package com.doggy.backend.domain.dog.service;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.entity.DogFavorite;
import com.doggy.backend.domain.dog.repository.DogFavoriteRepository;
import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.household.repository.HouseholdMemberRepository;
import com.doggy.backend.domain.household.repository.HouseholdRepository;
import com.doggy.backend.domain.household.service.HouseholdService;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.image.ImageStorageService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class DogServiceTest {

    @Mock DogRepository dogRepository;
    @Mock DogFavoriteRepository dogFavoriteRepository;
    @Mock UserRepository userRepository;
    @Mock HouseholdRepository householdRepository;
    @Mock HouseholdMemberRepository householdMemberRepository;
    @Mock HouseholdService householdService;
    @Mock ImageStorageService imageStorageService;
    @Mock WalkSessionRepository walkSessionRepository;

    @InjectMocks DogService dogService;

    private User makeUser(Long id) {
        User user = User.builder().nickname("user" + id).build();
        ReflectionTestUtils.setField(user, "id", id);
        return user;
    }

    private Dog makeDog(Long id, User owner) {
        Dog dog = Dog.builder()
                .user(owner)
                .name("dog" + id)
                .build();
        ReflectionTestUtils.setField(dog, "id", id);
        return dog;
    }

    @Nested
    @DisplayName("toggleFavorite")
    class ToggleFavorite {

        @Test
        @DisplayName("접근 권한 없는 강아지는 즐겨찾기할 수 없다")
        void fail_inaccessibleDog() {
            User owner = makeUser(1L);
            Dog dog = makeDog(10L, owner);

            given(dogRepository.findById(10L)).willReturn(Optional.of(dog));
            given(householdRepository.findByUserId(2L)).willReturn(Optional.empty());

            assertThatThrownBy(() -> dogService.toggleFavorite(2L, 10L))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("반려견을 찾을 수 없습니다");

            verify(dogFavoriteRepository, never()).save(any(DogFavorite.class));
            verify(dogFavoriteRepository, never()).deleteByUserIdAndDogId(2L, 10L);
        }

        @Test
        @DisplayName("본인 강아지는 즐겨찾기할 수 있다")
        void success_ownerDog() {
            User owner = makeUser(1L);
            Dog dog = makeDog(10L, owner);

            given(dogRepository.findById(10L)).willReturn(Optional.of(dog));
            given(dogFavoriteRepository.existsByUserIdAndDogId(1L, 10L)).willReturn(false);
            given(userRepository.findById(1L)).willReturn(Optional.of(owner));

            dogService.toggleFavorite(1L, 10L);

            verify(dogFavoriteRepository).save(any(DogFavorite.class));
        }
    }
}
