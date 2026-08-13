package com.doggy.backend.global.appversion;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AppVersionService {

    public static final String APP_VERSION_HEADER = "X-App-Version";
    public static final String APP_PLATFORM_HEADER = "X-App-Platform";

    private final AppVersionProperties properties;

    public AppVersionResponse check(String platformValue, String currentVersionValue) {
        AppPlatform platform = AppPlatform.from(platformValue);
        AppVersionProperties.PlatformVersion policy = properties.policyFor(platform);
        String currentVersion = cleanVersion(currentVersionValue);
        boolean updateRequired = isLowerThan(currentVersion, policy.minimum());
        boolean updateRecommended = !updateRequired && isLowerThan(currentVersion, policy.latest());

        return new AppVersionResponse(
                platform.headerValue(),
                currentVersion,
                policy.minimum(),
                policy.latest(),
                updateRequired,
                updateRecommended,
                policy.storeUrl(),
                message(updateRequired, updateRecommended)
        );
    }

    public boolean shouldBlock(String platformValue, String currentVersionValue) {
        return properties.checkEnabled()
                && properties.enforceMinimum()
                && check(platformValue, currentVersionValue).updateRequired();
    }

    public boolean isCheckEnabled() {
        return properties.checkEnabled();
    }

    private boolean isLowerThan(String currentVersion, String targetVersion) {
        return SemanticVersion.parse(currentVersion).compareTo(SemanticVersion.parse(targetVersion)) < 0;
    }

    private String cleanVersion(String value) {
        if (value == null || value.isBlank()) {
            return "0.0.0";
        }
        return value.trim();
    }

    private String message(boolean updateRequired, boolean updateRecommended) {
        if (updateRequired) {
            return "앱 업데이트가 필요합니다";
        }
        if (updateRecommended) {
            return "새 앱 버전이 있습니다";
        }
        return "";
    }
}
