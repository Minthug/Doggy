package com.doggy.backend.domain.user.service;

import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.PushSettingRepository;
import com.doggy.backend.domain.user.repository.UserAuthRepository;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.exception.BusinessException;
import com.doggy.backend.global.image.ImageStorageService;
import com.doggy.backend.global.security.jwt.RefreshTokenService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

@ExtendWith(MockitoExtension.class)
class UserFcmTokenServiceTest {

    @Mock UserRepository userRepository;
    @Mock UserAuthRepository userAuthRepository;
    @Mock PushSettingRepository pushSettingRepository;
    @Mock org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;
    @Mock RefreshTokenService refreshTokenService;
    @Mock ImageStorageService imageStorageService;

    private UserService service() {
        return new UserService(userRepository, userAuthRepository, pushSettingRepository,
                passwordEncoder, refreshTokenService, imageStorageService);
    }

    @Test
    void registeringTokenRemovesPreviousAccountAssociation() {
        User secondAccount = User.builder().nickname("B").build();
        given(userRepository.findById(2L)).willReturn(Optional.of(secondAccount));

        service().updateFcmToken(2L, "same-device-token");

        verify(userRepository).clearFcmTokenFromOtherUsers("same-device-token", 2L);
        assertThat(secondAccount.getFcmToken()).isEqualTo("same-device-token");
    }

    @Test
    void logoutRemovesOnlyMatchingUsersToken() {
        service().clearFcmToken(1L, "old-device-token");

        verify(userRepository).clearFcmTokenIfOwned(1L, "old-device-token");
    }

    @Test
    void blankTokenCannotReplaceAnotherAccountAssociation() {
        assertThatThrownBy(() -> service().updateFcmToken(2L, " "))
                .isInstanceOf(BusinessException.class);
        verifyNoInteractions(userRepository);
    }
}
