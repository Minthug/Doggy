package com.doggy.backend.global.config;

import com.doggy.backend.global.image.ImageStorageProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
@RequiredArgsConstructor
public class WebConfig implements WebMvcConfigurer {

    private final ImageStorageProperties imageStorageProperties;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler(imageStorageProperties.getPublicPath() + "/**")
                .addResourceLocations(imageStorageProperties.uploadPath().toUri().toString());
    }
}
