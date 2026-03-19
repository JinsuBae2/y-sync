package com.ync.ysync.service;

import com.ync.ysync.domain.CommunityPost;
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

    // 💡 카테고리별 혹은 전체 목록 조회 (keyword 필수는 아니므로 category 기반 필터링)
    public List<CommunityPost> getPosts(String category) {
        if (category == null || category.equals("ALL") || category.isEmpty()) {
            return communityPostRepository.findAllByOrderByCreatedAtDesc();
        }
        return communityPostRepository.findByCategoryOrderByCreatedAtDesc(category);
    }

    public CommunityPost getPost(Long id) {
        return communityPostRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("해당 게시글이 존재하지 않습니다."));
    }

    // 💡 게시글 작성을 처리합니다.
    @Transactional
    public CommunityPost createPost(String category, String title, String content, boolean anonymous, Long memberId) {
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));

        CommunityPost post = CommunityPost.builder()
                .category(category)
                .title(title)
                .content(content)
                .anonymous(anonymous)
                .member(member)
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
