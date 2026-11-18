package com.doggy.backend.global.security.oauth2;

import com.doggy.backend.global.security.UserPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.web.authentication.SimpleUrlAuthenticationSuccessHandler;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
@RequiredArgsConstructor
public class OAuth2SuccessHandler extends SimpleUrlAuthenticationSuccessHandler {

    private final OAuth2LoginCodeService loginCodeService;
    private final SessionOAuth2AuthorizationRequestRepository authorizationRequestRepository;

    @Override
    public void onAuthenticationSuccess(HttpServletRequest request,
                                        HttpServletResponse response,
                                        Authentication authentication) throws IOException {
        UserPrincipal principal = (UserPrincipal) authentication.getPrincipal();

        String challenge = authorizationRequestRepository.consumeAppChallenge(request);
        if (challenge == null) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "OAuth2 앱 로그인 요청이 없습니다");
            return;
        }

        String code = loginCodeService.createCode(principal.getId(), challenge);

        String redirectUrl = "doggy://auth/callback?code=" + code + "&challenge=" + challenge;

        getRedirectStrategy().sendRedirect(request, response, redirectUrl);
    }
}
