package com.doggy.backend.global.image;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.nio.file.Path;
import java.nio.file.Paths;

@ConfigurationProperties(prefix = "image")
public class ImageStorageProperties {

    private Upload upload = new Upload();
    private String publicBaseUrl = "http://localhost:8080";
    private String publicPath = "/images";
    private long maxSizeBytes = 5 * 1024 * 1024L;

    public Upload getUpload() {
        return upload;
    }

    public void setUpload(Upload upload) {
        this.upload = upload != null ? upload : new Upload();
    }

    public String getPublicBaseUrl() {
        return publicBaseUrl;
    }

    public void setPublicBaseUrl(String publicBaseUrl) {
        if (publicBaseUrl != null && !publicBaseUrl.isBlank()) {
            this.publicBaseUrl = trimTrailingSlash(publicBaseUrl.trim());
        }
    }

    public String getPublicPath() {
        return publicPath;
    }

    public void setPublicPath(String publicPath) {
        if (publicPath != null && !publicPath.isBlank()) {
            String clean = publicPath.trim();
            this.publicPath = clean.startsWith("/") ? trimTrailingSlash(clean) : "/" + trimTrailingSlash(clean);
        }
    }

    public long getMaxSizeBytes() {
        return maxSizeBytes;
    }

    public void setMaxSizeBytes(long maxSizeBytes) {
        if (maxSizeBytes > 0) {
            this.maxSizeBytes = maxSizeBytes;
        }
    }

    public Path uploadPath() {
        return Paths.get(upload.dir).toAbsolutePath().normalize();
    }

    public String publicUrl(String filename) {
        return publicBaseUrl + publicPath + "/" + filename;
    }

    public String stripPublicPrefix(String imageUrl) {
        if (imageUrl == null || imageUrl.isBlank()) {
            return null;
        }
        String absolutePrefix = publicBaseUrl + publicPath + "/";
        if (imageUrl.startsWith(absolutePrefix)) {
            return imageUrl.substring(absolutePrefix.length());
        }
        String relativePrefix = publicPath + "/";
        if (imageUrl.startsWith(relativePrefix)) {
            return imageUrl.substring(relativePrefix.length());
        }
        return null;
    }

    private String trimTrailingSlash(String value) {
        String clean = value;
        while (clean.endsWith("/") && clean.length() > 1) {
            clean = clean.substring(0, clean.length() - 1);
        }
        return clean;
    }

    public static class Upload {
        private String dir = "/var/doggy/images";

        public String getDir() {
            return dir;
        }

        public void setDir(String dir) {
            if (dir != null && !dir.isBlank()) {
                this.dir = dir;
            }
        }
    }
}
