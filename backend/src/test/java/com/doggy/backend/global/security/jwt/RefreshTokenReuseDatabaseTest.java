package com.doggy.backend.global.security.jwt;

import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.domain.user.service.UserService;
import com.doggy.backend.global.config.QueryDslConfig;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.image.ImageStorageService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import({JwtProvider.class, RefreshTokenService.class, UserService.class, QueryDslConfig.class})
@TestPropertySource(properties = {
        "jwt.secret=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=",
        "jwt.access-token-expiry=3600000",
        "jwt.refresh-token-expiry=2592000000",
        "spring.jpa.hibernate.ddl-auto=validate"
})
@Transactional(propagation = Propagation.NOT_SUPPORTED)
@EnabledIfEnvironmentVariable(
        named = "DOGGY_AUTH_TEST_DB_URL",
        matches = "jdbc:postgresql://(localhost|127\\.0\\.0\\.1):[0-9]+/doggy_auth_tx_test")
class RefreshTokenReuseDatabaseTest {

    @DynamicPropertySource
    static void database(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> System.getenv("DOGGY_AUTH_TEST_DB_URL"));
        registry.add("spring.datasource.username", () -> "doggy");
        registry.add("spring.datasource.password", () -> "doggy");
    }

    @Autowired UserRepository userRepository;
    @Autowired RefreshTokenRepository refreshTokenRepository;
    @Autowired RefreshTokenService refreshTokenService;
    @Autowired UserService userService;
    @MockitoBean PasswordEncoder passwordEncoder;
    @MockitoBean ImageStorageService imageStorageService;

    @Test
    void reusedTokenRevokesNewTokenEvenAfterUnauthorizedResponse() {
        User user = userRepository.save(User.builder().nickname("auth-tx-test").build());
        var first = refreshTokenService.issueTokens(user, "test-device");
        var second = userService.refresh(first.refreshToken(), "test-device");

        assertThatThrownBy(() -> userService.refresh(first.refreshToken(), "test-device"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("유효하지 않은 리프레시 토큰");

        var tokens = refreshTokenRepository.findAll().stream()
                .filter(token -> token.getUser().getId().equals(user.getId()))
                .toList();
        assertThat(tokens).hasSize(2).allMatch(token -> token.getRevokedAt() != null);
        assertThat(second.refreshToken()).isNotEqualTo(first.refreshToken());
    }
}
