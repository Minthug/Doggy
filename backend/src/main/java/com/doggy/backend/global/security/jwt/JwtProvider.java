package com.doggy.backend.global.security.jwt;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.util.Base64;
import java.util.Date;

@Slf4j
@Component
public class JwtProvider {

    private static final String TOKEN_TYPE_CLAIM = "tokenType";

    private final SecretKey secretKey;
    private final long accessTokenExpiry;
    private final long refreshTokenExpiry;

    public JwtProvider(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.access-token-expiry}") long accessTokenExpiry,
            @Value("${jwt.refresh-token-expiry}") long refreshTokenExpiry
    ) {
        this.secretKey = Keys.hmacShaKeyFor(Base64.getDecoder().decode(secret));
        this.accessTokenExpiry = accessTokenExpiry;
        this.refreshTokenExpiry = refreshTokenExpiry;
    }

    public String generateAccessToken(Long userId) {
        return generateToken(userId, accessTokenExpiry, TokenType.ACCESS);
    }

    public String generateRefreshToken(Long userId) {
        return generateToken(userId, refreshTokenExpiry, TokenType.REFRESH);
    }

    private String generateToken(Long userId, long expiry, TokenType tokenType) {
        Date now = new Date();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim(TOKEN_TYPE_CLAIM, tokenType.name())
                .issuedAt(now)
                .expiration(new Date(now.getTime() + expiry))
                .signWith(secretKey)
                .compact();
    }

    public Long getUserId(String token) {
        return Long.parseLong(parseClaims(token).getSubject());
    }

    public boolean validateAccessToken(String token) {
        return validate(token, TokenType.ACCESS);
    }

    public boolean validateRefreshToken(String token) {
        return validate(token, TokenType.REFRESH);
    }

    private boolean validate(String token, TokenType expectedType) {
        try {
            Claims claims = parseClaims(token);
            return expectedType.name().equals(claims.get(TOKEN_TYPE_CLAIM, String.class));
        } catch (ExpiredJwtException e) {
            log.debug("만료된 JWT 토큰: {}", e.getMessage());
        } catch (JwtException | IllegalArgumentException e) {
            log.debug("유효하지 않은 JWT 토큰: {}", e.getMessage());
        }
        return false;
    }

    private Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    private enum TokenType {
        ACCESS, REFRESH
    }
}
