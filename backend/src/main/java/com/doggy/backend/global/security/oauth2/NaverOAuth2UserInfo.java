package com.doggy.backend.global.security.oauth2;

import java.util.Map;

public class NaverOAuth2UserInfo extends OAuth2UserInfo {

    private final Map<String, Object> response;

    @SuppressWarnings("unchecked")
    public NaverOAuth2UserInfo(Map<String, Object> attributes) {
        super(attributes);
        this.response = (Map<String, Object>) attributes.get("response");
    }

    @Override
    public String getProviderId() {
        return (String) response.get("id");
    }

    @Override
    public String getEmail() {
        return (String) response.get("email");
    }

    @Override
    public String getNickname() {
        return (String) response.get("name");
    }

    @Override
    public String getProfileImage() {
        return (String) response.get("profile_image");
    }
}
