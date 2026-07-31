package com.doggy.backend.global.security.oauth2;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;

import java.time.LocalDateTime;
import java.util.Optional;

public interface OAuth2LoginCodeRepository extends JpaRepository<OAuth2LoginCode, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<OAuth2LoginCode> findByCodeHash(String codeHash);

    long deleteByExpiresAtBefore(LocalDateTime expiresAt);
}
