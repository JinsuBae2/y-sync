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
