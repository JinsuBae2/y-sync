package com.ync.ysync.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ync.ysync.domain.CommentDeletedBy;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class BooleanJsonContractTest {

    private final ObjectMapper objectMapper = new ObjectMapper().findAndRegisterModules();

    @Test
    void serializesPinnedAndDeletedFieldsWithIsPrefix() {
        assertBooleanContract(
                objectMapper.valueToTree(NoticeResponse.builder().isPinned(true).build()),
                "isPinned",
                "pinned"
        );

        CommunityController.CommunityResponse community =
                CommunityController.CommunityResponse.builder()
                        .isPinned(true)
                        .isDeleted(true)
                        .build();
        JsonNode communityJson = objectMapper.valueToTree(community);
        assertBooleanContract(communityJson, "isPinned", "pinned");
        assertBooleanContract(communityJson, "isDeleted", "deleted");

        CommentResponse comment = CommentResponse.builder().isDeleted(true).build();
        assertBooleanContract(objectMapper.valueToTree(comment), "isDeleted", "deleted");

        AdminController.AdminReportSummaryResponse report =
                AdminController.AdminReportSummaryResponse.builder()
                        .isAuthorSuspended(true)
                        .isDeleted(true)
                        .build();
        JsonNode reportJson = objectMapper.valueToTree(report);
        assertBooleanContract(reportJson, "isAuthorSuspended", "authorSuspended");
        assertBooleanContract(reportJson, "isDeleted", "deleted");

        MemberProfileController.MyCommentResponse myComment =
                new MemberProfileController.MyCommentResponse(
                        1L, "내용", "게시글", "NOTICE", 2L, "2026-08-25T12:00:00", true, "사유",
                        CommentDeletedBy.ADMIN
                );
        JsonNode myCommentJson = objectMapper.valueToTree(myComment);
        assertBooleanContract(myCommentJson, "isDeleted", "deleted");
        assertEquals("ADMIN", myCommentJson.get("deletedBy").asText());
    }

    @Test
    void deserializesPinnedRequestsFromCurrentAndLegacyKeys() throws Exception {
        NoticeController.NoticeRequest currentNoticeRequest = objectMapper.readValue(
                "{\"isPinned\":true}",
                NoticeController.NoticeRequest.class
        );
        NoticeController.NoticeRequest legacyNoticeRequest = objectMapper.readValue(
                "{\"pinned\":true}",
                NoticeController.NoticeRequest.class
        );
        assertTrue(currentNoticeRequest.isPinned());
        assertTrue(legacyNoticeRequest.isPinned());

        CommunityController.CommunityRequest currentCommunityRequest = objectMapper.readValue(
                "{\"isPinned\":true}",
                CommunityController.CommunityRequest.class
        );
        CommunityController.CommunityRequest legacyCommunityRequest = objectMapper.readValue(
                "{\"pinned\":true}",
                CommunityController.CommunityRequest.class
        );
        assertTrue(currentCommunityRequest.isPinned());
        assertTrue(legacyCommunityRequest.isPinned());
    }

    private void assertBooleanContract(JsonNode json, String currentKey, String legacyKey) {
        assertTrue(json.get(currentKey).booleanValue());
        assertFalse(json.has(legacyKey));
    }
}
