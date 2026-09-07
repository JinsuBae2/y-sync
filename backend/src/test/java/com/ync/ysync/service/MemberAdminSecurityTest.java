package com.ync.ysync.service;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.repository.MemberRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MemberAdminSecurityTest {

    @Mock
    private MemberRepository memberRepository;
    @Mock
    private PasswordEncoder passwordEncoder;
    @Mock
    private EmailService emailService;

    private MemberService memberService;

    @BeforeEach
    void setUp() {
        memberService = new MemberService(memberRepository, passwordEncoder, emailService);
    }

    @Test
    void admin은_superAdmin_계정을_생성할_수_없다() {
        assertThatThrownBy(() -> memberService.createMemberByAdmin(
                "2305001", "관리대상", MemberRole.SUPER_ADMIN, MemberRole.ADMIN))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("SUPER_ADMIN");

        verify(memberRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void admin은_자신이나_다른_회원을_superAdmin으로_승격할_수_없다() {
        Member target = member(MemberRole.ADMIN);
        when(memberRepository.findById(1L)).thenReturn(Optional.of(target));

        assertThatThrownBy(() -> memberService.updateMemberByAdmin(
                1L, null, MemberRole.SUPER_ADMIN, MemberRole.ADMIN))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("SUPER_ADMIN");

        assertThat(target.getRole()).isEqualTo(MemberRole.ADMIN);
        assertThat(target.getAuthVersion()).isZero();
        verify(memberRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void admin은_CSV로도_superAdmin을_생성할_수_없다() {
        ByteArrayInputStream csv = new ByteArrayInputStream(
                "loginId,name,role\n2305001,관리대상,SUPER_ADMIN\n".getBytes(StandardCharsets.UTF_8));

        MemberService.CsvImportResult result = memberService.createMembersByCsv(csv, MemberRole.ADMIN);

        assertThat(result.createdCount()).isZero();
        assertThat(result.errorCount()).isEqualTo(1);
        assertThat(result.errors().getFirst().message()).contains("SUPER_ADMIN");
        verify(memberRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void csv_등록은_신규_중복_오류를_구분한다() {
        ByteArrayInputStream csv = new ByteArrayInputStream(("학번,이름,역할\n"
                + "2305001,신규학생,USER\n"
                + "2305002,기존학생,USER\n"
                + "2305001,파일중복,USER\n"
                + "not-number,오류학생,USER\n").getBytes(StandardCharsets.UTF_8));
        Member existing = Member.builder()
                .loginId("2305002")
                .password("encoded-password")
                .name("기존학생")
                .role(MemberRole.USER)
                .provider(AuthProvider.LOCAL)
                .authType(AuthType.PASSWORD)
                .isActivated(true)
                .build();
        when(memberRepository.findAllByLoginIdIn(org.mockito.ArgumentMatchers.anyCollection()))
                .thenReturn(List.of(existing));

        MemberService.CsvImportResult result = memberService.createMembersByCsv(csv, MemberRole.ADMIN);

        assertThat(result.totalCount()).isEqualTo(4);
        assertThat(result.createdCount()).isEqualTo(1);
        assertThat(result.duplicateCount()).isEqualTo(2);
        assertThat(result.errorCount()).isEqualTo(1);
        assertThat(result.errors().getFirst().row()).isEqualTo(5);
        verify(memberRepository).saveAll(org.mockito.ArgumentMatchers.anyCollection());
    }

    @Test
    void csv_헤더_순서가_달라도_필요한_열만_자동으로_찾는다() {
        ByteArrayInputStream csv = new ByteArrayInputStream(("이름,전화번호,주소,학번\n"
                + "홍길동,010-1234-5678,대구광역시,2305003\n").getBytes(StandardCharsets.UTF_8));
        when(memberRepository.findAllByLoginIdIn(org.mockito.ArgumentMatchers.anyCollection()))
                .thenReturn(List.of());

        MemberService.CsvImportResult result = memberService.createMembersByCsv(csv, MemberRole.ADMIN);

        assertThat(result.createdCount()).isEqualTo(1);
        assertThat(result.errorCount()).isZero();
        verify(memberRepository).saveAll(org.mockito.ArgumentMatchers.argThat(members -> {
            Member saved = ((List<Member>) members).getFirst();
            return saved.getLoginId().equals("2305003")
                    && saved.getName().equals("홍길동")
                    && saved.getRole() == MemberRole.USER;
        }));
    }

    @Test
    void csv_필수_헤더가_없으면_등록을_중단한다() {
        ByteArrayInputStream csv = new ByteArrayInputStream(
                "이름,전화번호,주소\n홍길동,010-1234-5678,대구광역시\n".getBytes(StandardCharsets.UTF_8));

        assertThatThrownBy(() -> memberService.createMembersByCsv(csv, MemberRole.ADMIN))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("학번과 이름 열");

        verify(memberRepository, never()).saveAll(org.mockito.ArgumentMatchers.anyCollection());
    }

    @Test
    void excel_명단도_불필요한_열을_제외하고_등록한다() throws Exception {
        byte[] excelBytes;
        try (Workbook workbook = new XSSFWorkbook(); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            Sheet sheet = workbook.createSheet("학생 명단");
            var header = sheet.createRow(0);
            header.createCell(0).setCellValue("전화번호");
            header.createCell(1).setCellValue("이름");
            header.createCell(2).setCellValue("주소");
            header.createCell(3).setCellValue("학번");
            var student = sheet.createRow(1);
            student.createCell(0).setCellValue("010-1234-5678");
            student.createCell(1).setCellValue("엑셀학생");
            student.createCell(2).setCellValue("대구광역시");
            student.createCell(3).setCellValue("2305004");
            workbook.write(output);
            excelBytes = output.toByteArray();
        }
        when(memberRepository.findAllByLoginIdIn(org.mockito.ArgumentMatchers.anyCollection()))
                .thenReturn(List.of());

        MemberService.CsvImportResult result = memberService.createMembersBySpreadsheet(
                new ByteArrayInputStream(excelBytes), "students.xlsx", MemberRole.ADMIN);

        assertThat(result.createdCount()).isEqualTo(1);
        assertThat(result.errorCount()).isZero();
        verify(memberRepository).saveAll(org.mockito.ArgumentMatchers.argThat(members -> {
            Member saved = ((List<Member>) members).getFirst();
            return saved.getLoginId().equals("2305004") && saved.getName().equals("엑셀학생");
        }));
    }

    @Test
    void 역할이_변경되면_authVersion이_증가한다() {
        Member target = member(MemberRole.USER);
        target.setAuthVersion(7);
        when(memberRepository.findById(1L)).thenReturn(Optional.of(target));
        when(memberRepository.save(target)).thenReturn(target);

        memberService.updateMemberByAdmin(1L, null, MemberRole.ADMIN, MemberRole.ADMIN);

        assertThat(target.getRole()).isEqualTo(MemberRole.ADMIN);
        assertThat(target.getAuthVersion()).isEqualTo(8);
    }

    private Member member(MemberRole role) {
        return Member.builder()
                .loginId("2305001")
                .password("encoded-password")
                .name("관리대상")
                .role(role)
                .provider(AuthProvider.LOCAL)
                .authType(AuthType.PASSWORD)
                .isActivated(true)
                .build();
    }
}
