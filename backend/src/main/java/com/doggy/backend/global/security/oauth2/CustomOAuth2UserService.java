package com.doggy.backend.global.security.oauth2;

import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.entity.UserAuth;
import com.doggy.backend.domain.user.entity.UserAuth.AuthType;
import com.doggy.backend.domain.user.repository.UserAuthRepository;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.security.UserPrincipal;
import lombok.RequiredArgsConstructor;
import org.springframework.security.oauth2.client.userinfo.DefaultOAuth2UserService;
import org.springframework.security.oauth2.client.userinfo.OAuth2UserRequest;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CustomOAuth2UserService extends DefaultOAuth2UserService {

    private final UserRepository userRepository;
    private final UserAuthRepository userAuthRepository;

    @Override
    @Transactional
    public OAuth2User loadUser(OAuth2UserRequest userRequest) throws OAuth2AuthenticationException {
        OAuth2User oAuth2User = super.loadUser(userRequest);

        String provider = userRequest.getClientRegistration().getRegistrationId();
        OAuth2UserInfo userInfo = OAuth2UserInfo.of(provider, oAuth2User.getAttributes());
        AuthType authType = AuthType.valueOf(provider.toUpperCase());

        User user = userAuthRepository.findByAuthTypeAndProviderId(authType, userInfo.getProviderId())
                .map(UserAuth::getUser)
                .orElseGet(() -> createUser(userInfo, authType));

        return UserPrincipal.ofOAuth2(user, oAuth2User.getAttributes());
    }

    private User createUser(OAuth2UserInfo userInfo, AuthType authType) {
        User user = userRepository.save(
                User.builder()
                        .nickname(userInfo.getNickname())
                        .profileImage(userInfo.getProfileImage())
                        .build()
        );

        userAuthRepository.save(
                UserAuth.builder()
                        .user(user)
                        .authType(authType)
                        .email(userInfo.getEmail())
                        .providerId(userInfo.getProviderId())
                        .build()
        );

        return user;
    }
}
