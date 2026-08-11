# Image Storage

The current production-ready default is local disk storage. Keep the application contract stable by treating image storage as an implementation detail behind `ImageStorageService`.

## Current Local Storage

- Uploaded files are stored under `image.upload.dir`.
- Public image URLs are built from `image.public-base-url` and `image.public-path`.
- `/images/**` is served as a static resource from the local upload directory.
- The database stores the public URL in profile image fields.
- Upload validation allows JPEG, PNG, and WebP up to `image.max-size-bytes`.

## Configuration

```properties
image.upload.dir=${IMAGE_UPLOAD_DIR:/var/doggy/images}
image.public-base-url=${IMAGE_PUBLIC_BASE_URL:${SERVER_BASE_URL:http://localhost:8080}}
image.public-path=${IMAGE_PUBLIC_PATH:/images}
image.max-size-bytes=${IMAGE_MAX_SIZE_BYTES:5242880}
```

Use `IMAGE_PUBLIC_BASE_URL` when images are served from a different host, CDN, or object storage domain.

## Future Naver Object Storage Migration

When moving to Naver Object Storage, add a new `ImageStorageService` implementation instead of changing domain services.

Recommended next shape:

- Add an `image.storage.type` setting with `local` as the default.
- Keep `LocalImageStorageService` for development and fallback.
- Add an object storage implementation that stores files by generated object key.
- Return a public CDN/object URL from `store`.
- Delete objects by parsing only trusted storage URLs or by storing a separate object key.
- Prefer bucket lifecycle rules for orphan cleanup.

## Operational Notes

- Local disk storage must be backed up together with PostgreSQL.
- If API servers are scaled horizontally, local disk storage should be replaced first.
- Public profile images are intentionally readable without authentication. Do not reuse this path for sensitive images.
