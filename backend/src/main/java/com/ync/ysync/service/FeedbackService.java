package com.ync.ysync.service;

import com.ync.ysync.domain.Feedback;
import com.ync.ysync.domain.FeedbackImage;
import com.ync.ysync.repository.FeedbackRepository;
import com.ync.ysync.repository.FeedbackImageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class FeedbackService {
    private final FeedbackRepository repository;
    private final FeedbackImageRepository images;

    @Transactional
    public void submit(Long memberId, Feedback.Category category, String title, String content,
                       String screen, String clientInfo, List<MultipartFile> files) throws IOException {
        if (memberId == null || category == null) throw new IllegalArgumentException("로그인 및 유형을 확인해주세요.");
        title = validated(title, 100, true);
        content = validated(content, 3000, true);
        screen = validated(screen, 100, false);
        clientInfo = validated(clientInfo, 300, false);
        if (files == null) files = List.of();
        if (files.size() > 3) throw new IllegalArgumentException("이미지는 최대 3개까지 첨부할 수 있습니다.");
        List<byte[]> bytes = new ArrayList<>();
        List<String> types = new ArrayList<>();
        for (MultipartFile file : files) {
            if (file.isEmpty() || file.getSize() > 2 * 1024 * 1024)
                throw new IllegalArgumentException("이미지는 한 장당 2MB 이하로 첨부해주세요.");
            byte[] data = file.getBytes();
            types.add(imageType(data));
            bytes.add(data);
        }
        Feedback feedback = repository.save(new Feedback(memberId, category, title, content, screen, clientInfo));
        for (int i = 0; i < bytes.size(); i++)
            images.save(new FeedbackImage(feedback.getId(), types.get(i), bytes.get(i)));
    }

    public Page<FeedbackResponse> list(Boolean reviewed, int page) {
        if (page < 0) throw new IllegalArgumentException("페이지 번호를 확인해주세요.");
        var pageable = PageRequest.of(page, 20, Sort.by(Sort.Direction.DESC, "id"));
        var result = reviewed == null ? repository.findAll(pageable) : repository.findByReviewed(reviewed, pageable);
        return result.map(f -> new FeedbackResponse(f.getId(), f.getCategory(), f.getTitle(), f.getContent(),
                f.getScreen(), f.getClientInfo(), f.isReviewed(), f.getCreatedAt(), images.findIdsByFeedbackId(f.getId())));
    }

    @Transactional
    public void review(Long id) {
        repository.findById(id).orElseThrow(() -> new IllegalArgumentException("의견을 찾을 수 없습니다.")).markReviewed();
    }

    public FeedbackImage image(Long id) {
        return images.findById(id).orElseThrow(() -> new IllegalArgumentException("이미지를 찾을 수 없습니다."));
    }

    private static String validated(String value, int max, boolean required) {
        String text = value == null ? "" : value.trim();
        if ((required && text.isEmpty()) || text.length() > max)
            throw new IllegalArgumentException("필수 항목과 입력 길이를 확인해주세요.");
        return text;
    }

    // 💡 확장자나 요청 MIME을 신뢰하지 않고 허용한 이미지의 파일 시그니처를 확인합니다.
    private static String imageType(byte[] data) {
        if (data.length >= 8 && data[0] == (byte) 0x89 && data[1] == 0x50 && data[2] == 0x4e
                && data[3] == 0x47 && data[4] == 13 && data[5] == 10 && data[6] == 26 && data[7] == 10) return "image/png";
        if (data.length >= 3 && data[0] == (byte) 0xff && data[1] == (byte) 0xd8 && data[2] == (byte) 0xff) return "image/jpeg";
        throw new IllegalArgumentException("PNG 또는 JPG 이미지만 첨부할 수 있습니다.");
    }

    public record FeedbackResponse(Long id, Feedback.Category category, String title, String content,
                                   String screen, String clientInfo, boolean reviewed,
                                   LocalDateTime createdAt, List<Long> imageIds) {}
}
