package com.doggy.backend.global.alert;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Service
@RequiredArgsConstructor
public class DiscordAlertService implements AlertService {

    private static final int MAX_MESSAGE_LENGTH = 500;

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ConcurrentHashMap<String, WindowCounter> counters = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Long> cooldownUntil = new ConcurrentHashMap<>();

    @Value("${alert.discord.webhook-url:}")
    private String webhookUrl;

    @Value("${alert.window-seconds:300}")
    private long windowSeconds;

    @Value("${alert.cooldown-seconds:300}")
    private long cooldownSeconds;

    @Value("${alert.server-error.threshold:10}")
    private int serverErrorThreshold;

    @Value("${alert.db-error.threshold:1}")
    private int dbErrorThreshold;

    @Value("${alert.rate-limit.threshold:50}")
    private int rateLimitThreshold;

    @Value("${alert.image-storage.threshold:3}")
    private int imageStorageThreshold;

    @Override
    public void recordServerError(String path, Throwable error, String requestId) {
        String type = isDatabaseError(error) ? "DB_ERROR" : "SERVER_ERROR";
        int threshold = isDatabaseError(error) ? dbErrorThreshold : serverErrorThreshold;
        record(type, threshold, Map.of(
                "path", value(path),
                "requestId", value(requestId),
                "message", truncate(error.getMessage())
        ));
    }

    @Override
    public void recordRateLimitExceeded(String event, String path, String clientIp) {
        record("RATE_LIMIT_SPIKE:" + value(event), rateLimitThreshold, Map.of(
                "event", value(event),
                "path", value(path),
                "clientIp", value(clientIp),
                "requestId", value(MDC.get("requestId"))
        ));
    }

    @Override
    public void recordImageStorageFailure(String message) {
        record("IMAGE_STORAGE_FAILURE", imageStorageThreshold, Map.of(
                "message", truncate(message),
                "requestId", value(MDC.get("requestId"))
        ));
    }

    private void record(String type, int threshold, Map<String, String> fields) {
        if (threshold <= 0) {
            return;
        }

        long now = System.currentTimeMillis();
        long windowMillis = Duration.ofSeconds(windowSeconds).toMillis();
        WindowCounter counter = counters.compute(type, (ignored, current) -> {
            if (current == null || now >= current.resetAtMillis()) {
                return new WindowCounter(1, now + windowMillis);
            }
            return new WindowCounter(current.count() + 1, current.resetAtMillis());
        });

        if (counter.count() < threshold || isCoolingDown(type, now)) {
            return;
        }

        cooldownUntil.put(type, now + Duration.ofSeconds(cooldownSeconds).toMillis());
        send(type, counter.count(), windowSeconds, fields);
    }

    private boolean isCoolingDown(String type, long now) {
        return cooldownUntil.getOrDefault(type, 0L) > now;
    }

    private void send(String type, int count, long windowSeconds, Map<String, String> fields) {
        if (webhookUrl == null || webhookUrl.isBlank()) {
            log.debug("Discord alert webhook is not configured. type={} count={}", type, count);
            return;
        }

        String content = formatMessage(type, count, windowSeconds, fields);
        String body;
        try {
            body = objectMapper.writeValueAsString(Map.of("content", content));
        } catch (JsonProcessingException e) {
            log.warn("Discord alert payload serialization failed: {}", e.getMessage());
            return;
        }

        HttpRequest request = HttpRequest.newBuilder(URI.create(webhookUrl))
                .timeout(Duration.ofSeconds(3))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

        httpClient.sendAsync(request, HttpResponse.BodyHandlers.discarding())
                .thenAccept(response -> {
                    if (response.statusCode() >= 300) {
                        log.warn("Discord alert failed status={} type={}", response.statusCode(), type);
                    }
                })
                .exceptionally(error -> {
                    log.warn("Discord alert request failed type={} message={}", type, error.getMessage());
                    return null;
                });
    }

    private String formatMessage(String type, int count, long windowSeconds, Map<String, String> fields) {
        StringBuilder builder = new StringBuilder();
        builder.append("[Doggy API Alert]\n");
        builder.append("type: ").append(type).append('\n');
        builder.append("count: ").append(count).append(" / ").append(windowSeconds).append("s");
        fields.forEach((key, value) -> builder.append('\n').append(key).append(": ").append(value));
        return builder.toString();
    }

    private boolean isDatabaseError(Throwable error) {
        Throwable current = error;
        while (current != null) {
            String name = current.getClass().getName().toLowerCase();
            String message = current.getMessage() != null ? current.getMessage().toLowerCase() : "";
            if (name.contains("sql") || name.contains("jdbc") || message.contains("database")
                    || message.contains("connection")) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }

    private String truncate(String value) {
        String clean = value(value);
        return clean.length() <= MAX_MESSAGE_LENGTH ? clean : clean.substring(0, MAX_MESSAGE_LENGTH);
    }

    private String value(String value) {
        return value == null || value.isBlank() ? "unknown" : value;
    }

    private record WindowCounter(int count, long resetAtMillis) {
    }
}
