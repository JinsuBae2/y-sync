package com.ync.ysync.service;

import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;

// 💡 추후 AWS S3 등으로 교체하기 쉽도록 만든 파일 업로드 서비스 인터페이스입니다.
public interface FileService {
    
    /**
     * 파일을 업로드하고, 저장된 파일의 접근 URL을 반환합니다.
     * @param file 업로드할 MultipartFile 객체
     * @return 업로드된 파일의 URL 경로 (예: /uploads/abcde.jpg)
     */
    String uploadFile(MultipartFile file) throws IOException;
}
