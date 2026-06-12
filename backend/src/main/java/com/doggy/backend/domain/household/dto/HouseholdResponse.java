package com.doggy.backend.domain.household.dto;

import com.doggy.backend.domain.household.entity.Household;
import com.doggy.backend.domain.household.entity.HouseholdMember;

import java.util.List;

public record HouseholdResponse(
        Long id,
        String name,
        String inviteCode,
        List<MemberInfo> members
) {
    public record MemberInfo(
            Long userId,
            String nickname,
            String profileImage,
            String role
    ) {
        public static MemberInfo from(HouseholdMember m) {
            return new MemberInfo(
                    m.getUser().getId(),
                    m.getUser().getNickname(),
                    m.getUser().getProfileImage(),
                    m.getRole().name()
            );
        }
    }

    public static HouseholdResponse from(Household h) {
        return new HouseholdResponse(
                h.getId(),
                h.getName(),
                h.getInviteCode(),
                h.getMembers().stream().map(MemberInfo::from).toList()
        );
    }
}
