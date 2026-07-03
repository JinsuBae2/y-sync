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
    private final CalendarEventRepository calendarEventRepository;
    private final TimetableEntryRepository timetableEntryRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(String... args) throws Exception {
        // --- 0. 기존 DB 회원 마이그레이션 (안전장치) ---
        // 이미 유효한 암호화된 비밀번호를 가진 계정들은 isActivated = true로 일괄 마이그레이션합니다.
        memberRepository.findAll().forEach(member -> {
            if (!member.isActivated() && member.getPassword() != null && !member.getPassword().trim().isEmpty() && !member.getPassword().startsWith("TEMP_")) {
                member.setActivated(true);
                memberRepository.save(member);
                log.info("Migration: 회원 [{}] 계정을 활성화 상태(isActivated=true)로 업데이트했습니다.", member.getLoginId());
            }
        });

        // --- 1. Member 생성 (Upsert 방식) ---
        
        // 1. 마스터 관리자 (배진수)
        Member admin = memberRepository.findByLoginId("2305009").orElseGet(() -> 
                Member.builder().loginId("2305009").password(passwordEncoder.encode("ync2305009!")).name("배진수").isActivated(true).build());
        admin.setRole(MemberRole.SUPER_ADMIN); // 💡 항상 SUPER_ADMIN으로 보장
        admin.setActivated(true);
        memberRepository.save(admin);

        // 2. 테스트 학생 1
        Member student1 = memberRepository.findByLoginId("2300001").orElseGet(() -> 
                Member.builder().loginId("2300001").password(passwordEncoder.encode("test1234!")).name("김철수").isActivated(true).build());
        student1.setRole(MemberRole.USER);
        student1.setActivated(true);
        memberRepository.save(student1);

        // 3. 테스트 학생 2
        Member student2 = memberRepository.findByLoginId("2300002").orElseGet(() -> 
                Member.builder().loginId("2300002").password(passwordEncoder.encode("test1234!")).name("이영희").isActivated(true).build());
        student2.setRole(MemberRole.USER);
        student2.setActivated(true);
        memberRepository.save(student2);

        // 4. 테스트용 가입 대기 학생 (김수빈 - 2505034)
        Member testPendingStudent = memberRepository.findByLoginId("2505034").orElseGet(() -> 
                Member.builder()
                        .loginId("2505034")
                        .password(passwordEncoder.encode("TEMP_2505034_PENDING"))
                        .name("김수빈")
                        .isActivated(false) // 💡 회원가입 테스트가 가능하도록 비활성 상태로 유지
                        .build());
        testPendingStudent.setRole(MemberRole.USER);
        memberRepository.save(testPendingStudent);

        // --- 2. 기존 데이터 정리 및 재생성 (공용 데이터는 이미 있으면 유지 가능하지만 시연용이므로 조건부 생성) ---
        if (noticeRepository.count() == 0) {
            log.info("🚀 초기 공지사항 및 게시글 생성을 시작합니다...");

            // --- 2. Notice(공지사항) 생성 ---
            List<Notice> notices = new ArrayList<>();
            notices.add(Notice.builder()
                    .title("2026 영남이공대 소프트웨어융합과 캡스톤 디자인 일정 안내")
                    .content("이번 학기 캡스톤 디자인 최종 발표가 6월 중순에 예정되어 있습니다. 팀별 결과 보고서를 미리 준비해주세요.")
                    .author(admin)
                    .noticeType(NoticeType.NOTICE)
                    .aiSummary("6월 중순 캡스톤 디자인 발표 및 보고서 제출 사전 안내입니다.")
                    .eventStartDate(java.time.LocalDate.of(2026, 6, 15))
                    .eventEndDate(java.time.LocalDate.of(2026, 6, 15))
                    .build());
            
            notices.add(Notice.builder()
                    .title("학부 과방 및 전공 실습실 이용 수칙 안내")
                    .content("실습실 내 음식물 반입은 절대 금지됩니다. 퇴실 시 PC 전원을 꼭 꺼주시기 바랍니다. 파손 주의 부탁드립니다.")
                    .author(admin)
                    .noticeType(NoticeType.NOTICE)
                    .aiSummary("실습실 내 음식물 반입 금지 및 퇴실 시 전원 확인 등 이용 수칙 안내입니다.")
                    .build());

            notices.add(Notice.builder()
                    .title("[공지] 영남이공대학교 장학금 신청 기간 안내")
                    .content("성적 장학금 및 복지 장학금 신청이 다음 주 월요일부터 시작됩니다. 학부 사무실에 서류를 제출해 주세요.")
                    .author(admin)
                    .noticeType(NoticeType.NOTICE)
                    .aiSummary("다음 주부터 시작되는 성적/복지 장학금 신청 기간 및 방법 안내입니다.")
                    .build());

            notices.add(Notice.builder()
                    .title("2026학년도 하계 방학 특강(자바/코틀린) 모집")
                    .content("방학 중 자바와 코틀린 실무 역량을 키울 학생들을 모집합니다. 선착순 20명입니다.")
                    .author(admin)
                    .noticeType(NoticeType.NEWS)
                    .aiSummary("하계 방학 자바 및 코틀린 실무 특강 참여 학생 선착순 모집 안내입니다.")
                    .eventStartDate(java.time.LocalDate.of(2026, 7, 1))
                    .eventEndDate(java.time.LocalDate.of(2026, 7, 5))
                    .build());

            notices.add(Notice.builder()
                    .title("계명대-영남이공대 연합 해커톤 참가자 모집")
                    .content("인근 대학과의 연합 해커톤이 개최됩니다. 우승 팀에게는 상금과 부상이 주어집니다.")
                    .author(admin)
                    .noticeType(NoticeType.NEWS)
                    .aiSummary("타 대학 연합 해커톤 개최 소식 및 참가자 모집 안내입니다.")
                    .eventStartDate(java.time.LocalDate.of(2026, 8, 10))
                    .eventEndDate(java.time.LocalDate.of(2026, 8, 12))
                    .build());

            noticeRepository.saveAll(notices);

            // --- 3. CommunityPost(커뮤니티) 생성 ---
            List<CommunityPost> posts = new ArrayList<>();
            posts.add(CommunityPost.builder().category("QA").title("자바 환경 변수 설정 질문이요!").content("맥북에서 JAVA_HOME 설정을 했는데도 terminal에서 인식이 안 됩니다.").anonymous(false).member(admin).build());
            posts.add(CommunityPost.builder().category("QA").title("안드로이드 스튜디오 에뮬레이터 에러").content("VT-x disabled in BIOS 에러가 뜨는데 어떻게 해결하나요?").anonymous(true).member(student2).build());
            posts.add(CommunityPost.builder().category("TEAM").title("[팀원모집] 대구 관광 앱 해커톤").content("백엔드(스프링) 가능하신 분 한 명 더 구합니다.").anonymous(false).member(student1).build());
            posts.add(CommunityPost.builder().category("TEAM").title("알고리즘 스터디 모집").content("프로그래머스 레벨 2~3 위주로 풀 계획입니다.").anonymous(true).member(student2).build());
            posts.add(CommunityPost.builder().category("FREE").title("영남이공대 정문 근처 가성비 맛집").content("오늘 점심 먹으러 가는데 추천 부탁드려요.").anonymous(false).member(student2).build());
            posts.add(CommunityPost.builder().category("FREE").title("오늘 학식 메뉴 뭔가요?").content("배고픈데 메뉴 확인해주실 분?").anonymous(true).member(admin).build());
            posts.add(CommunityPost.builder().category("FREE").title("시험 기간 도서관 자리 있나요?").content("지금 도서관 자리 꽉 찼나요?").anonymous(true).member(student2).build());
            posts.add(CommunityPost.builder().category("QA").title("깃허브 잔디가 안 심어져요").content("이메일 설정을 다르게 한 것 같은데 어떻게 바꾸나요?").anonymous(false).member(student1).build());
            posts.add(CommunityPost.builder().category("TEAM").title("졸업 작품 안드로이드 개발자 구합니다.").content("이미 기획은 끝났고 개발만 같이 하실 분 찾습니다.").anonymous(false).member(student2).build());
            posts.add(CommunityPost.builder().category("FREE").title("종강까지 며칠 남았죠?").content("종강만 기다리는 중입니다.").anonymous(true).member(student1).build());

            communityPostRepository.saveAll(posts);

            // --- 4. Comment(댓글) 생성 ---
            List<Comment> comments = new ArrayList<>();
            comments.add(Comment.builder().content("캡스톤 디자인 일정 확인했습니다!").notice(notices.get(0)).member(student1).build());
            comments.add(Comment.builder().content("source ~/.zshrc 명령어를 실행해 보세요.").communityPost(posts.get(0)).member(student2).build());
            comments.add(Comment.builder().content("정문 앞에 '영남식당' 국밥 진짜 맛있어요.").communityPost(posts.get(4)).member(admin).build());
            
            commentRepository.saveAll(comments);

            // --- 5. CalendarEvent(학사 일정) 생성 ---
            List<CalendarEvent> events = new ArrayList<>();
            events.add(CalendarEvent.builder()
                    .title("1학기 중간고사")
                    .description("중간고사 시험 기간입니다. 학생분들은 실습 과목 일정을 확인하세요.")
                    .startDate(java.time.LocalDate.of(2026, 4, 20))
                    .endDate(java.time.LocalDate.of(2026, 4, 24))
                    .color("#FF5733")
                    .build());
            events.add(CalendarEvent.builder()
                    .title("개교기념일")
                    .description("휴강일입니다.")
                    .startDate(java.time.LocalDate.of(2026, 5, 15))
                    .endDate(java.time.LocalDate.of(2026, 5, 15))
                    .color("#8E44AD")
                    .build());
            calendarEventRepository.saveAll(events);

            // --- 6. TimetableEntry(과 시간표) 생성 ---
            List<TimetableEntry> timetables = new ArrayList<>();
            timetables.add(TimetableEntry.builder()
                    .grade(Grade.GRADE_1)
                    .dayOfWeek(java.time.DayOfWeek.MONDAY)
                    .subjectName("모바일 앱 개발")
                    .professorName("김철수 교수")
                    .classroom("정보관 303호")
                    .startPeriod(1)
                    .endPeriod(2)
                    .build());
            timetables.add(TimetableEntry.builder()
                    .grade(Grade.GRADE_1)
                    .dayOfWeek(java.time.DayOfWeek.MONDAY)
                    .subjectName("데이터베이스 실무")
                    .professorName("이영희 교수")
                    .classroom("정보관 304호")
                    .startPeriod(3)
                    .endPeriod(4)
                    .build());
            timetables.add(TimetableEntry.builder()
                    .grade(Grade.GRADE_1)
                    .dayOfWeek(java.time.DayOfWeek.TUESDAY)
                    .subjectName("서버 프레임워크")
                    .professorName("박민수 교수")
                    .classroom("정보관 401호")
                    .startPeriod(5)
                    .endPeriod(6)
                    .build());
            timetables.add(TimetableEntry.builder()
                    .grade(Grade.GRADE_2)
                    .dayOfWeek(java.time.DayOfWeek.MONDAY)
                    .subjectName("캡스톤 디자인")
                    .professorName("배진수 교수")
                    .classroom("정보관 402호")
                    .startPeriod(3)
                    .endPeriod(4)
                    .build());

            timetableEntryRepository.saveAll(timetables);

            log.info("✅ 초기 데이터 생성이 완료되었습니다!");
        }
    }
}
