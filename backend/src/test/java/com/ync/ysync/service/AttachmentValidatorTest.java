package com.ync.ysync.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.assertThatCode;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

class AttachmentValidatorTest {

    @Test
    void allowsDepartmentDocumentFormats() {
        List<MockMultipartFile> files = List.of(
                file("guide.pdf", 10), file("form.hwp", 10), file("form.hwpx", 10),
                file("table.xlsx", 10), file("photo.png", 10)
        );

        assertThatCode(() -> AttachmentValidator.validate(List.copyOf(files))).doesNotThrowAnyException();
    }

    @Test
    void rejectsExecutableFiles() {
        assertThatThrownBy(() -> AttachmentValidator.validate(List.of(file("malware.exe", 10))))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("지원하지 않는");
    }

    @Test
    void rejectsFilesLargerThanTwentyMegabytes() {
        assertThatThrownBy(() -> AttachmentValidator.validate(List.of(
                file("large.pdf", (int) AttachmentValidator.MAX_FILE_SIZE + 1))))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("20MB");
    }

    private MockMultipartFile file(String name, int size) {
        return new MockMultipartFile("files", name, "application/octet-stream", new byte[size]);
    }
}
