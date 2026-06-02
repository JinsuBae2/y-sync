package com.ync.ysync.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import jakarta.validation.ConstraintViolationException;
import org.springframework.dao.DataAccessException;

import java.util.HashMap;
import java.util.Map;

/**
 * 💡 애플리케이션 전역에서 발생하는 예외를 한곳에서 처리하여
 * 일관된 에러 응답을 반환하고 내부 정보 유출을 방지하는 전역 예외 처리기 클래스입니다.
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    // 💡 IllegalArgumentException & IllegalStateException 처리 (400 Bad Request)
    @ExceptionHandler({IllegalArgumentException.class, IllegalStateException.class})
    public ResponseEntity<Map<String, String>> handleBadRequestException(RuntimeException e) {
        log.warn("🚨 비즈니스 로직 예외 발생: {}", e.getMessage());
        Map<String, String> response = new HashMap<>();
        response.put("message", e.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    // 💡 DTO 유효성 검사 (@Valid) 예외 처리 (400 Bad Request)
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidationException(MethodArgumentNotValidException e) {
        log.warn("🚨 DTO 입력 검증 실패 발생");
        Map<String, Object> response = new HashMap<>();
        Map<String, String> errors = new HashMap<>();

        for (FieldError fieldError : e.getBindingResult().getFieldErrors()) {
            errors.put(fieldError.getField(), fieldError.getDefaultMessage());
        }

        response.put("message", "입력값 검증에 실패했습니다.");
        response.put("errors", errors);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    // 💡 JSON 파싱 및 데이터 바인딩 실패 예외 처리 (400 Bad Request)
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String, String>> handleHttpMessageNotReadableException(HttpMessageNotReadableException e) {
        log.warn("🚨 요청 JSON 바인딩 실패: {}", e.getMessage());
        Map<String, String> response = new HashMap<>();
        response.put("message", "요청 형식이 올바르지 않거나 파싱할 수 없는 값이 존재합니다. (날짜/Enum 등 데이터 형식을 확인해 주세요.)");
        response.put("details", e.getMostSpecificCause().getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    // 💡 컨트롤러 파라미터 타입 불일치 예외 처리 (400 Bad Request)
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<Map<String, String>> handleTypeMismatchException(MethodArgumentTypeMismatchException e) {
        log.warn("🚨 요청 파라미터 타입 불일치: {}", e.getMessage());
        Map<String, String> response = new HashMap<>();
        response.put("message", String.format("요청 파라미터 '%s'의 타입이 잘못되었습니다. (기대 타입: %s)", e.getName(), e.getRequiredType().getSimpleName()));
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    // 💡 제약조건 위반 예외 처리 (400 Bad Request)
    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<Map<String, String>> handleConstraintViolation(ConstraintViolationException e) {
        log.warn("🚨 데이터 제약 조건 위반: {}", e.getMessage());
        Map<String, String> response = new HashMap<>();
        response.put("message", "데이터 유효성 검증 실패: " + e.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    // 💡 데이터베이스 관련 예외 처리 (500 Internal Server Error)
    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, String>> handleDataAccessException(DataAccessException e) {
        log.error("🔥 데이터베이스 내부 오류 발생: ", e);
        Map<String, String> response = new HashMap<>();
        response.put("message", "데이터베이스 작업 중 오류가 발생했습니다. DB 스키마 또는 데이터를 확인해 주세요.");
        response.put("details", e.getMostSpecificCause().getMessage());
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
    }

    // 💡 권한 부족 예외 처리 (403 Forbidden)
    @ExceptionHandler(org.springframework.security.access.AccessDeniedException.class)
    public ResponseEntity<Map<String, String>> handleAccessDeniedException(org.springframework.security.access.AccessDeniedException e) {
        log.warn("🚨 권한 부족 예외 발생: {}", e.getMessage());
        Map<String, String> response = new HashMap<>();
        response.put("message", "해당 작업을 수행할 권한이 없습니다.");
        response.put("details", e.getMessage());
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(response);
    }

    // 💡 그 외 알 수 없는 모든 예외 처리 (500 Internal Server Error)
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleAllException(Exception e) {
        log.error("🔥 예상치 못한 시스템 내부 오류 발생: ", e);
        Map<String, String> response = new HashMap<>();
        response.put("message", "서버 내부 오류가 발생했습니다. 관리자에게 문의해 주세요.");
        response.put("details", e.getMessage());
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
    }
}


