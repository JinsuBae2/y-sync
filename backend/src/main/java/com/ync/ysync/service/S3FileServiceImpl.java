package com.ync.ysync.service;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Locale;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;

@Service
@ConditionalOnProperty(name = "ysync.storage.provider", havingValue = "s3")
public class S3FileServiceImpl implements FileService {

    private static final String OBJECT_PREFIX = "uploads/";

    private final S3Client s3Client;
    private final S3Presigner s3Presigner;
    private final String bucket;
    private final Duration presignDuration;

    public S3FileServiceImpl(
            S3Client s3Client,
            S3Presigner s3Presigner,
            @Value("${ysync.storage.s3.bucket}") String bucket,
            @Value("${ysync.storage.s3.presign-duration}") Duration presignDuration
    ) {
        this.s3Client = s3Client;
        this.s3Presigner = s3Presigner;
        this.bucket = bucket;
        this.presignDuration = presignDuration;
    }

    @Override
    public String uploadFile(MultipartFile file) throws IOException {
        if (file == null || file.isEmpty()) {
            return null;
        }

        String savedFilename = UUID.randomUUID() + extensionOf(file.getOriginalFilename());
        String objectKey = OBJECT_PREFIX + savedFilename;
        PutObjectRequest.Builder request = PutObjectRequest.builder()
                .bucket(bucket)
                .key(objectKey)
                .contentLength(file.getSize());

        if (file.getContentType() != null && !file.getContentType().isBlank()) {
            request.contentType(file.getContentType());
        }

        try {
            s3Client.putObject(request.build(), RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
        } catch (SdkException exception) {
            throw new IOException("S3 파일 업로드에 실패했습니다.", exception);
        }
        return "/s3-uploads/" + savedFilename;
    }

    public URI createPresignedDownloadUri(String filename) {
        return createPresignedDownloadUri(filename, null);
    }

    public URI createPresignedDownloadUri(String filename, String downloadName) {
        String safeFilename = requireSafeFilename(filename);
        GetObjectRequest.Builder getObjectRequest = GetObjectRequest.builder()
                .bucket(bucket)
                .key(OBJECT_PREFIX + safeFilename);
        if (downloadName != null && !downloadName.isBlank()) {
            String encodedName = URLEncoder.encode(safeDownloadName(downloadName), StandardCharsets.UTF_8)
                    .replace("+", "%20");
            getObjectRequest.responseContentDisposition("attachment; filename*=UTF-8''" + encodedName);
        }
        GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
                .signatureDuration(presignDuration)
                .getObjectRequest(getObjectRequest.build())
                .build();
        return URI.create(s3Presigner.presignGetObject(presignRequest).url().toString());
    }

    private static String extensionOf(String originalFilename) {
        if (originalFilename == null) return "";
        int dot = originalFilename.lastIndexOf('.');
        if (dot < 0 || dot == originalFilename.length() - 1) return "";
        String extension = originalFilename.substring(dot).toLowerCase(Locale.ROOT);
        return extension.matches("\\.[a-z0-9]{1,10}") ? extension : "";
    }

    private static String requireSafeFilename(String filename) {
        if (filename == null || !filename.matches("[0-9a-fA-F-]{36}(\\.[a-zA-Z0-9]{1,10})?")) {
            throw new IllegalArgumentException("올바르지 않은 파일 경로입니다.");
        }
        return filename;
    }

    private static String safeDownloadName(String downloadName) {
        String name = downloadName.replace('\\', '/');
        name = name.substring(name.lastIndexOf('/') + 1).replace("\r", "").replace("\n", "").trim();
        if (name.isEmpty()) return "attachment";
        return name.length() > 180 ? name.substring(name.length() - 180) : name;
    }
}
