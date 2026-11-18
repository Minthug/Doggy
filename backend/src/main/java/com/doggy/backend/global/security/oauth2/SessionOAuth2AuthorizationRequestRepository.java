package com.doggy.backend.global.security.oauth2;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.security.oauth2.client.web.AuthorizationRequestRepository;
import org.springframework.security.oauth2.client.web.HttpSessionOAuth2AuthorizationRequestRepository;
import org.springframework.security.oauth2.core.endpoint.OAuth2AuthorizationRequest;
import org.springframework.stereotype.Component;

@Component
public class SessionOAuth2AuthorizationRequestRepository
        implements AuthorizationRequestRepository<OAuth2AuthorizationRequest> {

    private static final String APP_CHALLENGE_ATTRIBUTE =
            SessionOAuth2AuthorizationRequestRepository.class.getName() + ".appChallenge";
    private static final int SESSION_EXPIRE_SECONDS = 180;

    private final HttpSessionOAuth2AuthorizationRequestRepository delegate =
            new HttpSessionOAuth2AuthorizationRequestRepository();

    @Override
    public OAuth2AuthorizationRequest loadAuthorizationRequest(HttpServletRequest request) {
        return delegate.loadAuthorizationRequest(request);
    }

    @Override
    public void saveAuthorizationRequest(OAuth2AuthorizationRequest authorizationRequest,
                                         HttpServletRequest request, HttpServletResponse response) {
        if (authorizationRequest == null) {
            delegate.saveAuthorizationRequest(null, request, response);
            HttpSession session = request.getSession(false);
            if (session != null) session.removeAttribute(APP_CHALLENGE_ATTRIBUTE);
            return;
        }

        String challenge = request.getParameter("app_challenge");
        if (challenge == null || !challenge.matches("[A-Za-z0-9_-]{43}")) {
            throw new IllegalArgumentException("OAuth2 앱 검증값이 필요합니다");
        }

        delegate.saveAuthorizationRequest(authorizationRequest, request, response);
        HttpSession session = request.getSession();
        session.setAttribute(APP_CHALLENGE_ATTRIBUTE, challenge);
        session.setMaxInactiveInterval(SESSION_EXPIRE_SECONDS);
    }

    @Override
    public OAuth2AuthorizationRequest removeAuthorizationRequest(HttpServletRequest request,
                                                                  HttpServletResponse response) {
        return delegate.removeAuthorizationRequest(request, response);
    }

    public String consumeAppChallenge(HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        if (session == null) return null;
        Object challenge = session.getAttribute(APP_CHALLENGE_ATTRIBUTE);
        session.removeAttribute(APP_CHALLENGE_ATTRIBUTE);
        return challenge instanceof String value && value.matches("[A-Za-z0-9_-]{43}") ? value : null;
    }
}
