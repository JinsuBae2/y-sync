package com.ync.ysync.controller;

import com.ync.ysync.domain.Report;
import com.ync.ysync.service.ReportService;
import com.ync.ysync.config.AuthUtil;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/reports")
@RequiredArgsConstructor
public class ReportController {

    private final ReportService reportService;
    private final AuthUtil authUtil;

    @PostMapping
    public ResponseEntity<?> createReport(@RequestBody ReportRequest request) {
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");
        }

        if (request.getTargetType() == null || request.getTargetId() == null || request.getReason() == null || request.getReason().trim().isEmpty()) {
            return ResponseEntity.badRequest().body("신고 대상 및 사유를 올바르게 입력해주세요.");
        }

        Report.TargetType targetType;
        try {
            targetType = Report.TargetType.valueOf(request.getTargetType().toUpperCase());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body("잘못된 신고 타겟 타입입니다. (POST 또는 COMMENT 가능)");
        }

        try {
            reportService.createReport(memberId, targetType, request.getTargetId(), request.getReason().trim());
            return ResponseEntity.ok("신고가 정상 접수되었습니다.");
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ReportRequest {
        private String targetType;
        private Long targetId;
        private String reason;
    }
}
