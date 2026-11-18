package com.doggy.backend.global.security.oauth2;

import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.oauth2.core.endpoint.OAuth2AuthorizationRequest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SessionOAuth2AuthorizationRequestRepositoryTest {

    private final SessionOAuth2AuthorizationRequestRepository repository =
            new SessionOAuth2AuthorizationRequestRepository();

    @Test
    void authorizationRequestAndAppChallengeSurviveRedirectOnlyInTheSameSession() {
        String challenge = "a".repeat(43);
        MockHttpServletRequest start = new MockHttpServletRequest();
        start.setParameter("app_challenge", challenge);
        MockHttpServletResponse startResponse = new MockHttpServletResponse();
        OAuth2AuthorizationRequest authRequest = authorizationRequest();

        repository.saveAuthorizationRequest(authRequest, start, startResponse);
        assertThat(start.getSession().getMaxInactiveInterval()).isEqualTo(180);
        assertThat(startResponse.getCookie("oauth2_auth_request")).isNull();

        MockHttpServletRequest wrongState = new MockHttpServletRequest();
        wrongState.setSession(start.getSession());
        wrongState.setParameter("state", "other-state");
        assertThat(repository.loadAuthorizationRequest(wrongState)).isNull();

        MockHttpServletRequest callback = new MockHttpServletRequest();
        callback.setSession(start.getSession());
        callback.setParameter("state", "server-state");
        assertThat(repository.loadAuthorizationRequest(callback)).isSameAs(authRequest);
        assertThat(repository.removeAuthorizationRequest(callback, new MockHttpServletResponse()))
                .isSameAs(authRequest);
        assertThat(repository.consumeAppChallenge(callback)).isEqualTo(challenge);
        assertThat(repository.consumeAppChallenge(callback)).isNull();
        assertThat(repository.loadAuthorizationRequest(callback)).isNull();

        MockHttpServletRequest otherBrowser = new MockHttpServletRequest();
        otherBrowser.setParameter("state", "server-state");
        assertThat(repository.loadAuthorizationRequest(otherBrowser)).isNull();
    }

    @Test
    void untrustedLegacyCookieIsIgnoredWithoutDeserialization() {
        MockHttpServletRequest callback = new MockHttpServletRequest();
        callback.setParameter("state", "server-state");
        callback.setCookies(new Cookie("oauth2_auth_request", "rO0ABXNy..."));

        assertThat(repository.loadAuthorizationRequest(callback)).isNull();
        assertThat(repository.consumeAppChallenge(callback)).isNull();
    }

    @Test
    void authorizationRequestWithoutAppChallengeIsRejected() {
        MockHttpServletRequest start = new MockHttpServletRequest();

        assertThatThrownBy(() -> repository.saveAuthorizationRequest(
                authorizationRequest(), start, new MockHttpServletResponse()))
                .isInstanceOf(IllegalArgumentException.class);
        assertThat(start.getSession(false)).isNull();
    }

    private OAuth2AuthorizationRequest authorizationRequest() {
        return OAuth2AuthorizationRequest.authorizationCode()
                .authorizationUri("https://provider.example/authorize")
                .clientId("client")
                .redirectUri("https://api.example/login/oauth2/code/provider")
                .state("server-state")
                .build();
    }
}
