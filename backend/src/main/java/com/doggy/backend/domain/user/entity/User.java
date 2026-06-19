package com.doggy.backend.domain.user.entity;

import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = "users")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class User extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50)
    private String nickname;

    @Column(columnDefinition = "TEXT")
    private String profileImage;

    @Column(length = 500)
    private String fcmToken;

    @Column(length = 20)
    private String phone;

    @Column(length = 100)
    private String address;

    private LocalDate birthDate;

    @Column(nullable = false)
    private boolean nicknameChanged = false;

    @Builder
    public User(String nickname, String profileImage, String phone, String address, LocalDate birthDate) {
        this.nickname = nickname;
        this.profileImage = profileImage;
        this.phone = phone;
        this.address = address;
        this.birthDate = birthDate;
    }

    public void updateProfile(String nickname, String profileImage) {
        if (!this.nickname.equals(nickname)) {
            this.nicknameChanged = true;
        }
        this.nickname = nickname;
        this.profileImage = profileImage;
    }

    public void updateFcmToken(String fcmToken) {
        this.fcmToken = fcmToken;
    }
}
