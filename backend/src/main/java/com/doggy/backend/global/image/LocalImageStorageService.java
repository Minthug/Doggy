package com.doggy.backend.global.image;

import com.doggy.backend.global.exception.BusinessException;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
public class LocalImageStorageService implements ImageStorageService {

    private static final long MAX_SIZE = 5 * 1024 * 1024L; // 5MB
    private static final Set<String> ALLOWED_TYPES = Set.of("image/jpeg", "image/png", "image/webp");

    @Value("${image.upload.dir:/var/doggy/images}")
    private String uploadDir;

    @Value("${SERVER_BASE_URL:http://localhost:8080}")
    private String serverBaseUrl;

    private Path uploadPath;

    @PostConstruct
    public void init() {
        uploadPath = Paths.get(uploadDir);
        try {
            Files.createDirectories(uploadPath);
        } catch (IOException e) {
            throw new IllegalStateException("이미지 업로드 디렉터리 생성 실패: " + uploadDir, e);
        }
    }

    @Override
    public String store(MultipartFile file) {
        validate(file);

        String ext = extractExtension(file.getOriginalFilename());
        String filename = UUID.randomUUID() + ext;
        Path dest = uploadPath.resolve(filename);

        try {
            file.transferTo(dest);
        } catch (IOException e) {
            log.error("이미지 저장 실패: {}", filename, e);
            throw BusinessException.internalError("이미지 저장에 실패했습니다");
        }

        return serverBaseUrl + "/images/" + filename;
    }

    @Override
    public void delete(String imageUrl) {
        if (imageUrl == null || !imageUrl.startsWith(serverBaseUrl + "/images/")) {
            return;
        }
        String filename = imageUrl.substring((serverBaseUrl + "/images/").length());
        Path target = uploadPath.resolve(filename);
        try {
            Files.deleteIfExists(target);
        } catch (IOException e) {
            log.warn("이미지 삭제 실패: {}", filename, e);
        }
    }

    private void validate(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw BusinessException.badRequest("파일이 비어 있습니다");
        }
        if (file.getSize() > MAX_SIZE) {
            throw BusinessException.badRequest("파일 크기는 5MB 이하여야 합니다");
        }
        String contentType = file.getContentType();
        if (contentType == null || !ALLOWED_TYPES.contains(contentType)) {
            throw BusinessException.badRequest("지원하지 않는 파일 형식입니다 (jpeg, png, webp만 가능)");
        }
    }

    private String extractExtension(String filename) {
        if (filename == null || !filename.contains(".")) return ".jpg";
        return filename.substring(filename.lastIndexOf('.'));
    }
}
