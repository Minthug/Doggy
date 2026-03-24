package com.doggy.backend.domain.user.repository;

import com.doggy.backend.domain.user.entity.UserAuth;
import com.doggy.backend.domain.user.entity.UserAuth.AuthType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserAuthRepository extends JpaRepository<UserAuth, Long> {

    Optional<UserAuth> findByAuthTypeAndEmail(AuthType authType, String email);

    Optional<UserAuth> findByAuthTypeAndProviderId(AuthType authType, String providerId);

    boolean existsByAuthTypeAndEmail(AuthType authType, String email);
}
