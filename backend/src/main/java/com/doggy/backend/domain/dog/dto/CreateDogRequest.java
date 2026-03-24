package com.doggy.backend.domain.dog.dto;

import com.doggy.backend.domain.dog.entity.Dog.Gender;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

public record CreateDogRequest(

        @NotBlank
        @Size(max = 50)
        String name,

        String breed,
        LocalDate birthDate,
        BigDecimal weightKg,
        Gender gender,
        boolean isNeutered,
        String profileImage
) {}
