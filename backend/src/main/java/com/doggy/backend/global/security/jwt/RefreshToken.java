package com.doggy.backend.global.security.jwt;

import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "refresh_tokens",
        indexes = {
                @Index(name = "idx_refresh_tokens_user_active", columnList = "user_id, revoked_at"),
                @Index(name = "idx_refresh_tokens_expires_at", columnList = "expires_at")
        }
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class RefreshToken extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "token_id", nullable = false, unique = true, length = 36)
    private String tokenId;

    @Column(name = "token_hash", nullable = false, unique = true, length = 64)
    private String tokenHash;

    @Column(name = "device_id", length = 128)
    private String deviceId;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "last_used_at")
    private LocalDateTime lastUsedAt;

    @Column(name = "revoked_at")
    private LocalDateTime revokedAt;

    public RefreshToken(User user, String tokenId, String tokenHash, String deviceId, LocalDateTime expiresAt) {
        this.user = user;
        this.tokenId = tokenId;
        this.tokenHash = tokenHash;
        this.deviceId = deviceId;
        this.expiresAt = expiresAt;
    }

    public boolean isActive(LocalDateTime now) {
        return revokedAt == null && expiresAt.isAfter(now);
    }

    public void markUsed(LocalDateTime now) {
        this.lastUsedAt = now;
    }

    public void revoke(LocalDateTime now) {
        if (revokedAt == null) {
            this.revokedAt = now;
        }
    }
}
