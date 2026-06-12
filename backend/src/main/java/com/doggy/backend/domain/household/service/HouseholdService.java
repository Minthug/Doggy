package com.doggy.backend.domain.household.service;

import com.doggy.backend.domain.household.dto.CreateHouseholdRequest;
import com.doggy.backend.domain.household.dto.HouseholdResponse;
import com.doggy.backend.domain.household.dto.JoinHouseholdRequest;
import com.doggy.backend.domain.household.entity.Household;
import com.doggy.backend.domain.household.entity.HouseholdMember;
import com.doggy.backend.domain.household.entity.HouseholdMember.Role;
import com.doggy.backend.domain.household.repository.HouseholdMemberRepository;
import com.doggy.backend.domain.household.repository.HouseholdRepository;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class HouseholdService {

    private final HouseholdRepository householdRepository;
    private final HouseholdMemberRepository householdMemberRepository;
    private final UserRepository userRepository;

    @Transactional
    public HouseholdResponse create(Long userId, CreateHouseholdRequest request) {
        if (householdRepository.findByUserId(userId).isPresent()) {
            throw BusinessException.badRequest("이미 가구에 속해 있습니다");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));

        Household household = Household.builder()
                .name(request.name())
                .build();
        householdRepository.save(household);

        HouseholdMember owner = HouseholdMember.builder()
                .household(household)
                .user(user)
                .role(Role.OWNER)
                .build();
        householdMemberRepository.save(owner);

        return HouseholdResponse.from(householdRepository.findById(household.getId())
                .orElseThrow());
    }

    @Transactional(readOnly = true)
    public HouseholdResponse getMyHousehold(Long userId) {
        Household household = householdRepository.findByUserId(userId)
                .orElseThrow(() -> BusinessException.notFound("가구를 찾을 수 없습니다"));
        return HouseholdResponse.from(household);
    }

    @Transactional
    public HouseholdResponse join(Long userId, JoinHouseholdRequest request) {
        if (householdRepository.findByUserId(userId).isPresent()) {
            throw BusinessException.badRequest("이미 가구에 속해 있습니다");
        }

        Household household = householdRepository.findByInviteCode(request.inviteCode().toUpperCase())
                .orElseThrow(() -> BusinessException.notFound("유효하지 않은 초대 코드입니다"));

        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));

        HouseholdMember member = HouseholdMember.builder()
                .household(household)
                .user(user)
                .role(Role.MEMBER)
                .build();
        householdMemberRepository.save(member);

        return HouseholdResponse.from(householdRepository.findById(household.getId())
                .orElseThrow());
    }

    @Transactional
    public String refreshInviteCode(Long userId) {
        Household household = householdRepository.findByUserId(userId)
                .orElseThrow(() -> BusinessException.notFound("가구를 찾을 수 없습니다"));

        HouseholdMember member = householdMemberRepository
                .findByHouseholdIdAndUserId(household.getId(), userId)
                .orElseThrow(() -> BusinessException.unauthorized("권한이 없습니다"));

        if (member.getRole() != Role.OWNER) {
            throw BusinessException.unauthorized("오너만 초대 코드를 재발급할 수 있습니다");
        }

        household.refreshInviteCode();
        return household.getInviteCode();
    }

    @Transactional
    public void leave(Long userId) {
        Household household = householdRepository.findByUserId(userId)
                .orElseThrow(() -> BusinessException.notFound("가구를 찾을 수 없습니다"));

        HouseholdMember member = householdMemberRepository
                .findByHouseholdIdAndUserId(household.getId(), userId)
                .orElseThrow(() -> BusinessException.notFound("가구 멤버를 찾을 수 없습니다"));

        if (member.getRole() == Role.OWNER && household.getMembers().size() > 1) {
            throw BusinessException.badRequest("다른 멤버가 있을 때 오너는 탈퇴할 수 없습니다. 오너를 위임하거나 멤버를 먼저 내보내세요");
        }

        householdMemberRepository.deleteByHouseholdIdAndUserId(household.getId(), userId);

        // 멤버가 아무도 없으면 가구 삭제
        if (household.getMembers().size() <= 1) {
            householdRepository.delete(household);
        }
    }
}
