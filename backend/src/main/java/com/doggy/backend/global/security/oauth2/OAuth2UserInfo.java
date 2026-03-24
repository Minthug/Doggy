package com.doggy.backend.global.security.oauth2;

import java.util.Map;

public abstract class OAuth2UserInfo {

    protected final Map<String, Object> attributes;

    protected OAuth2UserInfo(Map<String, Object> attributes) {
        this.attributes = attributes;
    }

    public abstract String getProviderId();
    public abstract String getEmail();
    public abstract String getNickname();
    public abstract String getProfileImage();

    public static OAuth2UserInfo of(String provider, Map<String, Object> attributes) {
        return switch (provider.toLowerCase()) {
            case "kakao"  -> new KakaoOAuth2UserInfo(attributes);
            case "google" -> new GoogleOAuth2UserInfo(attributes);
            case "naver"  -> new NaverOAuth2UserInfo(attributes);
            default -> throw new IllegalArgumentException("지원하지 않는 OAuth2 provider: " + provider);
        };
    }
}
