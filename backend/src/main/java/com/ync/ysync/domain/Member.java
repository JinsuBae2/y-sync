package com.ync.ysync.domain;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.Setter; // 💡 추가
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class Member {

    // 💡 탈퇴 처리된 계정이 작성한 글·댓글에 표시되는 이름입니다.
    public static final String WITHDRAWN_NAME = "탈퇴한 학생";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String loginId;

    @Column(nullable = false)
    @Setter
    @JsonIgnore
    private String password;

    @Column(unique = true)
    @Setter
    private String email;

    @Column(nullable = false)
    @Setter
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Setter // 💡 권한 변경을 위해 세터 추가
    private MemberRole role;

    // 💡 소셜 로그인 관련 필드 추가
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Setter
    private AuthProvider provider;

    @Column(unique = true)
    @Setter
    private String socialId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Setter
    private AuthType authType;

    // 💡 푸시 알림 전송을 위한 FCM 디바이스 토큰
    @Setter
    @Column(length = 500)
    private String fcmToken;

    @Setter
    @Column(nullable = false)
    private boolean noticeEnabled = true;

    @Setter
    @Column(nullable = false)
    private boolean commentEnabled = true;

    @Setter
    @Column(nullable = false)
    private boolean isActivated = false; // 💡 회원가입(활성화) 여부

    @Setter
    @Column(nullable = false)
    private boolean isSuspended = false; // 💡 차단 여부 필드 추가

    @Setter
    @Column(nullable = false, columnDefinition = "int default 0")
    private int authVersion = 0;

    // 💡 회원이 직접 선택한 공지 알림 수신 대상입니다. null은 '미설정'을 뜻합니다.
    //    기존 회원과 이전 버전 클라이언트 호환을 위해 nullable로 도입합니다.
    @Enumerated(EnumType.STRING)
    @Setter
    @Column(length = 20)
    private NoticeGradePreference noticeGradePreference;

    // 💡 서버가 계산한 마지막 확인 학년도입니다. null은 확인 이력이 없음을 뜻합니다.
    @Setter
    private Integer gradeConfirmedYear;

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    // 💡 탈퇴(익명화) 시각입니다. null이면 정상 회원입니다.
    //    회원 행을 지우지 않는 이유는 member를 참조하는 FK가 8개라 글·댓글을 쓴 회원은 삭제 자체가
    //    제약 위반으로 실패하고, 억지로 지우면 다른 사람의 대댓글까지 함께 사라지기 때문입니다.
    private LocalDateTime withdrawnAt;

    public boolean isWithdrawn() {
        return withdrawnAt != null;
    }

    /**
     * 💡 계정에서 개인을 특정할 수 있는 값을 모두 지우고 다시 로그인할 수 없는 상태로 만듭니다.
     *    작성한 글과 댓글은 남으며 작성자 이름은 "탈퇴한 학생"으로 보입니다.
     *
     * @param anonymousLoginId 학번을 대신할 식별자. loginId는 NOT NULL·UNIQUE라 비울 수 없습니다.
     * @param unusablePassword 어떤 입력과도 일치하지 않는 인코딩된 값
     */
    public void withdraw(String anonymousLoginId, String unusablePassword, LocalDateTime withdrawnAt) {
        this.loginId = anonymousLoginId;   // 학번 제거
        this.password = unusablePassword;
        this.email = null;
        this.name = WITHDRAWN_NAME;
        this.socialId = null;
        this.fcmToken = null;              // 더 이상 푸시가 가지 않도록
        this.role = MemberRole.USER;       // 관리자였다면 권한을 회수합니다
        this.isActivated = false;
        this.isSuspended = false;
        this.noticeEnabled = false;
        this.commentEnabled = false;
        this.noticeGradePreference = null;
        this.gradeConfirmedYear = null;
        this.authVersion = this.authVersion + 1; // 이미 발급된 JWT 무효화
        this.withdrawnAt = withdrawnAt;
    }

    @Builder
    public Member(String loginId, String password, String name, MemberRole role, AuthProvider provider, String socialId, AuthType authType, boolean isActivated, boolean isSuspended) {
        this.loginId = loginId;
        this.password = password;
        this.name = name;
        this.role = role;
        this.provider = provider != null ? provider : AuthProvider.LOCAL;
        this.socialId = socialId;
        this.authType = authType != null ? authType : AuthType.PASSWORD;
        this.noticeEnabled = true;
        this.commentEnabled = true;
        this.isActivated = isActivated;
        this.isSuspended = isSuspended;
    }
}
