package com.ync.ysync.service;

import com.ync.ysync.domain.AuthProvider;
import com.ync.ysync.domain.AuthType;
import com.ync.ysync.domain.Member;
import com.ync.ysync.domain.MemberRole;
import com.ync.ysync.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.FormulaEvaluator;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * 💡 학생 명단(CSV·Excel)을 읽어 회원을 일괄 사전 등록합니다.
 *
 * `MemberService`에서 분리한 이유는 이 기능이 **파일 파싱**이라는 다른 종류의 일이기 때문입니다.
 * 헤더 별칭 인식, 따옴표 처리, Excel→CSV 변환처럼 회원 도메인과 무관한 코드가 200줄 넘게 있었고,
 * 가입·로그인 로직과 한 파일에 있으면 어느 쪽을 고치든 나머지를 함께 읽어야 했습니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MemberSpreadsheetImportService {

    private static final Set<String> CSV_LOGIN_ID_HEADERS = Set.of(
            "학번", "학생번호", "학생학번", "studentid", "loginid");
    private static final Set<String> CSV_NAME_HEADERS = Set.of(
            "이름", "성명", "학생명", "name", "studentname");
    private static final Set<String> CSV_ROLE_HEADERS = Set.of(
            "역할", "권한", "role");

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;

    public record CsvImportError(int row, String loginId, String message) {
    }

    public record CsvImportResult(int totalCount, int createdCount, int duplicateCount, List<CsvImportError> errors) {
        public int errorCount() {
            return errors.size();
        }
    }

    /**
     * CSV 또는 Excel 명단을 일괄 등록합니다.
     */
    @Transactional
    public CsvImportResult importMembers(InputStream stream, String filename, MemberRole actorRole) {
        String normalizedFilename = filename == null ? "" : filename.trim().toLowerCase();
        if (normalizedFilename.endsWith(".csv")) {
            return importFromCsv(stream, actorRole);
        }
        if (normalizedFilename.endsWith(".xlsx") || normalizedFilename.endsWith(".xls")) {
            return importFromCsv(excelToCsv(stream), actorRole);
        }
        throw new IllegalArgumentException("CSV 또는 Excel(.xlsx, .xls) 파일만 업로드할 수 있습니다.");
    }

    @Transactional
    public CsvImportResult importFromCsv(InputStream csvStream, MemberRole actorRole) {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(csvStream, StandardCharsets.UTF_8))) {
            String line;
            boolean isFirstLine = true;
            int rowNumber = 0;
            int totalCount = 0;
            int duplicateCount = 0;
            int loginIdColumn = 0;
            int nameColumn = 1;
            int roleColumn = 2;
            List<CsvMemberRow> validRows = new ArrayList<>();
            List<CsvImportError> errors = new ArrayList<>();
            Set<String> loginIdsInFile = new HashSet<>();

            while ((line = reader.readLine()) != null) {
                rowNumber++;
                if (line.trim().isEmpty())
                    continue;

                // UTF-8 BOM 제거
                if (isFirstLine && line.startsWith("﻿")) {
                    line = line.substring(1);
                }

                List<String> parts = parseCsvLine(line);

                // 헤더가 있으면 필요한 열만 이름으로 찾아 사용하고 나머지는 무시한다.
                if (isFirstLine && isCsvHeaderRow(parts)) {
                    loginIdColumn = findHeaderIndex(parts, CSV_LOGIN_ID_HEADERS);
                    nameColumn = findHeaderIndex(parts, CSV_NAME_HEADERS);
                    roleColumn = findHeaderIndex(parts, CSV_ROLE_HEADERS);
                    isFirstLine = false;
                    if (loginIdColumn < 0 || nameColumn < 0) {
                        throw new IllegalArgumentException("CSV 헤더에서 학번과 이름 열을 찾을 수 없습니다.");
                    }
                    continue;
                }
                isFirstLine = false;
                totalCount++;

                String loginId = csvValue(parts, loginIdColumn);
                String name = csvValue(parts, nameColumn);
                if (loginId.isEmpty() && name.isEmpty()) {
                    errors.add(new CsvImportError(rowNumber, "", "학번과 이름이 비어 있습니다."));
                    continue;
                }

                // 학번은 숫자만 포함되어야 함
                if (!loginId.matches("^\\d+$")) {
                    log.warn("CSV 파싱 - 올바르지 않은 학번 형식 건너뜀: {}", loginId);
                    errors.add(new CsvImportError(rowNumber, loginId, "학번은 숫자만 입력할 수 있습니다."));
                    continue;
                }
                if (name.isEmpty()) {
                    errors.add(new CsvImportError(rowNumber, loginId, "이름이 비어 있습니다."));
                    continue;
                }
                MemberRole role = MemberRole.USER;
                String roleValue = csvValue(parts, roleColumn);
                if (!roleValue.isEmpty()) {
                    try {
                        role = MemberRole.valueOf(roleValue.toUpperCase());
                    } catch (IllegalArgumentException e) {
                        errors.add(new CsvImportError(rowNumber, loginId, "알 수 없는 권한입니다: " + roleValue));
                        continue;
                    }
                }
                try {
                    MemberRolePolicy.validateAssignment(actorRole, role);
                } catch (IllegalArgumentException e) {
                    errors.add(new CsvImportError(rowNumber, loginId, e.getMessage()));
                    continue;
                }
                if (!loginIdsInFile.add(loginId)) {
                    duplicateCount++;
                    continue;
                }
                validRows.add(new CsvMemberRow(loginId, name, role));
            }

            Set<String> existingLoginIds = new HashSet<>();
            if (!validRows.isEmpty()) {
                memberRepository.findAllByLoginIdIn(validRows.stream().map(CsvMemberRow::loginId).toList())
                        .stream().map(Member::getLoginId).forEach(existingLoginIds::add);
            }

            List<Member> membersToSave = new ArrayList<>();
            for (CsvMemberRow row : validRows) {
                if (existingLoginIds.contains(row.loginId())) {
                    duplicateCount++;
                    continue;
                }
                membersToSave.add(Member.builder()
                        .loginId(row.loginId())
                        .password(passwordEncoder.encode("TEMP_" + row.loginId() + "_" + System.currentTimeMillis()))
                        .name(row.name())
                        .role(row.role())
                        .isActivated(false)
                        .provider(AuthProvider.LOCAL)
                        .authType(AuthType.PASSWORD)
                        .build());
            }
            memberRepository.saveAll(membersToSave);

            CsvImportResult result = new CsvImportResult(totalCount, membersToSave.size(), duplicateCount, errors);
            log.info("학생 명단 일괄 사전등록 완료 - 신규 {}명, 중복 {}명, 오류 {}건",
                    result.createdCount(), result.duplicateCount(), result.errorCount());
            return result;
        } catch (Exception e) {
            throw new RuntimeException("학생 명단 파일 파싱 및 등록 중 오류가 발생했습니다: " + e.getMessage(), e);
        }
    }

    private InputStream excelToCsv(InputStream stream) {
        try (Workbook workbook = WorkbookFactory.create(stream)) {
            if (workbook.getNumberOfSheets() == 0) {
                throw new IllegalArgumentException("Excel 파일에 시트가 없습니다.");
            }
            Sheet sheet = workbook.getSheetAt(0);
            DataFormatter formatter = new DataFormatter();
            FormulaEvaluator evaluator = workbook.getCreationHelper().createFormulaEvaluator();
            StringBuilder csv = new StringBuilder();
            for (Row row : sheet) {
                int lastCell = Math.max(row.getLastCellNum(), 0);
                for (int column = 0; column < lastCell; column++) {
                    if (column > 0) {
                        csv.append(',');
                    }
                    var cell = row.getCell(column);
                    String value = cell == null ? "" : formatter.formatCellValue(cell, evaluator)
                            .replace('\r', ' ').replace('\n', ' ');
                    csv.append(escapeCsvValue(value));
                }
                csv.append('\n');
            }
            return new ByteArrayInputStream(csv.toString().getBytes(StandardCharsets.UTF_8));
        } catch (IllegalArgumentException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalArgumentException("Excel 파일을 읽을 수 없습니다: " + e.getMessage(), e);
        }
    }

    private String escapeCsvValue(String value) {
        if (value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")) {
            return "\"" + value.replace("\"", "\"\"") + "\"";
        }
        return value;
    }

    private record CsvMemberRow(String loginId, String name, MemberRole role) {
    }

    private boolean isCsvHeaderRow(List<String> values) {
        return values.stream()
                .map(this::normalizeCsvHeader)
                .anyMatch(header -> CSV_LOGIN_ID_HEADERS.contains(header)
                        || CSV_NAME_HEADERS.contains(header)
                        || CSV_ROLE_HEADERS.contains(header));
    }

    private int findHeaderIndex(List<String> values, Set<String> aliases) {
        for (int index = 0; index < values.size(); index++) {
            if (aliases.contains(normalizeCsvHeader(values.get(index)))) {
                return index;
            }
        }
        return -1;
    }

    private String normalizeCsvHeader(String value) {
        return value.trim().toLowerCase().replaceAll(" ", "").replaceAll("_", "").replaceAll("-", "");
    }

    private String csvValue(List<String> values, int index) {
        return index >= 0 && index < values.size() ? values.get(index).trim() : "";
    }

    private List<String> parseCsvLine(String line) {
        List<String> values = new ArrayList<>();
        StringBuilder value = new StringBuilder();
        boolean quoted = false;
        for (int index = 0; index < line.length(); index++) {
            char current = line.charAt(index);
            if (current == '"') {
                if (quoted && index + 1 < line.length() && line.charAt(index + 1) == '"') {
                    value.append('"');
                    index++;
                } else {
                    quoted = !quoted;
                }
            } else if (current == ',' && !quoted) {
                values.add(value.toString());
                value.setLength(0);
            } else {
                value.append(current);
            }
        }
        values.add(value.toString());
        return values;
    }
}
