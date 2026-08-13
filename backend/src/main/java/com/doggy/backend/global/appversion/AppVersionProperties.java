package com.doggy.backend.global.appversion;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.version")
public record AppVersionProperties(
        Boolean checkEnabled,
        Boolean enforceMinimum,
        PlatformVersion android,
        PlatformVersion ios
) {

    public AppVersionProperties {
        if (checkEnabled == null) {
            checkEnabled = true;
        }
        if (enforceMinimum == null) {
            enforceMinimum = false;
        }
        if (android == null) {
            android = new PlatformVersion("1.0.0", "1.0.0", "");
        }
        if (ios == null) {
            ios = new PlatformVersion("1.0.0", "1.0.0", "");
        }
    }

    public PlatformVersion policyFor(AppPlatform platform) {
        return platform == AppPlatform.IOS ? ios : android;
    }

    public record PlatformVersion(
            String minimum,
            String latest,
            String storeUrl
    ) {

        public PlatformVersion {
            if (minimum == null || minimum.isBlank()) {
                minimum = "1.0.0";
            }
            if (latest == null || latest.isBlank()) {
                latest = minimum;
            }
            if (storeUrl == null) {
                storeUrl = "";
            }
        }
    }
}
