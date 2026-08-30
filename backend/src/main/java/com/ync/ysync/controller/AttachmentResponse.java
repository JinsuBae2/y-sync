package com.ync.ysync.controller;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class AttachmentResponse {
    private String url;
    private String originalFilename;
    private String contentType;
    private Long size;
    private boolean image;
}
