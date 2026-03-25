package com.ync.ysync.service;

import com.ync.ysync.domain.CommunityPost;
import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CommunityService {

    private final CommunityPostRepository communityPostRepository;
    private final MemberRepository memberRepository;

    // 💡 카테고리별 혹은 전체 목록 조회 (고정글 우선, 최신순 필터링)
    public List<CommunityPost> getPosts(String category) {
        if (category == null || category.equals("ALL") || category.isEmpty()) {
            return communityPostRepository.findAllByOrderByIsPinnedDescCreatedAtDesc();
        }
        return communityPostRepository.findByCategoryOrderByIsPinnedDescCreatedAtDesc(category);
    }

    @Transactional
    public CommunityPost getPost(Long id) {
        CommunityPost post = communityPostRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("해당 게시글이 존재하지 않습니다."));
        post.incrementViewCount(); // 💡 상세 조회 시 조회수 1가
        return post;
    }

    // 💡 게시글 작성을 처리합니다.
    @Transactional
    public CommunityPost createPost(String category, String title, String content, boolean anonymous, Grade targetGrade, boolean isPinned, Long memberId) {
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));

        CommunityPost post = CommunityPost.builder()
                .category(category)
                .title(title)
                .content(content)
                .anonymous(anonymous)
                .member(member)
                .targetGrade(targetGrade)
                .isPinned(isPinned)
                .build();

        return communityPostRepository.save(post);
    }

    // 💡 게시글 삭제를 처리합니다. 작성자 본인이거나 ADMIN인 경우만 가능합니다.
    @Transactional
    public void deletePost(Long id, Long memberId, MemberRole role) {
        CommunityPost post = getPost(id);
        
        if (role != MemberRole.ADMIN && !post.getMember().getId().equals(memberId)) {
            throw new IllegalArgumentException("게시글 삭제 권한이 없습니다.");
        }
        
        communityPostRepository.delete(post);
    }
}
