package com.ync.ysync.controller;

import com.ync.ysync.domain.TargetType;
import com.ync.ysync.service.ScrapService;
import com.ync.ysync.config.AuthUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/scraps")
@RequiredArgsConstructor
public class ScrapController {

    private final ScrapService scrapService;
    private final AuthUtil authUtil; // 💡 추가

    // 💡 스크랩 토글 (추가/삭제) API
    @PostMapping
    public ResponseEntity<?> toggleScrap(
            @RequestParam TargetType targetType,
            @RequestParam Long targetId) { // 💡 AuthUtil 파라미터 제거
        
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");
        }

        try {
            scrapService.toggleScrap(memberId, targetType, targetId);
            return ResponseEntity.ok("스크랩 토글 성공");
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        } catch (DataIntegrityViolationException e) {
            // 💡 동시에 들어온 같은 요청이 먼저 INSERT에 성공한 경우입니다.
            //    uq_scrap 이 이쪽 INSERT를 막았을 뿐 "스크랩됨"이라는 결과는 이미 달성됐으므로 성공으로 응답합니다.
            //    트랜잭션 경계 밖(컨트롤러)에서 잡아야 롤백된 트랜잭션을 되살리려다 UnexpectedRollbackException이 나지 않습니다.
            return ResponseEntity.ok("스크랩 토글 성공");
        }
    }

    // 💡 내 스크랩 목록 조회 API
    @GetMapping
    public ResponseEntity<?> getMyScraps() { // 💡 AuthUtil 파라미터 제거
        Long memberId = authUtil.getLoginMemberId();
        if (memberId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("로그인이 필요합니다.");
        }

        List<ScrapService.ScrapResponseDto> scraps = scrapService.getMyScraps(memberId);
        return ResponseEntity.ok(scraps);
    }
}
