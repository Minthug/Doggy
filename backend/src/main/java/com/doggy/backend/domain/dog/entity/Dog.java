package com.doggy.backend.domain.dog.entity;

import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "dogs")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Dog extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 50)
    private String name;

    @Column(length = 100)
    private String breed;

    private LocalDate birthDate;

    @Column(precision = 4, scale = 1)
    private BigDecimal weightKg;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private Gender gender;

    @Column(nullable = false)
    private boolean isNeutered = false;

    @Column(length = 500)
    private String profileImage;

    @Builder
    public Dog(User user, String name, String breed, LocalDate birthDate,
               BigDecimal weightKg, Gender gender, boolean isNeutered, String profileImage) {
        this.user = user;
        this.name = name;
        this.breed = breed;
        this.birthDate = birthDate;
        this.weightKg = weightKg;
        this.gender = gender;
        this.isNeutered = isNeutered;
        this.profileImage = profileImage;
    }

    public void update(String name, String breed, LocalDate birthDate,
                       BigDecimal weightKg, Gender gender, boolean isNeutered, String profileImage) {
        this.name = name;
        this.breed = breed;
        this.birthDate = birthDate;
        this.weightKg = weightKg;
        this.gender = gender;
        this.isNeutered = isNeutered;
        this.profileImage = profileImage;
    }

    public enum Gender {
        MALE, FEMALE
    }
}
