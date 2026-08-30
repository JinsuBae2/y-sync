package com.ync.ysync.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.ArgumentCaptor;

import java.net.URI;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectResponse;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedGetObjectRequest;

class S3FileServiceImplTest {

    private final S3Client s3Client = mock(S3Client.class);
    private final S3Presigner presigner = mock(S3Presigner.class);
    private final S3FileServiceImpl fileService = new S3FileServiceImpl(
            s3Client,
            presigner,
            "y-sync-attachments-155641294529",
            Duration.ofMinutes(5)
    );

    @Test
    void uploadsWithOpaqueFilenameAndKeepsExistingPublicPathContract() throws Exception {
        when(s3Client.putObject(any(PutObjectRequest.class), any(RequestBody.class)))
                .thenReturn(PutObjectResponse.builder().build());
        MockMultipartFile file = new MockMultipartFile(
                "images",
                "notice.PNG",
                "image/png",
                new byte[]{1, 2, 3}
        );

        String storedPath = fileService.uploadFile(file);

        assertThat(storedPath).matches("/s3-uploads/[0-9a-f-]{36}\\.png");
        verify(s3Client).putObject(any(PutObjectRequest.class), any(RequestBody.class));
    }

    @Test
    void createsShortLivedPresignedDownloadUri() throws Exception {
        PresignedGetObjectRequest presigned = mock(PresignedGetObjectRequest.class);
        when(presigned.url()).thenReturn(
                URI.create("https://example-bucket.s3.ap-northeast-2.amazonaws.com/object?signature=test")
                        .toURL()
        );
        when(presigner.presignGetObject(any(GetObjectPresignRequest.class))).thenReturn(presigned);

        URI uri = fileService.createPresignedDownloadUri(
                "550e8400-e29b-41d4-a716-446655440000.pdf"
        );

        assertThat(uri.getHost()).isEqualTo("example-bucket.s3.ap-northeast-2.amazonaws.com");
    }

    @Test
    void rejectsTraversalInDownloadFilename() {
        assertThatThrownBy(() -> fileService.createPresignedDownloadUri("../secret.txt"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void addsOriginalFilenameWhenDownloadingAttachment() throws Exception {
        PresignedGetObjectRequest presigned = mock(PresignedGetObjectRequest.class);
        when(presigned.url()).thenReturn(
                URI.create("https://example-bucket.s3.ap-northeast-2.amazonaws.com/object?signature=test").toURL()
        );
        when(presigner.presignGetObject(any(GetObjectPresignRequest.class))).thenReturn(presigned);

        fileService.createPresignedDownloadUri(
                "550e8400-e29b-41d4-a716-446655440000.pdf",
                "학사 안내.pdf"
        );

        ArgumentCaptor<GetObjectPresignRequest> captor = ArgumentCaptor.forClass(GetObjectPresignRequest.class);
        verify(presigner).presignGetObject(captor.capture());
        assertThat(captor.getValue().getObjectRequest().responseContentDisposition())
                .contains("attachment", "%ED%95%99%EC%82%AC%20%EC%95%88%EB%82%B4.pdf");
    }
}
