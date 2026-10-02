package com.ync.ysync.controller;

import com.ync.ysync.config.AuthUtil;
import com.ync.ysync.domain.Feedback;
import com.ync.ysync.service.FeedbackService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class FeedbackController {
    private final FeedbackService service;
    private final AuthUtil authUtil;

    @PostMapping(value = "/feedback", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<Void> submit(@RequestParam Feedback.Category category, @RequestParam String title,
            @RequestParam String content, @RequestParam(defaultValue = "") String screen,
            @RequestParam(defaultValue = "") String clientInfo,
            @RequestPart(required = false) List<MultipartFile> images) throws IOException {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        service.submit(memberId, category, title, content, screen, clientInfo, images);
        return ResponseEntity.status(HttpStatus.CREATED).build();
    }

    @GetMapping("/admin/feedback")
    @PreAuthorize("hasRole('ADMIN')")
    public Page<FeedbackService.FeedbackResponse> list(@RequestParam(required = false) Boolean reviewed,
                                                      @RequestParam(defaultValue = "0") int page) {
        return service.list(reviewed, page);
    }

    @PutMapping("/admin/feedback/{id}/reviewed")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> review(@PathVariable Long id) {
        service.review(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/admin/feedback/images/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<byte[]> image(@PathVariable Long id) {
        var image = service.image(id);
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .header("X-Content-Type-Options", "nosniff")
                .contentType(MediaType.parseMediaType(image.getContentType())).body(image.getData());
    }
}
