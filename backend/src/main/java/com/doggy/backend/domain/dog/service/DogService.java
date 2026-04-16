package com.doggy.backend.domain.dog.service;

import com.doggy.backend.domain.dog.dto.CreateDogRequest;
import com.doggy.backend.domain.dog.dto.DogResponse;
import com.doggy.backend.domain.dog.dto.UpdateDogRequest;
import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class DogService {

    private final DogRepository dogRepository;
    private final UserRepository userRepository;

    @Transactional
    public DogResponse create(Long userId, CreateDogRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));

        Dog dog = dogRepository.save(
                Dog.builder()
                        .user(user)
                        .name(request.name())
                        .breed(request.breed())
                        .birthDate(request.birthDate())
                        .weightKg(request.weightKg())
                        .gender(request.gender())
                        .isNeutered(request.isNeutered())
                        .profileImage(request.profileImage())
                        .warnings(request.warnings())
                        .build()
        );

        return DogResponse.from(dog);
    }

    public List<DogResponse> getMyDogs(Long userId) {
        return dogRepository.findAllByUserId(userId).stream()
                .map(DogResponse::from)
                .toList();
    }

    public DogResponse getDog(Long userId, Long dogId) {
        Dog dog = dogRepository.findByIdAndUserId(dogId, userId)
                .orElseThrow(() -> BusinessException.notFound("반려견을 찾을 수 없습니다"));
        return DogResponse.from(dog);
    }

    @Transactional
    public DogResponse update(Long userId, Long dogId, UpdateDogRequest request) {
        Dog dog = dogRepository.findByIdAndUserId(dogId, userId)
                .orElseThrow(() -> BusinessException.notFound("반려견을 찾을 수 없습니다"));

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

        return DogResponse.from(dog);
    }

    @Transactional
    public void delete(Long userId, Long dogId) {
        Dog dog = dogRepository.findByIdAndUserId(dogId, userId)
                .orElseThrow(() -> BusinessException.notFound("반려견을 찾을 수 없습니다"));
        dogRepository.delete(dog);
    }
}
