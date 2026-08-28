package com.ync.ysync.controller;

import com.ync.ysync.service.S3FileServiceImpl;
import java.net.URI;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
@ConditionalOnProperty(name = "ysync.storage.provider", havingValue = "s3")
public class S3FileController {

    private final S3FileServiceImpl fileService;

    public S3FileController(S3FileServiceImpl fileService) {
        this.fileService = fileService;
    }

    @GetMapping("/s3-uploads/{filename:.+}")
    public ResponseEntity<Void> download(@PathVariable String filename) {
        URI downloadUri = fileService.createPresignedDownloadUri(filename);
        return ResponseEntity.status(HttpStatus.FOUND).location(downloadUri).build();
    }
}
