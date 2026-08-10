package com.doggy.backend.global.exception;

import com.doggy.backend.global.alert.AlertService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.Map;
import java.util.stream.Collectors;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    private final Environment environment;
    private final AlertService alertService;

    public GlobalExceptionHandler(Environment environment, AlertService alertService) {
        this.environment = environment;
        this.alertService = alertService;
    }

    // 비즈니스 예외
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<Map<String, String>> handleBusinessException(BusinessException e,
                                                                        HttpServletRequest request) {
        if (e.getStatus().is5xxServerError()) {
            log.warn("business_exception status={} message={}", e.getStatus().value(), e.getMessage());
            alertService.recordServerError(request.getRequestURI(), e, requestId());
        }
        return ResponseEntity.status(e.getStatus())
                .body(Map.of("message", e.getMessage()));
    }

    // @Valid 검증 실패
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> handleValidationException(MethodArgumentNotValidException e) {
        Map<String, String> errors = e.getBindingResult().getFieldErrors().stream()
                .collect(Collectors.toMap(
                        FieldError::getField,
                        field -> field.getDefaultMessage() != null ? field.getDefaultMessage() : "유효하지 않은 값입니다",
                        (existing, duplicate) -> existing
                ));
        return ResponseEntity.badRequest().body(errors);
    }

    // 필수 헤더 누락 (Refresh-Token 등)
    @ExceptionHandler(MissingRequestHeaderException.class)
    public ResponseEntity<Map<String, String>> handleMissingHeader(MissingRequestHeaderException e) {
        return ResponseEntity.badRequest()
                .body(Map.of("message", "필수 헤더가 누락되었습니다: " + e.getHeaderName()));
    }

    // 필수 쿼리 파라미터 누락
    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<Map<String, String>> handleMissingParam(MissingServletRequestParameterException e) {
        return ResponseEntity.badRequest()
                .body(Map.of("message", "필수 파라미터가 누락되었습니다: " + e.getParameterName()));
    }

    // 경로 변수 타입 불일치 (예: /dogs/abc)
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<Map<String, String>> handleTypeMismatch(MethodArgumentTypeMismatchException e) {
        return ResponseEntity.badRequest()
                .body(Map.of("message", "잘못된 요청 값입니다: " + e.getName()));
    }

    // 인증 없이 보호된 API 접근
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<Map<String, String>> handleAccessDenied(AccessDeniedException e) {
        log.warn("access_denied message={}", e.getMessage());
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(Map.of("message", "접근 권한이 없습니다"));
    }

    // 존재하지 않는 API 경로 (404)
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<Map<String, String>> handleNoResource(NoResourceFoundException e) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(Map.of("message", "요청한 경로를 찾을 수 없습니다"));
    }

    // 그 외 예상치 못한 예외
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleException(Exception e, HttpServletRequest request) {
        log.error("Unhandled exception: {}", e.getMessage(), e);
        alertService.recordServerError(request.getRequestURI(), e, requestId());
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(errorBody("서버 오류가 발생했습니다"));
    }

    private Map<String, String> errorBody(String message) {
        String requestId = requestId();
        if (requestId != null && !requestId.isBlank() && includeRequestIdInErrorResponse()) {
            return Map.of("message", message, "requestId", requestId);
        }
        return Map.of("message", message);
    }

    private String requestId() {
        return org.slf4j.MDC.get("requestId");
    }

    private boolean includeRequestIdInErrorResponse() {
        return environment.getProperty("app.error.include-request-id", Boolean.class, true);
    }
}
