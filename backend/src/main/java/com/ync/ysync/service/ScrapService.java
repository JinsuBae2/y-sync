package com.ync.ysync.service;

import com.ync.ysync.domain.*;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NoticeRepository;
import com.ync.ysync.repository.ScrapRepository;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ScrapService {

    private final ScrapRepository scrapRepository;
    private final MemberRepository memberRepository;
    private final NoticeRepository noticeRepository;
    private final CommunityPostRepository communityPostRepository;

    @Transactional
    public void toggleScrap(Long memberId, TargetType targetType, Long targetId) {
        // 💡 해제는 조건부 DELETE 한 문장으로 처리합니다. 지워진 행이 없으면 아직 스크랩하지 않은 상태입니다.
        //    조회해서 엔티티를 지우면, 같은 해제 요청이 동시에 들어왔을 때(버튼 연타 등)
        //    한쪽이 "expected row count 1 but was 0"으로 500을 받습니다.
        if (scrapRepository.deleteByMemberIdAndTargetTypeAndTargetId(memberId, targetType, targetId) > 0) {
            return;
        }

        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));

        // 게시글 존재 검증 (삭제된 글인지 체크 등)
        if (targetType == TargetType.NOTICE) {
            if(noticeRepository.findById(targetId).isEmpty()) {
                throw new IllegalArgumentException("공지사항을 찾을 수 없습니다.");
            }
        } else {
            CommunityPost post = communityPostRepository.findById(targetId)
                    .orElseThrow(() -> new IllegalArgumentException("커뮤니티 게시글을 찾을 수 없습니다."));
            if(post.isDeleted()) throw new IllegalArgumentException("삭제된 게시글은 스크랩할 수 없습니다.");
        }

        // 💡 추가 쪽 경쟁은 uq_scrap 이 막습니다. 중복키 예외는 컨트롤러가 "스크랩됨"으로 흡수합니다.
        scrapRepository.save(Scrap.builder()
                .member(member)
                .targetType(targetType)
                .targetId(targetId)
                .build());
    }

    public List<ScrapResponseDto> getMyScraps(Long memberId) {
        List<Scrap> scraps = scrapRepository.findAllByMemberIdOrderByCreatedAtDesc(memberId);

        if (scraps.isEmpty()) {
            return List.of();
        }

        // 대상 ID 추출
        List<Long> noticeIds = scraps.stream()
                .filter(s -> s.getTargetType() == TargetType.NOTICE)
                .map(Scrap::getTargetId)
                .collect(Collectors.toList());

        List<Long> communityIds = scraps.stream()
                .filter(s -> s.getTargetType() == TargetType.COMMUNITY)
                .map(Scrap::getTargetId)
                .collect(Collectors.toList());

        // 대상 일괄 조회 (IN Query)
        Map<Long, Notice> noticeMap = noticeRepository.findAllById(noticeIds).stream()
                .collect(Collectors.toMap(Notice::getId, n -> n));

        Map<Long, CommunityPost> communityMap = communityPostRepository.findAllById(communityIds).stream()
                .collect(Collectors.toMap(CommunityPost::getId, p -> p));

        // 응답 조립 (미삭제 게시물만 매핑)
        return scraps.stream()
                .map(scrap -> {
                    if (scrap.getTargetType() == TargetType.NOTICE) {
                        Notice notice = noticeMap.get(scrap.getTargetId());
                        if (notice == null) return null;
                        return ScrapResponseDto.fromNotice(scrap, notice);
                    } else {
                        CommunityPost post = communityMap.get(scrap.getTargetId());
                        if (post == null || post.isDeleted()) return null;
                        return ScrapResponseDto.fromCommunityPost(scrap, post);
                    }
                })
                .filter(dto -> dto != null)
                .collect(Collectors.toList());
    }

    @Data
    @Builder
    public static class ScrapResponseDto {
        private Long scrapId;
        private TargetType targetType;
        private Long targetId;
        private String category; // NOTICE일 때는 null 혹은 고정카테고리명
        private String title;
        private String authorName;
        private LocalDateTime postCreatedAt;
        private long commentCount;
        private LocalDateTime scrappedAt;

        public static ScrapResponseDto fromNotice(Scrap scrap, Notice notice) {
            return ScrapResponseDto.builder()
                    .scrapId(scrap.getId())
                    .targetType(scrap.getTargetType())
                    .targetId(scrap.getTargetId())
                    .category("공지사항")
                    .title(notice.getTitle())
                    .authorName(notice.getAuthor().getName())
                    .postCreatedAt(notice.getCreatedAt())
                    .commentCount(notice.getCommentCount())
                    .scrappedAt(scrap.getCreatedAt())
                    .build();
        }

        public static ScrapResponseDto fromCommunityPost(Scrap scrap, CommunityPost post) {
            return ScrapResponseDto.builder()
                    .scrapId(scrap.getId())
                    .targetType(scrap.getTargetType())
                    .targetId(scrap.getTargetId())
                    .category(post.getCategory()) // 예: QA, TEAM, FREE
                    .title(post.getTitle())
                    .authorName(post.isAnonymous() ? "익명의 학생" : post.getMember().getName())
                    .postCreatedAt(post.getCreatedAt())
                    .commentCount(post.getCommentCount())
                    .scrappedAt(scrap.getCreatedAt())
                    .build();
        }
    }
}
