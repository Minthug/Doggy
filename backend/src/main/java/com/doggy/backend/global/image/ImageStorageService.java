package com.doggy.backend.global.image;

import org.springframework.web.multipart.MultipartFile;

public interface ImageStorageService {
    String store(MultipartFile file, Long userId);
    void validateOwner(String imageUrl, Long userId);
    void delete(String imageUrl, Long userId);
}
