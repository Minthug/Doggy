package com.doggy.backend.domain.dog.service;

import com.doggy.backend.domain.dog.dto.CreateDogRequest;
import com.doggy.backend.domain.dog.dto.DogResponse;
import com.doggy.backend.domain.dog.dto.UpdateDogRequest;
import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.entity.DogFavorite;
import com.doggy.backend.domain.dog.repository.DogFavoriteRepository;
import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.household.entity.Household;
import com.doggy.backend.domain.household.entity.HouseholdMember;
import com.doggy.backend.domain.household.repository.HouseholdMemberRepository;
import com.doggy.backend.domain.household.repository.HouseholdRepository;
import com.doggy.backend.domain.household.service.HouseholdService;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.domain.walk.repository.WalkSessionRepository;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.image.ImageStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class DogService {

    private final DogRepository dogRepository;
    private final DogFavoriteRepository dogFavoriteRepository;
    private final UserRepository userRepository;
    private final HouseholdRepository householdRepository;
    private final HouseholdMemberRepository householdMemberRepository;
    private final HouseholdService householdService;
    private final ImageStorageService imageStorageService;
    private final WalkSessionRepository walkSessionRepository;

    @Transactional
    public DogResponse create(Long userId, CreateDogRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));

        Dog dog = Dog.builder()
                .user(user)
                .name(request.name())
                .breed(request.breed())
                .birthDate(request.birthDate())
                .weightKg(request.weightKg())
                .gender(request.gender())
                .isNeutered(request.isNeutered())
                .profileImage(request.profileImage())
                .warnings(request.warnings())
                .build();

        // 가구에 속해 있으면 자동으로 가구 연결
        householdRepository.findByUserId(userId).ifPresent(dog::assignHousehold);

        return DogResponse.from(dogRepository.save(dog));
    }

    public List<DogResponse> getMyDogs(Long userId) {
        Set<Long> favoritedIds = dogFavoriteRepository.findFavoritedDogIdsByUserId(userId);
        Long householdId = householdService.findHouseholdIdByUserId(userId).getId();
        List<Dog> dogs = householdId != null
                ? dogRepository.findAllAccessibleDogs(userId, householdId)
                : dogRepository.findAllByUserId(userId);
        return dogs.stream()
                .map(dog -> DogResponse.from(dog, favoritedIds.contains(dog.getId())))
                .toList();
    }

    public DogResponse getDog(Long userId, Long dogId) {
        Dog dog = dogRepository.findById(dogId)
                .orElseThrow(() -> BusinessException.notFound("반려견을 찾을 수 없습니다"));
        checkAccess(userId, dog);
        boolean favorited = dogFavoriteRepository.existsByUserIdAndDogId(userId, dogId);
        return DogResponse.from(dog, favorited);
    }

    private void checkAccess(Long userId, Dog dog) {
        if (dog.getUser().getId().equals(userId)) return;
        Household household = householdRepository.findByUserId(userId).orElse(null);
        if (household != null && dog.getHousehold() != null
                && dog.getHousehold().getId().equals(household.getId())) return;
        throw BusinessException.notFound("반려견을 찾을 수 없습니다");
    }

    @Transactional
    public void toggleFavorite(Long userId, Long dogId) {
        Dog dog = dogRepository.findById(dogId)
                .orElseThrow(() -> BusinessException.notFound("반려견을 찾을 수 없습니다"));
        checkAccess(userId, dog);
        if (dogFavoriteRepository.existsByUserIdAndDogId(userId, dogId)) {
            dogFavoriteRepository.deleteByUserIdAndDogId(userId, dogId);
        } else {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
            dogFavoriteRepository.save(DogFavorite.builder().user(user).dog(dog).build());
        }
    }

    @Transactional
    public DogResponse update(Long userId, Long dogId, UpdateDogRequest request) {
        log.info("[DogService.update] userId={}, dogId={}", userId, dogId);
        Dog dog = dogRepository.findById(dogId)
                .orElseThrow(() -> BusinessException.notFound("반려견을 찾을 수 없습니다"));
        boolean isDogOwner = dog.getUser().getId().equals(userId);
        boolean isHouseholdOwner = dog.getHousehold() != null &&
                householdMemberRepository.findByHouseholdIdAndUserId(dog.getHousehold().getId(), userId)
                        .map(m -> m.getRole() == HouseholdMember.Role.OWNER)
                        .orElse(false);
        if (!isDogOwner && !isHouseholdOwner) {
            log.warn("[DogService.update] forbidden: dogOwnerId={}, requestUserId={}", dog.getUser().getId(), userId);
            throw BusinessException.forbidden("강아지 소유자 또는 가구 오너만 수정할 수 있습니다");
        }
        String oldImage = dog.getProfileImage();
        dog.update(
                request.name(),
                request.breed(),
                request.birthDate(),
                request.weightKg(),
                request.gender(),
                request.isNeutered(),
                request.profileImage(),
                request.warnings()
        );
        if (oldImage != null && !oldImage.equals(request.profileImage())) {
            imageStorageService.delete(oldImage);
        }
        return DogResponse.from(dog);
    }

    @Transactional
    public void delete(Long userId, Long dogId) {
        Dog dog = dogRepository.findById(dogId)
                .orElseThrow(() -> BusinessException.notFound("반려견을 찾을 수 없습니다"));
        boolean isDogOwner = dog.getUser().getId().equals(userId);
        boolean isHouseholdOwner = dog.getHousehold() != null &&
                householdMemberRepository.findByHouseholdIdAndUserId(dog.getHousehold().getId(), userId)
                        .map(m -> m.getRole() == HouseholdMember.Role.OWNER)
                        .orElse(false);
        if (!isDogOwner && !isHouseholdOwner) {
            throw BusinessException.forbidden("강아지 소유자 또는 가구 오너만 삭제할 수 있습니다");
        }
        imageStorageService.delete(dog.getProfileImage());
        walkSessionRepository.removeDogFromAllSessions(dogId);
        dogRepository.delete(dog);
    }
}
