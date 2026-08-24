package com.ync.ysync.config;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void missingResourceReturnsNotFound() {
        NoResourceFoundException exception = mock(NoResourceFoundException.class);
        when(exception.getResourcePath()).thenReturn("/uploads/.env");

        ResponseEntity<Map<String, String>> response = handler.handleNoResourceFoundException(exception);

        assertEquals(HttpStatus.NOT_FOUND, response.getStatusCode());
        assertEquals("요청한 리소스를 찾을 수 없습니다.", response.getBody().get("message"));
    }

    @Test
    void internalErrorDoesNotExposeExceptionDetails() {
        ResponseEntity<Map<String, String>> response =
                handler.handleAllException(new RuntimeException("sensitive-internal-value"));

        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.getStatusCode());
        assertFalse(response.getBody().containsKey("details"));
        assertFalse(response.getBody().containsValue("sensitive-internal-value"));
    }
}
