package com.doggy.backend.global.appversion;

public enum AppPlatform {
    ANDROID,
    IOS,
    UNKNOWN;

    public static AppPlatform from(String value) {
        if (value == null || value.isBlank()) {
            return UNKNOWN;
        }
        return switch (value.trim().toLowerCase()) {
            case "android" -> ANDROID;
            case "ios" -> IOS;
            default -> UNKNOWN;
        };
    }

    public String headerValue() {
        return name().toLowerCase();
    }
}
