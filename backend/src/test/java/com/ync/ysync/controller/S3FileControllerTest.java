package com.ync.ysync.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.ync.ysync.service.S3FileServiceImpl;
import java.net.URI;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

class S3FileControllerTest {

    @Test
    void redirectsStableApplicationPathToPresignedS3Url() {
        S3FileServiceImpl fileService = mock(S3FileServiceImpl.class);
        S3FileController controller = new S3FileController(fileService);
        String filename = "550e8400-e29b-41d4-a716-446655440000.pdf";
        URI presignedUri = URI.create(
                "https://example-bucket.s3.ap-northeast-2.amazonaws.com/object?signature=test"
        );
        when(fileService.createPresignedDownloadUri(filename)).thenReturn(presignedUri);

        ResponseEntity<Void> response = controller.download(filename);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FOUND);
        assertThat(response.getHeaders().getLocation()).isEqualTo(presignedUri);
    }
}
