package com.doggy.backend.global.alert;

public interface AlertService {

    void recordServerError(String path, Throwable error, String requestId);

    void recordRateLimitExceeded(String event, String path, String clientIp);

    void recordImageStorageFailure(String message);

    static AlertService noop() {
        return new AlertService() {
            @Override
            public void recordServerError(String path, Throwable error, String requestId) {
            }

            @Override
            public void recordRateLimitExceeded(String event, String path, String clientIp) {
            }

            @Override
            public void recordImageStorageFailure(String message) {
            }
        };
    }
}
