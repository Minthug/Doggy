package com.doggy.backend.global.appversion;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AppVersionServiceTest {

    @Test
    void requiresUpdateWhenCurrentVersionIsLowerThanMinimum() {
        AppVersionService service = new AppVersionService(properties(true, true));

        AppVersionResponse response = service.check("android", "1.0.9");

        assertThat(response.updateRequired()).isTrue();
        assertThat(response.updateRecommended()).isFalse();
        assertThat(service.shouldBlock("android", "1.0.9")).isTrue();
    }

    @Test
    void recommendsUpdateWhenCurrentVersionIsLowerThanLatestOnly() {
        AppVersionService service = new AppVersionService(properties(true, true));

        AppVersionResponse response = service.check("ios", "1.1.0");

        assertThat(response.updateRequired()).isFalse();
        assertThat(response.updateRecommended()).isTrue();
        assertThat(service.shouldBlock("ios", "1.1.0")).isFalse();
    }

    @Test
    void doesNotBlockWhenEnforcementIsDisabled() {
        AppVersionService service = new AppVersionService(properties(true, false));

        assertThat(service.shouldBlock("android", "1.0.0")).isFalse();
    }

    @Test
    void ignoresBuildMetadataWhenComparingVersions() {
        AppVersionService service = new AppVersionService(properties(true, true));

        AppVersionResponse response = service.check("android", "1.1.0+1");

        assertThat(response.updateRequired()).isFalse();
    }

    private AppVersionProperties properties(boolean checkEnabled, boolean enforceMinimum) {
        AppVersionProperties.PlatformVersion android =
                new AppVersionProperties.PlatformVersion("1.1.0", "1.2.0", "https://play.google.com/store/apps/details?id=com.doggy");
        AppVersionProperties.PlatformVersion ios =
                new AppVersionProperties.PlatformVersion("1.1.0", "1.2.0", "https://apps.apple.com/app/doggy");
        return new AppVersionProperties(checkEnabled, enforceMinimum, android, ios);
    }
}
