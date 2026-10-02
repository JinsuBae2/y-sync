package com.ync.ysync.service;

import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.domain.NoticeType;
import com.ync.ysync.domain.NoticeImage; // 💡 추가
import com.ync.ysync.event.NoticeCreatedEvent;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NoticeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile; // 💡 추가

import java.io.IOException;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NoticeService {

    private final NoticeRepository noticeRepository;
    private final MemberRepository memberRepository;
    private final FileService fileService; // 💡 추가
    private final ApplicationEventPublisher eventPublisher;
    private final PostDeletionCleaner postDeletionCleaner;

    /** 공지 피드 기본 페이지 크기입니다. */
    public static final int FEED_DEFAULT_SIZE = 10;
    /** 한 번에 받아갈 수 있는 상한입니다. 클라이언트가 size를 키워 전체를 긁어가지 못하게 합니다. */
    public static final int FEED_MAX_SIZE = 30;
    /** 새 공지 개수 표시 상한입니다. 그 이상은 정확한 수가 의미 없고 COUNT 비용만 듭니다. */
    public static final int NEW_NOTICE_COUNT_CAP = 99;

    /**
     * 💡 공지 피드 한 페이지입니다.
     *
     * @param pinned     고정 공지. 첫 페이지(커서 없음)에서만 채워지고 이후 페이지에서는 비어 있습니다.
     * @param items      일반 공지, 최신순
     * @param nextCursor 다음 페이지 커서. 마지막 페이지면 null
     * @param latestId   같은 필터에서 가장 최근 공지의 id. 클라이언트가 새 공지 감지 기준으로 씁니다.
     */
    public record NoticeFeed(List<Notice> pinned, List<Notice> items,
                             String nextCursor, boolean hasNext, Long latestId) {
    }

    /**
     * 💡 커서 기반으로 공지 한 페이지를 돌려줍니다.
     *
     * 고정 공지는 커서 페이징에서 제외하고 첫 페이지에만 함께 내려줍니다. 정렬이
     * `isPinned DESC, createdAt DESC`라 고정 공지는 날짜와 무관하게 위로 뜨는데, 그 상태로
     * `(createdAt, id)` 커서 하나를 쓰면 고정/일반 경계에서 페이지가 어긋납니다. 분리하면
     * 커서가 단순해지고, 스크롤 도중 고정 공지가 목록 중간에 끼어들지도 않습니다.
     *
     * @param cursor  이전 응답의 `nextCursor`. 첫 페이지는 null
     * @param grade   `Grade.ALL`이면 필터하지 않습니다
     * @param keyword null·공백이면 필터하지 않습니다
     */
    public NoticeFeed getFeed(String cursor, Integer size, Grade grade, String keyword) {
        Grade effectiveGrade = grade != null ? grade : Grade.ALL;
        String effectiveKeyword = keyword == null ? "" : keyword.trim();
        int pageSize = normalizeFeedSize(size);

        // 💡 한 건 더 조회해 "다음이 있는지"를 판정합니다. 별도 COUNT 쿼리를 돌리지 않습니다.
        var probe = org.springframework.data.domain.PageRequest.of(0, pageSize + 1);
        List<Notice> found = (cursor == null || cursor.isBlank())
                ? noticeRepository.findFeedFirstPage(false, effectiveGrade, effectiveKeyword, probe)
                : findAfter(NoticeCursor.decode(cursor), effectiveGrade, effectiveKeyword, probe);

        boolean hasNext = found.size() > pageSize;
        List<Notice> items = hasNext ? found.subList(0, pageSize) : found;

        String nextCursor = null;
        if (hasNext) {
            Notice last = items.get(items.size() - 1);
            nextCursor = new NoticeCursor(last.getCreatedAt(), last.getId()).encode();
        }

        List<Notice> pinned = (cursor == null || cursor.isBlank())
                ? noticeRepository.findFeedFirstPage(true, effectiveGrade, effectiveKeyword,
                        org.springframework.data.domain.PageRequest.of(0, FEED_MAX_SIZE))
                : List.of();

        Long latestId = noticeRepository.findLatestId(effectiveGrade, effectiveKeyword);
        return new NoticeFeed(pinned, items, nextCursor, hasNext, latestId);
    }

    /**
     * 💡 클라이언트가 들고 있는 `latestId` 이후로 올라온 공지 수입니다.
     *
     * 고정 여부는 따지지 않습니다. 스크롤 도중 새로 올라온 고정 공지도 사용자에게는 새 공지입니다.
     */
    public long countNewNotices(Long sinceId, Grade grade, String keyword) {
        if (sinceId == null) {
            return 0;
        }
        long count = noticeRepository.countNewerThan(
                sinceId, grade != null ? grade : Grade.ALL, keyword == null ? "" : keyword.trim());
        return Math.min(count, NEW_NOTICE_COUNT_CAP);
    }

    private List<Notice> findAfter(NoticeCursor cursor, Grade grade, String keyword,
                                   org.springframework.data.domain.Pageable pageable) {
        return noticeRepository.findFeedAfterCursor(
                false, grade, keyword, cursor.createdAt(), cursor.id(), pageable);
    }

    private int normalizeFeedSize(Integer size) {
        if (size == null || size <= 0) {
            return FEED_DEFAULT_SIZE;
        }
        return Math.min(size, FEED_MAX_SIZE);
    }

    // 전체 공지사항을 최신순으로 가져옵니다.
    public List<Notice> getAllNotices() {
        return noticeRepository.findAllByOrderByIsPinnedDescCreatedAtDesc();
    }

    // 💡 전체 공지사항을 페이징하여 가져옵니다.
    public org.springframework.data.domain.Page<Notice> getAllNotices(org.springframework.data.domain.Pageable pageable) {
        return noticeRepository.findAllByOrderByIsPinnedDescCreatedAtDesc(pageable);
    }

    // 💡 키워드를 이용해 공지사항의 제목이나 내용을 검색합니다.
    // 키워드가 없거나(null) 공백일 경우 전체 목록을 반환하여 유연한 대응이 가능하게 합니다.
    public List<Notice> searchNotices(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return getAllNotices();
        }
        return noticeRepository.findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByIsPinnedDescCreatedAtDesc(keyword, keyword);
    }

    // 💡 키워드를 이용해 공지사항의 제목이나 내용을 페이징 검색합니다.
    public org.springframework.data.domain.Page<Notice> searchNotices(String keyword, org.springframework.data.domain.Pageable pageable) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return getAllNotices(pageable);
        }
        return noticeRepository.findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByIsPinnedDescCreatedAtDesc(keyword, keyword, pageable);
    }


    @Transactional
    public Notice getNotice(Long id) {
        // 💡 존재 확인과 조회수 증가를 UPDATE 한 문장으로 함께 처리합니다. 갱신된 행이 없으면 없는 글입니다.
        if (noticeRepository.incrementViewCount(id) == 0) {
            throw new IllegalArgumentException("해당 공지사항이 존재하지 않습니다.");
        }
        return noticeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("해당 공지사항이 존재하지 않습니다."));
    }

    @Transactional
    public Notice createNotice(String title, String content, NoticeType noticeType, Grade targetGrade, boolean isPinned, java.time.LocalDate eventStartDate, java.time.LocalDate eventEndDate, Long memberId, List<MultipartFile> images) {
        AttachmentValidator.validate(images);
        Member author = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));

        Notice notice = Notice.builder()
                .title(title)
                .content(content)
                .author(author)
                .noticeType(noticeType)
                .targetGrade(targetGrade)
                .isPinned(isPinned)
                .eventStartDate(eventStartDate)
                .eventEndDate(eventEndDate)
                .build();

        if (images != null && !images.isEmpty()) {
            for (MultipartFile file : images) {
                try {
                    String fileUrl = fileService.uploadFile(file);
                    if (fileUrl != null) {
                        NoticeImage noticeImage = NoticeImage.builder()
                                .imageUrl(fileUrl)
                                .originalFilename(file.getOriginalFilename())
                                .contentType(file.getContentType())
                                .fileSize(file.getSize())
                                .notice(notice)
                                .build();
                        notice.getImages().add(noticeImage);
                    }
                } catch (IOException e) {
                    throw new RuntimeException("파일 업로드 중 오류가 발생했습니다.", e);
                }
            }
        }
        Notice savedNotice = noticeRepository.save(notice);

        // 💡 비동기 이벤트를 발행하여 FCM 알림 발송 (Loose Coupling)
        eventPublisher.publishEvent(new NoticeCreatedEvent(this, savedNotice, author.getId()));

        return savedNotice;
    }

    @Transactional
    public Notice updateNotice(Long id, String title, String content, NoticeType noticeType, Grade targetGrade, boolean isPinned, java.time.LocalDate eventStartDate, java.time.LocalDate eventEndDate, Long memberId, MemberRole role, List<MultipartFile> images) {
        AttachmentValidator.validate(images);
        Notice notice = findNotice(id);
        validateAuthorOrAdmin(notice, memberId, role);
        
        notice.update(title, content, noticeType, targetGrade, isPinned, eventStartDate, eventEndDate);
        
        // 새 파일이 전달된 경우 기존 첨부를 초기화 후 추가합니다.
        if (images != null && !images.isEmpty()) {
            notice.getImages().clear();
            for (MultipartFile file : images) {
                try {
                    String fileUrl = fileService.uploadFile(file);
                    if (fileUrl != null) {
                        NoticeImage noticeImage = NoticeImage.builder()
                                .imageUrl(fileUrl)
                                .originalFilename(file.getOriginalFilename())
                                .contentType(file.getContentType())
                                .fileSize(file.getSize())
                                .notice(notice)
                                .build();
                        notice.getImages().add(noticeImage);
                    }
                } catch (IOException e) {
                    throw new RuntimeException("파일 업로드 중 오류가 발생했습니다.", e);
                }
            }
        }
        
        return notice;
    }

    @Transactional
    public void deleteNotice(Long id, Long memberId, MemberRole role) {
        Notice notice = findNotice(id);
        validateAuthorOrAdmin(notice, memberId, role);

        // 💡 공지 댓글에도 FK가 걸려 있어, 댓글이 하나라도 달린 공지는 먼저 정리하지 않으면 삭제에 실패합니다.
        postDeletionCleaner.cleanUpNotice(notice.getId());

        noticeRepository.delete(notice);
    }

    // 💡 수정·삭제 같은 내부 작업에서는 조회수를 증가시키지 않습니다.
    private Notice findNotice(Long id) {
        return noticeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("해당 공지사항이 존재하지 않습니다."));
    }

    private void validateAuthorOrAdmin(Notice notice, Long memberId, MemberRole role) {
        if (role != MemberRole.ADMIN && role != MemberRole.SUPER_ADMIN && !notice.getAuthor().getId().equals(memberId)) {
            throw new IllegalArgumentException("해당 공지사항에 대한 권한이 없습니다.");
        }
    }
}
