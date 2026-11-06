package com.doggy.backend.global.image;

import com.doggy.backend.global.alert.AlertService;
import com.doggy.backend.global.exception.BusinessException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class LocalImageStorageServiceTest {

    private static final String SERVER_BASE_URL = "https://api.example.com";

    @TempDir
    Path tempDir;

    private LocalImageStorageService service;

    @BeforeEach
    void setUp() {
        ImageStorageProperties properties = new ImageStorageProperties();
        properties.getUpload().setDir(tempDir.toString());
        properties.setPublicBaseUrl(SERVER_BASE_URL);
        service = new LocalImageStorageService(AlertService.noop(), properties);
        service.init();
    }

    @Test
    void storeRejectsSpoofedContentType() {
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "payload.jpg",
                "image/jpeg",
                "<script>alert(1)</script>".getBytes()
        );

        assertThatThrownBy(() -> service.store(file, 1L))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("지원하지 않는 파일 형식");
    }

    @Test
    void storeUsesDetectedExtensionInsteadOfOriginalFilename() {
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "payload.html",
                "image/jpeg",
                new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 0x00}
        );

        String url = service.store(file, 1L);

        assertThat(url).startsWith(SERVER_BASE_URL + "/images/");
        assertThat(url).endsWith(".jpg");
        assertThat(Files.exists(tempDir.resolve(url.substring((SERVER_BASE_URL + "/images/").length())))).isTrue();
    }

    @Test
    void storeRejectsMismatchedContentTypeAndSignature() {
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "payload.png",
                "image/png",
                new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 0x00}
        );

        assertThatThrownBy(() -> service.store(file, 1L))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("지원하지 않는 파일 형식");
    }

    @Test
    void deleteIgnoresPathTraversalAttempts() throws Exception {
        Path outside = tempDir.getParent().resolve("outside.txt");
        Files.writeString(outside, "keep");

        try {
            assertThatCode(() -> service.delete(SERVER_BASE_URL + "/images/../outside.txt", 1L))
                    .doesNotThrowAnyException();
            assertThat(Files.readString(outside)).isEqualTo("keep");
        } finally {
            Files.deleteIfExists(outside);
        }
    }

    @Test
    void anotherUserCannotAttachOrDeleteUploadedImage() {
        MockMultipartFile file = new MockMultipartFile(
                "file", "photo.jpg", "image/jpeg", new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 0x00});
        String url = service.store(file, 1L);
        Path stored = tempDir.resolve(url.substring((SERVER_BASE_URL + "/images/").length()));

        assertThatCode(() -> service.validateOwner(url, 1L)).doesNotThrowAnyException();
        assertThatThrownBy(() -> service.validateOwner(url, 2L))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("본인이 업로드한");
        service.delete(url, 2L);
        assertThat(Files.exists(stored)).isTrue();

        service.delete(url, 1L);
        assertThat(Files.exists(stored)).isFalse();
    }

    @Test
    void legacyImageWithoutOwnerIsNotDeleted() throws Exception {
        String filename = "8e2d9ab0-e314-4976-97ba-0a72bd760998.jpg";
        Path stored = tempDir.resolve(filename);
        Files.write(stored, new byte[]{1, 2, 3});

        service.delete(SERVER_BASE_URL + "/images/" + filename, 1L);

        assertThat(Files.exists(stored)).isTrue();
    }
}
