package com.ync.ysync.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import java.io.File;
import java.io.IOException;
import java.util.UUID;

// 💡 프로젝트 외부 경로에 파일을 저장하는 로컬 구현체입니다.
@Service
@ConditionalOnProperty(name = "ysync.storage.provider", havingValue = "local", matchIfMissing = true)
public class LocalFileServiceImpl implements FileService {

    // 💡 프로퍼티에서 저장할 디렉토리 경로를 주입받습니다.
    @Value("${ysync.upload.dir}")
    private String uploadDir;

    @Override
    public String uploadFile(MultipartFile file) throws IOException {
        if (file == null || file.isEmpty()) {
            return null;
        }

        // 저장할 디렉토리가 없으면 생성합니다.
        File directory = new File(uploadDir);
        if (!directory.exists()) {
            directory.mkdirs();
        }

        // 💡 파일명 중복을 피하기 위해 UUID를 사용해 고유한 파일명을 생성합니다.
        String originalFilename = file.getOriginalFilename();
        String extension = "";
        if (originalFilename != null && originalFilename.contains(".")) {
            extension = originalFilename.substring(originalFilename.lastIndexOf("."));
        }
        
        String savedFilename = UUID.randomUUID().toString() + extension;
        
        // 실제 로컬 디렉토리에 파일 저장
        File destFile = new File(uploadDir + savedFilename);
        file.transferTo(destFile);

        // 정적 리소스로 접근할 수 있는 URL 경로 반환 (WebConfig에서 /uploads/**로 매핑 예정)
        return "/uploads/" + savedFilename;
    }
}
