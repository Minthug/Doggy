package com.doggy.backend.global.security;

import com.doggy.backend.domain.user.entity.User;
import lombok.Getter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.oauth2.core.user.OAuth2User;

import java.util.Collection;
import java.util.List;
import java.util.Map;

@Getter
public class UserPrincipal implements UserDetails, OAuth2User {

    private final Long id;
    private final String password;
    private Map<String, Object> attributes;

    private UserPrincipal(Long id, String password) {
        this.id = id;
        this.password = password;
    }

    public static UserPrincipal of(User user, String passwordHash) {
        return new UserPrincipal(user.getId(), passwordHash);
    }

    public static UserPrincipal ofOAuth2(User user, Map<String, Object> attributes) {
        UserPrincipal principal = new UserPrincipal(user.getId(), null);
        principal.attributes = attributes;
        return principal;
    }

    @Override
    public Map<String, Object> getAttributes() {
        return attributes;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_USER"));
    }

    @Override
    public String getUsername() {
        return String.valueOf(id);
    }

    @Override
    public String getName() {
        return String.valueOf(id);
    }
}
