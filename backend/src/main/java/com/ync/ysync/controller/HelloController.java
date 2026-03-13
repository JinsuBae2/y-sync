package com.ync.ysync.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    @GetMapping("/api/v1/hello")
    public String hello() {
        return "Y-Sync 서버가 정상적으로 응답합니다!";
    }
}
