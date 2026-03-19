package com.ync.ysync.config;

import com.ync.ysync.domain.*;
import com.ync.ysync.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

/**
 * 💡 서버 시작 시 초기 데이터를 생성하는 initializer 클래스입니다.
 * 시연 및 개발 편의를 위해 마스터 계정, 테스트 학생, 공지사항, 커뮤니티 게시글, 댓글 등을 생성합니다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {

    private final MemberRepository memberRepository;
    private final NoticeRepository noticeRepository;
    private final CommunityPostRepository communityPostRepository;
    private final CommentRepository commentRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(String... args) throws Exception {
        // 1. 중복 생성 방지: 데이터가 이미 존재하면 스킵합니다.
        if (memberRepository.count() > 0) {
            log.info("ℹ️ 초기 데이터가 이미 존재하여 생성을 건너뜁니다.");
            return;
        }

        log.info("🚀 초기 데이터 생성을 시작합니다...");

        // --- 1. Member 생성 ---
        
        // 마스터 관리자 (ADMIN)
        Member admin = Member.builder()
                .loginId("2305009")
                .password(passwordEncoder.encode("ync2305009!"))
                .name("배진수")
                .role(MemberRole.ADMIN)
                .build();
        memberRepository.save(admin);

        // 테스트 이공대 학생 1 (USER)
        Member student1 = Member.builder()
                .loginId("2300001")
                .password(passwordEncoder.encode("test1234!"))
                .name("김철수")
                .role(MemberRole.USER)
                .build();
        memberRepository.save(student1);

        // 테스트 이공대 학생 2 (USER)
        Member student2 = Member.builder()
                .loginId("2300002")
                .password(passwordEncoder.encode("test1234!"))
                .name("이영희")
                .role(MemberRole.USER)
                .build();
        memberRepository.save(student2);

        // --- 2. Notice(공지사항) 생성 ---
        
        List<Notice> notices = new ArrayList<>();
        notices.add(Notice.builder()
                .title("2026 영남이공대 소프트웨어융합과 캡스톤 디자인 일정 안내")
                .content("이번 학기 캡스톤 디자인 최종 발표가 6월 중순에 예정되어 있습니다. 팀별 결과 보고서를 미리 준비해주세요.")
                .author(admin)
                .noticeType(NoticeType.OFFICIAL)
                .aiSummary("6월 중순 캡스톤 디자인 발표 및 보고서 제출 사전 안내입니다.")
                .build());
        
        notices.add(Notice.builder()
                .title("학부 과방 및 전공 실습실 이용 수칙 안내")
                .content("실습실 내 음식물 반입은 절대 금지됩니다. 퇴실 시 PC 전원을 꼭 꺼주시기 바랍니다. 파손 주의 부탁드립니다.")
                .author(admin)
                .noticeType(NoticeType.OFFICIAL)
                .aiSummary("실습실 내 음식물 반입 금지 및 퇴실 시 전원 확인 등 이용 수칙 안내입니다.")
                .build());

        notices.add(Notice.builder()
                .title("[공지] 영남이공대학교 장학금 신청 기간 안내")
                .content("성적 장학금 및 복지 장학금 신청이 다음 주 월요일부터 시작됩니다. 학부 사무실에 서류를 제출해 주세요.")
                .author(admin)
                .noticeType(NoticeType.OFFICIAL)
                .aiSummary("다음 주부터 시작되는 성적/복지 장학금 신청 기간 및 방법 안내입니다.")
                .build());

        notices.add(Notice.builder()
                .title("2026학년도 하계 방학 특강(자바/코틀린) 모집")
                .content("방학 중 자바와 코틀린 실무 역량을 키울 학생들을 모집합니다. 선착순 20명입니다.")
                .author(admin)
                .noticeType(NoticeType.INTERNAL)
                .aiSummary("하계 방학 자바 및 코틀린 실무 특강 참여 학생 선착순 모집 안내입니다.")
                .build());

        notices.add(Notice.builder()
                .title("계명대-영남이공대 연합 해커톤 참가자 모집")
                .content("인근 대학과의 연합 해커톤이 개최됩니다. 우승 팀에게는 상금과 부상이 주어집니다.")
                .author(admin)
                .noticeType(NoticeType.INTERNAL)
                .aiSummary("타 대학 연합 해커톤 개최 소식 및 참가자 모집 안내입니다.")
                .build());

        noticeRepository.saveAll(notices);

        // --- 3. CommunityPost(커뮤니티) 생성 ---
        
        List<CommunityPost> posts = new ArrayList<>();
        
        // QA
        posts.add(CommunityPost.builder()
                .category("QA")
                .title("자바 환경 변수 설정 질문이요!")
                .content("맥북에서 JAVA_HOME 설정을 했는데도 terminal에서 인식이 안 됩니다. zshrc 문제일까요?")
                .anonymous(false)
                .member(student1)
                .build());

        posts.add(CommunityPost.builder()
                .category("QA")
                .title("안드로이드 스튜디오 에뮬레이터 에러 (HELP)")
                .content("VT-x disabled in BIOS 에러가 뜨는데 어떻게 해결하나요? 윈도우 환경입니다.")
                .anonymous(true)
                .member(student2)
                .build());

        // TEAM
        posts.add(CommunityPost.builder()
                .category("TEAM")
                .title("[팀원모집] 대구 관광 앱 해커톤 함께하실 분!")
                .content("백엔드(스프링) 가능하신 분 한 명 더 구합니다. 현재 기획자와 디자이너는 있습니다.")
                .anonymous(false)
                .member(student1)
                .build());

        posts.add(CommunityPost.builder()
                .category("TEAM")
                .title("알고리즘 스터디 모집 (매주 목요일)")
                .content("프로그래머스 레벨 2~3 위주로 풀 계획입니다. 성실히 하실 분 모십니다.")
                .anonymous(true)
                .member(student2)
                .build());

        // FREE
        posts.add(CommunityPost.builder()
                .category("FREE")
                .title("영남이공대 정문 근처 가성비 맛집 추천")
                .content("오늘 점심 먹으러 가는데 가성비 좋은 돼지국밥집 어디가 괜찮나요?")
                .anonymous(false)
                .member(student2)
                .build());

        posts.add(CommunityPost.builder()
                .category("FREE")
                .title("오늘 학식 메뉴 뭔가요?")
                .content("배고픈데 메뉴 확인하기 귀찮네요... 아시는 분?")
                .anonymous(true)
                .member(student1)
                .build());

        posts.add(CommunityPost.builder()
                .category("FREE")
                .title("시험 기간 도서관 자리 있나요?")
                .content("지금 도서관 자리 꽉 찼나요? 가야 할지 말지 고민이네요.")
                .anonymous(true)
                .member(student2)
                .build());

        posts.add(CommunityPost.builder()
                .category("QA")
                .title("깃허브 잔디가 안 심어져요 ㅠㅠ")
                .content("Config 이메일 설정을 다르게 한 것 같은데 이미 커밋한 건 어떻게 바꾸나요?")
                .anonymous(false)
                .member(student1)
                .build());

        posts.add(CommunityPost.builder()
                .category("TEAM")
                .title("졸업 작품 안드로이드 개발자 구합니다.")
                .content("이미 기획은 끝났고 개발만 같이 하실 분 찾습니다. 코틀린 사용합니다.")
                .anonymous(false)
                .member(student2)
                .build());

        posts.add(CommunityPost.builder()
                .category("FREE")
                .title("종강까지 며칠 남았죠?")
                .content("종강만 기다리는 중입니다. 시간 왜 이렇게 안 가죠??")
                .anonymous(true)
                .member(student1)
                .build());

        communityPostRepository.saveAll(posts);

        // --- 4. Comment(댓글) 생성 ---
        
        List<Comment> comments = new ArrayList<>();
        
        // 공지 댓글
        comments.add(Comment.builder()
                .content("캡스톤 디자인 일정 확인했습니다. 감사합니다!")
                .notice(notices.get(0))
                .member(student1)
                .build());
        
        comments.add(Comment.builder()
                .content("실습실 이용 수칙 꼭 지키겠습니다.")
                .notice(notices.get(1))
                .member(student2)
                .build());

        // 게시글 댓글
        comments.add(Comment.builder()
                .content("source ~/.zshrc 명령어를 실행해 보셨나요?")
                .communityPost(posts.get(0))
                .member(student2)
                .build());

        comments.add(Comment.builder()
                .content("아, 그 명령어를 빼먹었네요! 감사합니다 해결됐어요.")
                .communityPost(posts.get(0))
                .member(student1)
                .build());

        comments.add(Comment.builder()
                .content("BIOS 들어가서 Virtualization 설정을 Enabled로 바꿔야 합니다.")
                .communityPost(posts.get(1))
                .member(student1)
                .build());

        comments.add(Comment.builder()
                .content("해커톤 팀에 관심 있습니다! 쪽지 드릴게요.")
                .communityPost(posts.get(2))
                .member(student2)
                .build());

        comments.add(Comment.builder()
                .content("정문 앞에 '영남식당' 국밥 진짜 맛있어요.")
                .communityPost(posts.get(4))
                .member(student1)
                .build());

        comments.add(Comment.builder()
                .content("오늘 학식 돈까스인데 사람 엄청 많더라고요.")
                .communityPost(posts.get(5))
                .member(student2)
                .build());

        comments.add(Comment.builder()
                .content("도서관 3층에 자리 좀 남아있어요 지금 오셔도 될 듯요.")
                .communityPost(posts.get(6))
                .member(student1)
                .build());

        comments.add(Comment.builder()
                .content("필터링된 커밋 작성자 수정하는 git filter-branch 명령어가 있어요.")
                .communityPost(posts.get(7))
                .member(student2)
                .build());

        comments.add(Comment.builder()
                .content("저도 종강만 기다려요... 2주 남았네요 ㅠㅠ")
                .communityPost(posts.get(9))
                .member(student2)
                .build());

        comments.add(Comment.builder()
                .content("장학금 서류 내일 제출해야겠네요.")
                .notice(notices.get(2))
                .member(student1)
                .build());

        comments.add(Comment.builder()
                .content("특강 선착순 끝났나요?")
                .notice(notices.get(3))
                .member(student2)
                .build());

        comments.add(Comment.builder()
                .content("해커톤 참가 신청 완료했습니다!")
                .notice(notices.get(4))
                .member(student1)
                .build());

        comments.add(Comment.builder()
                .content("이번 캡스톤 주제는 인공지능 활용인가요?")
                .notice(notices.get(0))
                .member(student2)
                .build());

        commentRepository.saveAll(comments);

        log.info("✅ 초기 데이터 생성이 완료되었습니다!");
    }
}
