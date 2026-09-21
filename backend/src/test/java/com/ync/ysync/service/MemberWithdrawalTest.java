package com.ync.ysync.service;

import com.ync.ysync.domain.AdminRequest;
import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Comment;
import com.ync.ysync.domain.CommunityPost;
import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.Notification;
import com.ync.ysync.domain.PersonalTimetableEntry;
import com.ync.ysync.domain.Scrap;
import com.ync.ysync.domain.TargetType;
import com.ync.ysync.repository.AdminRequestRepository;
import com.ync.ysync.repository.CommentRepository;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NotificationRepository;
import com.ync.ysync.repository.PersonalTimetableEntryRepository;
import com.ync.ysync.repository.ScrapRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.time.DayOfWeek;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 💡 관리자 회원 삭제가 "행 삭제"가 아니라 "계정 익명화"로 동작하는지 고정하는 테스트입니다.
 *
 * 운영 DB에서 `member`를 참조하는 FK가 8개인 것을 확인했습니다. 이전 구현은 회원 행을 그대로
 * 지웠기 때문에 **글이나 댓글을 쓴 적 있는 회원은 관리자도 삭제할 수 없었습니다.**
 * 딸린 데이터까지 지우는 방식은 그 사람의 글에 달린 다른 학생의 댓글까지 없애므로 택하지 않았습니다.
 *
 * 실제 DELETE·UPDATE가 DB까지 도달해야 FK 위반 여부를 볼 수 있으므로 클래스에 @Transactional을 걸지 않습니다.
 */
@SpringBootTest
class MemberWithdrawalTest {

    @Autowired private MemberService memberService;
    @Autowired private MemberRepository memberRepository;
    @Autowired private CommunityPostRepository communityPostRepository;
    @Autowired private CommentRepository commentRepository;
    @Autowired private NotificationRepository notificationRepository;
    @Autowired private ScrapRepository scrapRepository;
    @Autowired private PersonalTimetableEntryRepository personalTimetableEntryRepository;
    @Autowired private AdminRequestRepository adminRequestRepository;
    @Autowired private PasswordEncoder passwordEncoder;

    @MockitoBean private JavaMailSender javaMailSender;

    private Member createMember(String loginId, String name, MemberRole role) {
        Member member = memberRepository.save(Member.builder()
                .loginId(loginId).password(passwordEncoder.encode("Password!234")).name(name)
                .role(role).provider(AuthProvider.LOCAL).authType(AuthType.PASSWORD)
                .isActivated(true).isSuspended(false)
                .build());
        member.setEmail(loginId + "@ync.ac.kr");
        member.setFcmToken("fcm-token");
        return memberRepository.save(member);
    }

    private CommunityPost createPost(Member author) {
        return communityPostRepository.save(CommunityPost.builder()
                .category("FREE").title("글").content("내용")
                .anonymous(false).member(author).targetGrade(Grade.ALL).isPinned(false)
                .build());
    }

    @Test
    void 글과_댓글을_쓴_회원도_탈퇴_처리할_수_있다() {
        Member member = createMember("wd-" + System.nanoTime(), "홍길동", MemberRole.USER);
        CommunityPost post = createPost(member);
        commentRepository.save(Comment.builder()
                .content("내 댓글").communityPost(post).member(member).build());

        assertThatCode(() -> memberService.deleteMemberByAdmin(member.getId()))
                .doesNotThrowAnyException();
    }

    @Test
    void 탈퇴하면_개인정보가_지워지고_다시_로그인할_수_없다() {
        String loginId = "wd-" + System.nanoTime();
        Member member = createMember(loginId, "홍길동", MemberRole.ADMIN);
        int authVersionBefore = member.getAuthVersion();

        memberService.deleteMemberByAdmin(member.getId());

        Member withdrawn = memberRepository.findById(member.getId()).orElseThrow();
        assertThat(withdrawn.isWithdrawn()).isTrue();
        assertThat(withdrawn.getLoginId()).isNotEqualTo(loginId).doesNotContain(loginId);
        assertThat(withdrawn.getName()).isEqualTo("탈퇴한 학생");
        assertThat(withdrawn.getEmail()).isNull();
        assertThat(withdrawn.getFcmToken()).isNull();
        // 관리자였다면 권한도 회수합니다.
        assertThat(withdrawn.getRole()).isEqualTo(MemberRole.USER);
        assertThat(withdrawn.isActivated()).isFalse();
        // 이미 발급된 JWT를 무효화합니다.
        assertThat(withdrawn.getAuthVersion()).isGreaterThan(authVersionBefore);
        // 어떤 비밀번호와도 일치하지 않습니다.
        assertThat(passwordEncoder.matches("Password!234", withdrawn.getPassword())).isFalse();
        // 학번이 풀리므로 같은 학생을 다시 사전 등록할 수 있습니다.
        assertThat(memberRepository.findByLoginId(loginId)).isEmpty();
    }

    @Test
    void 탈퇴해도_글과_댓글은_남고_다른_학생의_댓글도_지워지지_않는다() {
        Member author = createMember("wd-a-" + System.nanoTime(), "글쓴이", MemberRole.USER);
        Member other = createMember("wd-b-" + System.nanoTime(), "다른학생", MemberRole.USER);
        CommunityPost post = createPost(author);
        Comment mine = commentRepository.save(Comment.builder()
                .content("내 댓글").communityPost(post).member(author).build());
        Comment others = commentRepository.save(Comment.builder()
                .content("남의 댓글").communityPost(post).member(other).build());

        memberService.deleteMemberByAdmin(author.getId());

        assertThat(communityPostRepository.findById(post.getId())).isPresent();
        assertThat(commentRepository.findById(mine.getId())).isPresent();
        // 이 줄이 "딸린 데이터까지 삭제" 방식을 택하지 않은 이유입니다.
        assertThat(commentRepository.findById(others.getId())).isPresent();

        // 글의 작성자 행은 그대로 있고 이름만 바뀝니다. (지연 로딩 프록시를 피해 회원을 직접 조회합니다)
        assertThat(memberRepository.findById(author.getId()).orElseThrow().getName())
                .isEqualTo("탈퇴한 학생");
    }

    @Test
    void 탈퇴하면_본인만_보는_데이터는_함께_지워진다() {
        Member member = createMember("wd-p-" + System.nanoTime(), "홍길동", MemberRole.USER);
        CommunityPost post = createPost(member);

        notificationRepository.save(Notification.builder()
                .member(member).title("알림").body("내용")
                .targetType(TargetType.COMMUNITY).targetId(post.getId()).build());
        scrapRepository.save(Scrap.builder()
                .member(member).targetType(TargetType.COMMUNITY).targetId(post.getId()).build());
        personalTimetableEntryRepository.save(PersonalTimetableEntry.builder()
                .member(member).dayOfWeek(DayOfWeek.MONDAY).subjectName("자료구조")
                .professorName("김교수").classroom("공학관 201")
                .startPeriod(1).endPeriod(2).build());
        adminRequestRepository.save(AdminRequest.builder()
                .requester(member).reason("사유").build());

        memberService.deleteMemberByAdmin(member.getId());

        assertThat(notificationRepository.findByMemberIdOrderByCreatedAtDesc(member.getId())).isEmpty();
        assertThat(scrapRepository.findAllByMemberIdOrderByCreatedAtDesc(member.getId())).isEmpty();
        assertThat(personalTimetableEntryRepository.findAllByMemberId(member.getId())).isEmpty();
        assertThat(adminRequestRepository.findTopByRequesterIdOrderByRequestedAtDesc(member.getId())).isEmpty();
    }

    @Test
    void 탈퇴한_계정은_관리자_회원_목록에_보이지_않는다() {
        String loginId = "wd-list-" + System.nanoTime();
        Member member = createMember(loginId, "목록테스트", MemberRole.USER);

        assertThat(memberService.getMembers(PageRequest.of(0, 200), loginId).getContent())
                .extracting(Member::getId).contains(member.getId());

        memberService.deleteMemberByAdmin(member.getId());

        assertThat(memberService.getMembers(PageRequest.of(0, 200), loginId).getContent())
                .isEmpty();
        assertThat(memberService.getMembers(PageRequest.of(0, 500), null).getContent())
                .extracting(Member::getId).doesNotContain(member.getId());
    }

    @Test
    void SUPER_ADMIN과_이미_탈퇴한_계정은_처리하지_않는다() {
        Member superAdmin = createMember("wd-su-" + System.nanoTime(), "슈퍼", MemberRole.SUPER_ADMIN);
        assertThatThrownBy(() -> memberService.deleteMemberByAdmin(superAdmin.getId()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("SUPER_ADMIN");

        Member member = createMember("wd-twice-" + System.nanoTime(), "홍길동", MemberRole.USER);
        memberService.deleteMemberByAdmin(member.getId());
        assertThatThrownBy(() -> memberService.deleteMemberByAdmin(member.getId()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("이미 탈퇴");
    }
}
