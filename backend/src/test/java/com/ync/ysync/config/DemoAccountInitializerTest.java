package com.ync.ysync.config;

import com.ync.ysync.repository.MemberRepository;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import static org.mockito.Mockito.mock;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DemoAccountInitializerTest {
    @Test void reservedSeedIdsAreRejectedEvenBeforeSeedDataExists() {
        for (String loginId : new String[]{"2305009", "2300001", "2300002", "2505034"}) {
            var initializer = new DemoAccountInitializer(mock(MemberRepository.class),
                    new BCryptPasswordEncoder(), true, loginId, "Demo-123!");
            assertThatThrownBy(initializer::run).as(loginId)
                    .isInstanceOf(IllegalStateException.class).hasMessageContaining("시드");
        }
    }
}
