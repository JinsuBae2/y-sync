package com.ync.ysync.service;

import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.springframework.web.multipart.MultipartFile;

final class AttachmentValidator {

    static final int MAX_FILE_COUNT = 10;
    static final long MAX_FILE_SIZE = 20L * 1024 * 1024;
    static final long MAX_TOTAL_SIZE = 50L * 1024 * 1024;
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of(
            "png", "jpg", "jpeg", "gif", "webp", "pdf", "hwp", "hwpx",
            "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "zip"
    );

    private AttachmentValidator() {
    }

    static void validate(List<MultipartFile> files) {
        if (files == null || files.isEmpty()) return;
        if (files.size() > MAX_FILE_COUNT) {
            throw new IllegalArgumentException("첨부파일은 최대 10개까지 등록할 수 있습니다.");
        }
        long totalSize = 0L;
        for (MultipartFile file : files) {
            if (file == null || file.isEmpty()) continue;
            totalSize += file.getSize();
            if (file.getSize() > MAX_FILE_SIZE) {
                throw new IllegalArgumentException("첨부파일 하나의 크기는 20MB를 넘을 수 없습니다.");
            }
            String extension = extensionOf(file.getOriginalFilename());
            if (!ALLOWED_EXTENSIONS.contains(extension)) {
                throw new IllegalArgumentException("지원하지 않는 첨부파일 형식입니다: " + extension);
            }
        }
        if (totalSize > MAX_TOTAL_SIZE) {
            throw new IllegalArgumentException("첨부파일 전체 크기는 50MB를 넘을 수 없습니다.");
        }
    }

    private static String extensionOf(String filename) {
        if (filename == null) return "";
        int dot = filename.lastIndexOf('.');
        return dot >= 0 && dot < filename.length() - 1
                ? filename.substring(dot + 1).toLowerCase(Locale.ROOT)
                : "";
    }
}
