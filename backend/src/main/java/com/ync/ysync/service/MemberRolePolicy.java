package com.ync.ysync.service;

import com.ync.ysync.domain.MemberRole;

/**
 * 💡 권한 부여 규칙입니다. 관리자 단건 등록과 명단 일괄 등록이 같은 규칙을 따라야 해서 분리했습니다.
 *
 * 한 쪽에만 규칙을 두면 다른 경로로 우회할 수 있습니다. 실제로 명단 업로드는 권한 열을 받으므로
 * 여기서 막지 않으면 CSV 한 줄로 SUPER_ADMIN을 만들 수 있습니다.
 */
final class MemberRolePolicy {

    private MemberRolePolicy() {
    }

    static void validateAssignment(MemberRole actorRole, MemberRole requestedRole) {
        if (requestedRole == MemberRole.SUPER_ADMIN && actorRole != MemberRole.SUPER_ADMIN) {
            throw new IllegalArgumentException("SUPER_ADMIN 권한은 SUPER_ADMIN만 부여할 수 있습니다.");
        }
    }
}
