package com.ync.ysync.config;

import com.ync.ysync.repository.CalendarEventRepository;
import com.ync.ysync.repository.CommentRepository;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.MemberRepository;
import com.ync.ysync.repository.NoticeRepository;
import com.ync.ysync.repository.TimetableEntryRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import static org.mockito.Mockito.verifyNoInteractions;

/**
 * 💡 시드 계정 비밀번호를 소스에서 설정으로 옮긴 뒤의 동작을 고정합니다.
 *
 * 평문 비밀번호를 소스에 두면 깃 히스토리에 영구히 남습니다. 설정으로 옮긴 대신,
 * 값이 없을 때 임의의 기본값으로 계정을 만들지 않고 아무것도 하지 않아야 합니다.
 * 알려진 비밀번호를 가진 계정이 조용히 생기는 편이 더 위험하기 때문입니다.
 */
@ExtendWith(MockitoExtension.class)
class DataInitializerSeedPasswordTest {

    @Mock private MemberRepository memberRepository;
    @Mock private NoticeRepository noticeRepository;
    @Mock private CommunityPostRepository communityPostRepository;
    @Mock private CommentRepository commentRepository;
    @Mock private CalendarEventRepository calendarEventRepository;
    @Mock private TimetableEntryRepository timetableEntryRepository;
    @Mock private PasswordEncoder passwordEncoder;

    private DataInitializer initializerWithSeedPassword(String seedPassword) {
        DataInitializer initializer = new DataInitializer(
                memberRepository, noticeRepository, communityPostRepository,
                commentRepository, calendarEventRepository, timetableEntryRepository,
                passwordEncoder);
        ReflectionTestUtils.setField(initializer, "seedPassword", seedPassword);
        return initializer;
    }

    @Test
    void 시드_비밀번호가_없으면_계정을_만들지_않는다() throws Exception {
        initializerWithSeedPassword(null).run();

        verifyNoInteractions(memberRepository, noticeRepository, communityPostRepository,
                commentRepository, calendarEventRepository, timetableEntryRepository, passwordEncoder);
    }

    @Test
    void 빈_문자열도_미설정으로_본다() throws Exception {
        initializerWithSeedPassword("   ").run();

        verifyNoInteractions(memberRepository, passwordEncoder);
    }
}
