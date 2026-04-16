package com.doggy.backend.domain.dog.entity;

import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.HashSet;
import java.util.Set;

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

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "dog_warnings", joinColumns = @JoinColumn(name = "dog_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "warning", length = 20)
    private Set<DogWarning> warnings = new HashSet<>();

    @Builder
    public Dog(User user, String name, String breed, LocalDate birthDate,
               BigDecimal weightKg, Gender gender, boolean isNeutered, String profileImage,
               Set<DogWarning> warnings) {
        this.user = user;
        this.name = name;
        this.breed = breed;
        this.birthDate = birthDate;
        this.weightKg = weightKg;
        this.gender = gender;
        this.isNeutered = isNeutered;
        this.profileImage = profileImage;
        if (warnings != null) this.warnings = warnings;
    }

    public void update(String name, String breed, LocalDate birthDate,
                       BigDecimal weightKg, Gender gender, boolean isNeutered, String profileImage,
                       Set<DogWarning> warnings) {
        this.name = name;
        this.breed = breed;
        this.birthDate = birthDate;
        this.weightKg = weightKg;
        this.gender = gender;
        this.isNeutered = isNeutered;
        this.profileImage = profileImage;
        this.warnings = warnings != null ? warnings : new HashSet<>();
    }

    public enum Gender {
        MALE, FEMALE
    }

    public enum DogWarning {
        AGGRESSIVE,  // 사나움
        BITING,      // 물림 주의
        JUMPING,     // 달려듦
        ESCAPING,    // 도주 주의
        BARKING      // 짖음 주의
    }
}
