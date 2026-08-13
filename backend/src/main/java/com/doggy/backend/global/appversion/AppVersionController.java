package com.doggy.backend.global.appversion;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/app")
@RequiredArgsConstructor
public class AppVersionController {

    private final AppVersionService appVersionService;

    @GetMapping("/version")
    public ResponseEntity<AppVersionResponse> checkVersion(
            @RequestHeader(value = AppVersionService.APP_PLATFORM_HEADER, required = false) String platform,
            @RequestHeader(value = AppVersionService.APP_VERSION_HEADER, required = false) String version
    ) {
        return ResponseEntity.ok(appVersionService.check(platform, version));
    }
}
