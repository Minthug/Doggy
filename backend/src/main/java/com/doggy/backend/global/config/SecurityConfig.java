package com.doggy.backend.global.config;

import com.doggy.backend.global.appversion.AppVersionFilter;
import com.doggy.backend.global.security.InternalApiTokenFilter;
import com.doggy.backend.global.security.jwt.JwtAuthenticationFilter;
import com.doggy.backend.global.security.oauth2.CustomOAuth2UserService;
import com.doggy.backend.global.security.oauth2.HttpCookieOAuth2AuthorizationRequestRepository;
import com.doggy.backend.global.security.oauth2.OAuth2SuccessHandler;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import java.util.Map;

@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
@Slf4j
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final InternalApiTokenFilter internalApiTokenFilter;
    private final AppVersionFilter appVersionFilter;
    private final CustomOAuth2UserService customOAuth2UserService;
    private final OAuth2SuccessHandler oAuth2SuccessHandler;
    private final HttpCookieOAuth2AuthorizationRequestRepository cookieAuthorizationRequestRepository;
    private final ObjectMapper objectMapper;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(
                                "/api/auth/**",
                                "/api/app/version",
                                "/login/oauth2/**",
                                "/oauth2/**",
                                "/api/walks/public",
                                "/api/weather/**",
                                "/actuator/health",
                                "/actuator",
                                "/actuator/**",
                                "/api/admin",
                                "/api/admin/**",
                                "/api/internal",
                                "/api/internal/**",
                                "/images/**"
                        ).permitAll()
                        .anyRequest().authenticated()
                )
                .oauth2Login(oauth2 -> oauth2
                        .authorizationEndpoint(endpoint ->
                                endpoint.authorizationRequestRepository(cookieAuthorizationRequestRepository))
                        .userInfoEndpoint(userInfo ->
                                userInfo.userService(customOAuth2UserService))
                        .successHandler(oAuth2SuccessHandler)
                )
                .exceptionHandling(ex -> ex
                        // 인증 없이 보호된 API 접근 시 401
                        .authenticationEntryPoint((request, response, e) -> {
                            log.warn("authentication_required path={} clientIp={}",
                                    request.getRequestURI(), clientIp(request));
                            response.setStatus(HttpStatus.UNAUTHORIZED.value());
                            response.setContentType(MediaType.APPLICATION_JSON_VALUE + ";charset=UTF-8");
                            response.getWriter().write(
                                    objectMapper.writeValueAsString(Map.of("message", "로그인이 필요합니다"))
                            );
                        })
                        // 권한 없을 시 403
                        .accessDeniedHandler((request, response, e) -> {
                            log.warn("access_denied path={} clientIp={}",
                                    request.getRequestURI(), clientIp(request));
                            response.setStatus(HttpStatus.FORBIDDEN.value());
                            response.setContentType(MediaType.APPLICATION_JSON_VALUE + ";charset=UTF-8");
                            response.getWriter().write(
                                    objectMapper.writeValueAsString(Map.of("message", "접근 권한이 없습니다"))
                            );
                        })
                )
                .addFilterBefore(internalApiTokenFilter, UsernamePasswordAuthenticationFilter.class)
                .addFilterBefore(appVersionFilter, UsernamePasswordAuthenticationFilter.class)
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    private String clientIp(jakarta.servlet.http.HttpServletRequest request) {
        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (forwardedFor != null && !forwardedFor.isBlank()) {
            return cleanIp(forwardedFor.split(",")[0]);
        }
        String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isBlank()) {
            return cleanIp(realIp);
        }
        return cleanIp(request.getRemoteAddr());
    }

    private String cleanIp(String value) {
        if (value == null || value.isBlank()) {
            return "unknown";
        }
        String clean = value.trim();
        return clean.length() <= 128 ? clean : clean.substring(0, 128);
    }
}
