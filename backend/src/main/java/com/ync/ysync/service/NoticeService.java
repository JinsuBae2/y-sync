package com.ync.ysync.service;

import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.domain.NoticeType;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NoticeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NoticeService {

    private final NoticeRepository noticeRepository;
    private final MemberRepository memberRepository;

    // 전체 공지사항을 최신순으로 가져옵니다.
    public List<Notice> getAllNotices() {
        return noticeRepository.findAllByOrderByIsPinnedDescCreatedAtDesc();
    }

    // 💡 키워드를 이용해 공지사항의 제목이나 내용을 검색합니다.
    // 키워드가 없거나(null) 공백일 경우 전체 목록을 반환하여 유연한 대응이 가능하게 합니다.
    public List<Notice> searchNotices(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return getAllNotices();
        }
        return noticeRepository.findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByIsPinnedDescCreatedAtDesc(keyword, keyword);
    }


    @Transactional
    public Notice getNotice(Long id) {
        Notice notice = noticeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("해당 공지사항이 존재하지 않습니다."));
        notice.incrementViewCount();
        return notice;
    }

    @Transactional
    public Notice createNotice(String title, String content, NoticeType noticeType, Grade targetGrade, boolean isPinned, Long memberId) {
        Member author = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));

        Notice notice = Notice.builder()
                .title(title)
                .content(content)
                .author(author)
                .noticeType(noticeType)
                .targetGrade(targetGrade)
                .isPinned(isPinned)
                .build();

        return noticeRepository.save(notice);
    }

    @Transactional
    public Notice updateNotice(Long id, String title, String content, NoticeType noticeType, Grade targetGrade, boolean isPinned, Long memberId, MemberRole role) {
        Notice notice = getNotice(id);
        validateAuthorOrAdmin(notice, memberId, role);
        
        notice.update(title, content, noticeType, targetGrade, isPinned);
        return notice;
    }

    @Transactional
    public void deleteNotice(Long id, Long memberId, MemberRole role) {
        Notice notice = getNotice(id);
        validateAuthorOrAdmin(notice, memberId, role);
        
        noticeRepository.delete(notice);
    }

    private void validateAuthorOrAdmin(Notice notice, Long memberId, MemberRole role) {
        if (role != MemberRole.ADMIN && !notice.getAuthor().getId().equals(memberId)) {
            throw new IllegalArgumentException("해당 공지사항에 대한 권한이 없습니다.");
        }
    }
}
