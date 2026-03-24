package com.doggy.backend.domain.dog.dto;

import com.doggy.backend.domain.dog.entity.Dog;
import com.doggy.backend.domain.dog.entity.Dog.Gender;

import java.math.BigDecimal;
import java.time.LocalDate;

public record DogResponse(
        Long id,
        String name,
        String breed,
        LocalDate birthDate,
        BigDecimal weightKg,
        Gender gender,
        boolean isNeutered,
        String profileImage
) {
    public static DogResponse from(Dog dog) {
        return new DogResponse(
                dog.getId(),
                dog.getName(),
                dog.getBreed(),
                dog.getBirthDate(),
                dog.getWeightKg(),
                dog.getGender(),
                dog.isNeutered(),
                dog.getProfileImage()
        );
    }
}
