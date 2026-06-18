package com.doggy.backend.global.image;

import org.springframework.web.multipart.MultipartFile;

public interface ImageStorageService {
    String store(MultipartFile file);
    void delete(String imageUrl);
}
