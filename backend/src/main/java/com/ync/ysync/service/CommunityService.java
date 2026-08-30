package com.ync.ysync.service;

import com.ync.ysync.domain.CommunityPost;
import com.ync.ysync.domain.Grade;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.domain.PostImage;
import com.ync.ysync.repository.CommunityPostRepository;
import com.ync.ysync.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CommunityService {

    private final CommunityPostRepository communityPostRepository;
    private final MemberRepository memberRepository;
    private final FileService fileService;

    // 💡 카테고리별 혹은 전체 목록 조회 (고정글 우선, 최신순 필터링)
    public List<CommunityPost> getPosts(String category) {
        if (category == null || category.equals("ALL") || category.isEmpty()) {
            return communityPostRepository.findAllByOrderByIsPinnedDescCreatedAtDesc();
        }
        return communityPostRepository.findByCategoryOrderByIsPinnedDescCreatedAtDesc(category);
    }

    // 💡 커뮤니티 게시글 검색 (키워드 + 카테고리 조합)
    public List<CommunityPost> searchPosts(String keyword, String category) {
        if (category == null || category.equals("ALL") || category.isEmpty()) {
            return communityPostRepository.findByTitleContainingIgnoreCaseOrContentContainingIgnoreCaseOrderByIsPinnedDescCreatedAtDesc(keyword, keyword);
        }
        return communityPostRepository.searchByCategoryAndKeyword(category, keyword);
    }

    @Transactional
    public CommunityPost getPost(Long id) {
        CommunityPost post = communityPostRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("해당 게시글이 존재하지 않습니다."));
        post.incrementViewCount(); // 💡 상세 조회 시 조회수 1가
        return post;
    }

    // 💡 파일 이미지를 포함한 게시글 작성을 처리합니다.
    @Transactional
    public CommunityPost createPostWithImages(String category, String title, String content, boolean anonymous, Grade targetGrade, boolean isPinned, Long memberId, List<MultipartFile> images) {
        AttachmentValidator.validate(images);
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

        if (images != null && !images.isEmpty()) {
            for (MultipartFile file : images) {
                try {
                    String fileUrl = fileService.uploadFile(file);
                    if (fileUrl != null) {
                        PostImage postImage = PostImage.builder()
                                .imageUrl(fileUrl)
                                .originalFilename(file.getOriginalFilename())
                                .contentType(file.getContentType())
                                .fileSize(file.getSize())
                                .communityPost(post)
                                .build();
                        post.getImages().add(postImage);
                    }
                } catch (IOException e) {
                    throw new RuntimeException("파일 업로드 중 오류가 발생했습니다.", e);
                }
            }
        }

        return communityPostRepository.save(post);
    }

    // 작성자 본인의 게시글만 수정하고 새 파일이 있을 때에만 기존 첨부를 교체합니다.
    @Transactional
    public CommunityPost updatePost(Long id, String category, String title, String content,
                                    boolean anonymous, Grade targetGrade, Long memberId,
                                    List<MultipartFile> images) {
        AttachmentValidator.validate(images);
        CommunityPost post = communityPostRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("해당 게시글이 존재하지 않습니다."));

        if (!post.getMember().getId().equals(memberId)) {
            throw new IllegalArgumentException("게시글 수정 권한이 없습니다.");
        }
        if (post.isDeleted()) {
            throw new IllegalArgumentException("삭제된 게시글은 수정할 수 없습니다.");
        }

        post.update(category, title, content, anonymous, targetGrade);

        if (images != null && !images.isEmpty()) {
            post.getImages().clear();
            for (MultipartFile file : images) {
                try {
                    String fileUrl = fileService.uploadFile(file);
                    if (fileUrl != null) {
                        post.getImages().add(PostImage.builder()
                                .imageUrl(fileUrl)
                                .originalFilename(file.getOriginalFilename())
                                .contentType(file.getContentType())
                                .fileSize(file.getSize())
                                .communityPost(post)
                                .build());
                    }
                } catch (IOException e) {
                    throw new RuntimeException("파일 업로드 중 오류가 발생했습니다.", e);
                }
            }
        }

        return post;
    }

    // 💡 게시글 삭제를 처리합니다. 작성자 본인이거나 ADMIN인 경우만 가능합니다.
    @Transactional
    public void deletePost(Long id, Long memberId, MemberRole role) {
        // 💡 삭제 권한 확인은 실제 열람이 아니므로 조회수를 올리지 않고 게시글만 조회합니다.
        CommunityPost post = communityPostRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("해당 게시글이 존재하지 않습니다."));
        
        if (role != MemberRole.ADMIN && role != MemberRole.SUPER_ADMIN && !post.getMember().getId().equals(memberId)) {
            throw new IllegalArgumentException("게시글 삭제 권한이 없습니다.");
        }

        
        communityPostRepository.delete(post);
    }
}
