package com.ync.ysync.service;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Comment;
import com.ync.ysync.domain.CommunityPost;
import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.Notice;
import com.ync.ysync.domain.NoticeType;
import com.ync.ysync.domain.Report;
import com.ync.ysync.domain.Scrap;
import com.ync.ysync.domain.TargetType;
import com.ync.ysync.repository.CommentRepository;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NoticeRepository;
import com.ync.ysync.repository.ReportRepository;
import com.ync.ysync.repository.ScrapRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 💡 댓글이 달린 글을 하드 삭제할 수 있는지 고정하는 테스트입니다.
 *
 * `comment.community_post_id`와 `comment.notice_id`에는 FK 제약이 걸려 있습니다(운영 DB에서 확인).
 * 이전 구현은 딸린 댓글을 지우지 않고 글만 지우려 했기 때문에, **댓글이 하나라도 달린 글은
 * 작성자든 관리자든 삭제할 수 없었습니다.** 제약 위반이 500으로 나갔습니다.
 *
 * 실제 DELETE가 DB까지 도달해야 FK 위반 여부를 확인할 수 있으므로 클래스에 @Transactional을 걸지 않습니다.
 */
@SpringBootTest
class PostHardDeleteTest {

    @Autowired private CommunityService communityService;
    @Autowired private NoticeService noticeService;
    @Autowired private CommunityPostRepository communityPostRepository;
    @Autowired private NoticeRepository noticeRepository;
    @Autowired private CommentRepository commentRepository;
    @Autowired private ScrapRepository scrapRepository;
    @Autowired private ReportRepository reportRepository;
    @Autowired private MemberRepository memberRepository;

    @MockitoBean private JavaMailSender javaMailSender;

    private Member createMember(String prefix, MemberRole role) {
        return memberRepository.save(Member.builder()
                .loginId(prefix + "-" + System.nanoTime()).password("encoded").name("사용자")
                .role(role).provider(AuthProvider.LOCAL).authType(AuthType.PASSWORD)
                .isActivated(true).isSuspended(false)
                .build());
    }

    private CommunityPost createPost(Member author) {
        return communityPostRepository.save(CommunityPost.builder()
                .category("FREE").title("삭제 테스트").content("내용")
                .anonymous(false).member(author).targetGrade(Grade.ALL).isPinned(false)
                .build());
    }

    private Comment addPostComment(CommunityPost post, Member writer, Comment parent) {
        return commentRepository.save(Comment.builder()
                .content("댓글").communityPost(post).member(writer).parent(parent).build());
    }

    @Test
    void 댓글이_달린_커뮤니티_글을_삭제할_수_있다() {
        Member author = createMember("post-del", MemberRole.USER);
        CommunityPost post = createPost(author);
        Comment root = addPostComment(post, author, null);
        Comment reply = addPostComment(post, author, root);

        assertThatCode(() -> communityService.deletePost(post.getId(), author.getId(), MemberRole.USER))
                .doesNotThrowAnyException();

        assertThat(communityPostRepository.findById(post.getId())).isEmpty();
        assertThat(commentRepository.findById(root.getId())).isEmpty();
        assertThat(commentRepository.findById(reply.getId())).isEmpty();
    }

    @Test
    void 댓글이_달린_공지를_삭제할_수_있다() {
        Member admin = createMember("notice-del", MemberRole.ADMIN);
        Notice notice = noticeRepository.save(new Notice(
                "삭제 테스트", "내용", admin, NoticeType.NOTICE, null, Grade.ALL, false, null, null));
        Comment root = commentRepository.save(Comment.builder()
                .content("댓글").notice(notice).member(admin).build());
        Comment reply = commentRepository.save(Comment.builder()
                .content("대댓글").notice(notice).member(admin).parent(root).build());

        assertThatCode(() -> noticeService.deleteNotice(notice.getId(), admin.getId(), MemberRole.ADMIN))
                .doesNotThrowAnyException();

        assertThat(noticeRepository.findById(notice.getId())).isEmpty();
        assertThat(commentRepository.findById(root.getId())).isEmpty();
        assertThat(commentRepository.findById(reply.getId())).isEmpty();
    }

    @Test
    void 글을_삭제하면_그_글과_댓글을_가리키던_신고와_스크랩도_사라진다() {
        Member author = createMember("orphan", MemberRole.USER);
        Member reader = createMember("orphan-reader", MemberRole.USER);
        CommunityPost post = createPost(author);
        Comment comment = addPostComment(post, author, null);

        reportRepository.save(Report.builder()
                .reporter(reader).targetType(Report.TargetType.POST).targetId(post.getId())
                .reason("사유").build());
        reportRepository.save(Report.builder()
                .reporter(reader).targetType(Report.TargetType.COMMENT).targetId(comment.getId())
                .reason("사유").build());
        scrapRepository.save(Scrap.builder()
                .member(reader).targetType(TargetType.COMMUNITY).targetId(post.getId()).build());

        communityService.deletePost(post.getId(), author.getId(), MemberRole.USER);

        // 남으면 관리자 신고함에 열 수 없는 항목이 계속 보입니다.
        assertThat(reportRepository.countByTargetTypeAndTargetId(Report.TargetType.POST, post.getId()))
                .isZero();
        assertThat(reportRepository.countByTargetTypeAndTargetId(Report.TargetType.COMMENT, comment.getId()))
                .isZero();
        assertThat(scrapRepository.findByMemberIdAndTargetTypeAndTargetId(
                reader.getId(), TargetType.COMMUNITY, post.getId())).isEmpty();
    }

    @Test
    void 권한이_없으면_삭제도_정리도_일어나지_않는다() {
        Member author = createMember("perm-author", MemberRole.USER);
        Member stranger = createMember("perm-stranger", MemberRole.USER);
        CommunityPost post = createPost(author);
        Comment comment = addPostComment(post, author, null);

        assertThatThrownBy(() -> communityService.deletePost(post.getId(), stranger.getId(), MemberRole.USER))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("권한이 없습니다");

        assertThat(communityPostRepository.findById(post.getId())).isPresent();
        assertThat(commentRepository.findById(comment.getId())).isPresent();
    }
}
