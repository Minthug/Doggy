package com.doggy.backend.domain.dog.entity;

import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "dog_favorites",
        uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "dog_id"}),
        indexes = {
                @Index(name = "idx_dog_favorites_user_id", columnList = "user_id"),
                @Index(name = "idx_dog_favorites_dog_id", columnList = "dog_id")
        })
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class DogFavorite extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "dog_id", nullable = false)
    private Dog dog;

    @Builder
    public DogFavorite(User user, Dog dog) {
        this.user = user;
        this.dog = dog;
    }
}
