package com.doggy.backend.domain.user.entity;

import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(
    name = "user_auth",
    uniqueConstraints = {
        @UniqueConstraint(columnNames = {"auth_type", "provider_id"}),
        @UniqueConstraint(columnNames = {"auth_type", "email"})
    },
    indexes = {
        @Index(name = "idx_user_auth_user_id", columnList = "user_id")
    }
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserAuth extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "auth_type", nullable = false, length = 20)
    private AuthType authType;

    @Column(length = 255)
    private String email;

    @Column(length = 255)
    private String passwordHash;

    @Column(length = 255)
    private String providerId;

    @Builder
    public UserAuth(User user, AuthType authType, String email, String passwordHash, String providerId) {
        this.user = user;
        this.authType = authType;
        this.email = email;
        this.passwordHash = passwordHash;
        this.providerId = providerId;
    }

    public void updatePasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public enum AuthType {
        LOCAL, KAKAO, GOOGLE, NAVER, APPLE
    }
}
