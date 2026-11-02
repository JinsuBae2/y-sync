package com.ync.ysync.service;

import com.ync.ysync.domain.*;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.MemberRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import static org.assertj.core.api.Assertions.*;

@SpringBootTest
@Transactional
class CommunityFeedTest {
    @Autowired CommunityService service;
    @Autowired CommunityPostRepository posts;
    @Autowired MemberRepository members;
    @Autowired JdbcTemplate jdbc;
    @MockitoBean JavaMailSender mail;
    Member author;
    String marker;

    @BeforeEach void setup() {
        marker = "COMMFEED" + System.nanoTime();
        author = members.save(Member.builder().loginId(marker).password("encoded").name("작성자")
                .role(MemberRole.USER).provider(AuthProvider.LOCAL).authType(AuthType.PASSWORD)
                .isActivated(true).isSuspended(false).build());
    }
    CommunityPost post(String category, Grade grade, boolean pinned) {
        return posts.saveAndFlush(CommunityPost.builder().category(category).title(marker).content("본문")
                .member(author).targetGrade(grade).isPinned(pinned).build());
    }
    CommunityService.CommunityFeed page(String cursor, int size) {
        return service.getFeed(cursor,size,"ALL",Grade.ALL,marker);
    }
    @Test void 고정글과_같은_시각의_글도_누락_중복없이_이어받는다() {
        List<Long> normal = new ArrayList<>(), pinned = new ArrayList<>();
        for(int i=0;i<25;i++) {
            boolean pin=i%5==0;
            var p=post("FREE",Grade.ALL,pin);
            jdbc.update("update community_post set created_at = ? where id = ?",LocalDateTime.of(2026,11,2,9,0),p.getId());
            (pin?pinned:normal).add(p.getId());
        }
        // JPQL의 커서 값도 실제 DB 시각을 사용하도록 1차 캐시를 비웁니다.
        entityManager.clear();
        List<Long> actual = new ArrayList<>();
        String cursor=null;
        for(int guard=0;guard<20;guard++) {
            var page=page(cursor,3);
            assertThat(page.items()).hasSizeLessThanOrEqualTo(3);
            page.items().forEach(p->actual.add(p.getId()));
            if(!page.hasNext()) break;
            cursor=page.nextCursor();
        }
        List<Long> expected=new ArrayList<>(pinned.reversed());
        expected.addAll(normal.reversed());
        assertThat(actual).containsExactlyElementsOf(expected).doesNotHaveDuplicates();
    }
    @Autowired jakarta.persistence.EntityManager entityManager;
    @Test void 검색_분류_학년_삭제필터를_페이지_조회전에_적용한다() {
        var all=post("QA",Grade.ALL,false);
        var grade=post("QA",Grade.GRADE_2,false);
        post("QA",Grade.GRADE_1,false);
        post("FREE",Grade.GRADE_2,false);
        var deleted=post("QA",Grade.GRADE_2,true);
        deleted.deleteByAdmin("test"); posts.flush();
        var result=service.getFeed(null,20,"QA",Grade.GRADE_2,marker);
        assertThat(result.items()).extracting(CommunityPost::getId).containsExactly(grade.getId(),all.getId());
        assertThat(service.getFeed(null,20,"QA",Grade.GRADE_2,"없는검색어").items()).isEmpty();
    }
    @Test void 새글과_커서글_삭제가_다음페이지를_밀지_않는다() {
        var oldest=post("FREE",Grade.ALL,false);
        var middle=post("FREE",Grade.ALL,false);
        post("FREE",Grade.ALL,false);
        var first=page(null,2);
        post("FREE",Grade.ALL,false);
        posts.deleteById(middle.getId()); posts.flush();
        assertThat(page(first.nextCursor(),2).items()).extracting(CommunityPost::getId).containsExactly(oldest.getId());
    }
    @Test void 잘못된_커서와_크기를_거절한다() {
        assertThatThrownBy(()->page("invalid",20)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(()->page(null,0)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(()->page(null,51)).isInstanceOf(IllegalArgumentException.class);
    }
}
