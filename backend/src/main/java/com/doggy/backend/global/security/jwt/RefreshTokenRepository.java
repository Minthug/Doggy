package com.doggy.backend.global.security.jwt;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Optional;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    @Modifying
    @Query("""
            UPDATE RefreshToken t
            SET t.revokedAt = :revokedAt
            WHERE t.user.id = :userId AND t.revokedAt IS NULL
            """)
    int revokeActiveTokensByUserId(@Param("userId") Long userId, @Param("revokedAt") LocalDateTime revokedAt);

    long deleteByExpiresAtBefore(LocalDateTime expiresAt);
}
