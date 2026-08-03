package com.doggy.backend.global.ratelimit;

import com.doggy.backend.global.exception.BusinessException;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Locale;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class RateLimitService {

    private static final int LOGIN_LIMIT = 10;
    private static final Duration LOGIN_WINDOW = Duration.ofMinutes(5);
    private static final int SIGNUP_LIMIT = 5;
    private static final Duration SIGNUP_WINDOW = Duration.ofHours(1);
    private static final int REFRESH_LIMIT = 30;
    private static final Duration REFRESH_WINDOW = Duration.ofMinutes(1);
    private static final int OAUTH2_EXCHANGE_LIMIT = 20;
    private static final Duration OAUTH2_EXCHANGE_WINDOW = Duration.ofMinutes(1);
    private static final int IMAGE_UPLOAD_LIMIT = 10;
    private static final Duration IMAGE_UPLOAD_WINDOW = Duration.ofMinutes(1);

    private final ConcurrentHashMap<String, Bucket> buckets = new ConcurrentHashMap<>();

    public void checkLogin(HttpServletRequest request, String email) {
        check("login:" + clientIp(request) + ":" + normalize(email), LOGIN_LIMIT, LOGIN_WINDOW);
    }

    public void checkSignup(HttpServletRequest request) {
        check("signup:" + clientIp(request), SIGNUP_LIMIT, SIGNUP_WINDOW);
    }

    public void checkRefresh(HttpServletRequest request) {
        check("refresh:" + clientIp(request), REFRESH_LIMIT, REFRESH_WINDOW);
    }

    public void checkOAuth2Exchange(HttpServletRequest request) {
        check("oauth2-exchange:" + clientIp(request), OAUTH2_EXCHANGE_LIMIT, OAUTH2_EXCHANGE_WINDOW);
    }

    public void checkImageUpload(Long userId, HttpServletRequest request) {
        String subject = userId != null ? "user:" + userId : "ip:" + clientIp(request);
        check("image-upload:" + subject, IMAGE_UPLOAD_LIMIT, IMAGE_UPLOAD_WINDOW);
    }

    private void check(String key, int maxRequests, Duration window) {
        long now = System.currentTimeMillis();
        long windowMillis = window.toMillis();
        Bucket bucket = buckets.compute(key, (ignored, current) -> {
            if (current == null || now >= current.resetAtMillis()) {
                return new Bucket(1, now + windowMillis);
            }
            int count = Math.min(current.count() + 1, maxRequests + 1);
            return new Bucket(count, current.resetAtMillis());
        });

        if (bucket.count() > maxRequests) {
            throw BusinessException.tooManyRequests("요청이 너무 많습니다. 잠시 후 다시 시도해주세요");
        }
    }

    private String clientIp(HttpServletRequest request) {
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

    private String normalize(String value) {
        if (value == null || value.isBlank()) {
            return "unknown";
        }
        String clean = value.trim().toLowerCase(Locale.ROOT);
        return clean.length() <= 255 ? clean : clean.substring(0, 255);
    }

    @Scheduled(fixedDelay = 300_000)
    void cleanupExpiredBuckets() {
        long now = System.currentTimeMillis();
        buckets.entrySet().removeIf(entry -> now >= entry.getValue().resetAtMillis());
    }

    private record Bucket(int count, long resetAtMillis) {
    }
}
