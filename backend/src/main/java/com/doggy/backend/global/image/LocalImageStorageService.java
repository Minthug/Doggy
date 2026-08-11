package com.doggy.backend.global.image;

import com.doggy.backend.global.alert.AlertService;
import com.doggy.backend.global.exception.BusinessException;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;

@Slf4j
@Service
public class LocalImageStorageService implements ImageStorageService {

    private final AlertService alertService;
    private final ImageStorageProperties properties;
    private Path uploadPath;

    public LocalImageStorageService(AlertService alertService, ImageStorageProperties properties) {
        this.alertService = alertService;
        this.properties = properties;
    }

    @PostConstruct
    public void init() {
        uploadPath = properties.uploadPath();
        try {
            Files.createDirectories(uploadPath);
        } catch (IOException e) {
            throw new IllegalStateException("이미지 업로드 디렉터리 생성 실패: " + properties.getUpload().getDir(), e);
        }
    }

    @Override
    public String store(MultipartFile file) {
        ImageType imageType = validate(file);

        String filename = UUID.randomUUID() + imageType.extension;
        Path dest = uploadPath.resolve(filename);

        try {
            file.transferTo(dest);
        } catch (IOException e) {
            log.error("이미지 저장 실패: {}", filename, e);
            alertService.recordImageStorageFailure(e.getMessage());
            throw BusinessException.internalError("이미지 저장에 실패했습니다");
        }

        return properties.publicUrl(filename);
    }

    @Override
    public void delete(String imageUrl) {
        String filename = properties.stripPublicPrefix(imageUrl);
        if (filename == null) {
            return;
        }
        Path target = uploadPath.resolve(filename).normalize();
        if (!target.startsWith(uploadPath)) {
            log.warn("이미지 삭제 경로가 업로드 디렉터리 밖을 가리킵니다: {}", filename);
            return;
        }
        try {
            Files.deleteIfExists(target);
        } catch (IOException e) {
            log.warn("이미지 삭제 실패: {}", filename, e);
        }
    }

    private ImageType validate(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw BusinessException.badRequest("파일이 비어 있습니다");
        }
        if (file.getSize() > properties.getMaxSizeBytes()) {
            throw BusinessException.badRequest("파일 크기는 " + maxSizeMb() + "MB 이하여야 합니다");
        }
        String contentType = file.getContentType();
        ImageType imageType = detectImageType(file);
        if (imageType == null || contentType == null || !imageType.contentType.equals(contentType)) {
            throw BusinessException.badRequest("지원하지 않는 파일 형식입니다 (jpeg, png, webp만 가능)");
        }
        return imageType;
    }

    private ImageType detectImageType(MultipartFile file) {
        byte[] header;
        try {
            header = file.getInputStream().readNBytes(12);
        } catch (IOException e) {
            throw BusinessException.badRequest("파일을 읽을 수 없습니다");
        }

        if (isJpeg(header)) return ImageType.JPEG;
        if (isPng(header)) return ImageType.PNG;
        if (isWebp(header)) return ImageType.WEBP;
        return null;
    }

    private boolean isJpeg(byte[] header) {
        return header.length >= 3
                && unsigned(header[0]) == 0xFF
                && unsigned(header[1]) == 0xD8
                && unsigned(header[2]) == 0xFF;
    }

    private boolean isPng(byte[] header) {
        return header.length >= 8
                && unsigned(header[0]) == 0x89
                && header[1] == 0x50
                && header[2] == 0x4E
                && header[3] == 0x47
                && header[4] == 0x0D
                && header[5] == 0x0A
                && header[6] == 0x1A
                && header[7] == 0x0A;
    }

    private boolean isWebp(byte[] header) {
        return header.length >= 12
                && header[0] == 0x52
                && header[1] == 0x49
                && header[2] == 0x46
                && header[3] == 0x46
                && header[8] == 0x57
                && header[9] == 0x45
                && header[10] == 0x42
                && header[11] == 0x50;
    }

    private int unsigned(byte b) {
        return b & 0xFF;
    }

    private long maxSizeMb() {
        return properties.getMaxSizeBytes() / (1024 * 1024);
    }

    private enum ImageType {
        JPEG("image/jpeg", ".jpg"),
        PNG("image/png", ".png"),
        WEBP("image/webp", ".webp");

        private final String contentType;
        private final String extension;

        ImageType(String contentType, String extension) {
            this.contentType = contentType;
            this.extension = extension;
        }
    }
}
