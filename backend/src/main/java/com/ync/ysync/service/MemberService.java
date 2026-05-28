package com.ync.ysync.service;

import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class MemberService {

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public Member signup(String loginId, String password, String name) {
        if (memberRepository.findByLoginId(loginId).isPresent()) {
            throw new IllegalArgumentException("이미 존재하는 아이디입니다.");
        }

        Member member = Member.builder()
                .loginId(loginId)
                .password(passwordEncoder.encode(password))
                .name(name)
                .role(MemberRole.USER) // 기본 권한
                .build();

        return memberRepository.save(member);
    }

    @Transactional(readOnly = true)
    public Member login(String loginId, String password) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new IllegalArgumentException("아이디 또는 비밀번호가 맞지 않습니다."));

        if (!passwordEncoder.matches(password, member.getPassword())) {
            throw new IllegalArgumentException("아이디 또는 비밀번호가 맞지 않습니다.");
        }

        return member;
    }

    @Transactional(readOnly = true)
    public Member socialLogin(String socialId, com.ync.ysync.domain.AuthProvider provider) {
        return memberRepository.findBySocialIdAndProvider(socialId, provider).orElse(null);
    }

    @Transactional
    public Member socialSignup(String loginId, String name, String socialId, com.ync.ysync.domain.AuthProvider provider, String password) {
        java.util.Optional<Member> existingMemberOpt = memberRepository.findByLoginId(loginId);
        
        if (existingMemberOpt.isPresent()) {
            Member existingMember = existingMemberOpt.get();
            
            // 기존 가입자가 존재하면 반드시 비밀번호를 확인하여 본인 인증
            if (password == null || password.trim().isEmpty()) {
                throw new IllegalArgumentException("REQUIRE_PASSWORD");
            }
            
            if (!passwordEncoder.matches(password, existingMember.getPassword())) {
                throw new IllegalArgumentException("비밀번호가 일치하지 않습니다.");
            }
            
            // 본인 인증이 완료되었으므로 소셜 계정 연동 및 이름 업데이트 허용
            if (!existingMember.getName().equals(name)) {
                existingMember.setName(name); 
            }
            existingMember.setProvider(provider);
            existingMember.setSocialId(socialId);
            return memberRepository.save(existingMember);
        }

        Member member = Member.builder()
                .loginId(loginId)
                .password(passwordEncoder.encode("SOCIAL_USER_PASSWORD")) // 소셜 계정용 더미 비밀번호
                .name(name)
                .role(MemberRole.USER)
                .provider(provider)
                .socialId(socialId)
                .authType(com.ync.ysync.domain.AuthType.PASSWORD)
                .build();

        return memberRepository.save(member);
    }

    @Transactional(readOnly = true)
    public Member findById(Long id) {
        return memberRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("회원을 찾을 수 없습니다."));
    }

    // 💡 FCM 토큰 업데이트
    @Transactional
    public void updateFcmToken(Long memberId, String fcmToken) {
        Member member = findById(memberId);
        member.setFcmToken(fcmToken);
    }
}
