package com.doggy.backend.global.image;

import com.doggy.backend.global.ratelimit.RateLimitService;
import com.doggy.backend.global.security.UserPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@RestController
@RequestMapping("/api/images")
@RequiredArgsConstructor
public class ImageController {

    private final ImageStorageService imageStorageService;
    private final RateLimitService rateLimitService;

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<Map<String, String>> upload(
            @AuthenticationPrincipal UserPrincipal principal,
            HttpServletRequest servletRequest,
            @RequestParam("file") MultipartFile file) {
        rateLimitService.checkImageUpload(principal != null ? principal.getId() : null, servletRequest);
        String url = imageStorageService.store(file);
        return ResponseEntity.ok(Map.of("url", url));
    }
}
