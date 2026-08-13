package com.doggy.backend.global.appversion;

public record AppVersionResponse(
        String platform,
        String currentVersion,
        String minimumVersion,
        String latestVersion,
        boolean updateRequired,
        boolean updateRecommended,
        String storeUrl,
        String message
) {
}
