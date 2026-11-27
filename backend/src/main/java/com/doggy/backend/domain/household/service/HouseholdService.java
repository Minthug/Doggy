package com.doggy.backend.domain.household.service;

import com.doggy.backend.domain.dog.repository.DogRepository;
import com.doggy.backend.domain.household.dto.CreateHouseholdRequest;
import com.doggy.backend.domain.household.dto.HouseholdIdCache;
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
    private final DogRepository dogRepository;

    @Transactional(readOnly = true)
    public HouseholdIdCache findHouseholdIdByUserId(Long userId) {
        return householdRepository.findByUserId(userId)
                .map(household -> householdMemberRepository
                        .findByHouseholdIdAndUserId(household.getId(), userId)
                        .map(member -> new HouseholdIdCache(household.getId(), member.getJoinedAt()))
                        .orElseGet(() -> new HouseholdIdCache(null, null)))
                .orElseGet(() -> new HouseholdIdCache(null, null));
    }


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
        household.getMembers().add(owner);

        // 오너의 기존 강아지들을 가구에 연결
        dogRepository.findAllByUserId(userId).forEach(dog -> dog.assignHousehold(household));

        return HouseholdResponse.from(household);
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

        Household household = householdRepository.findByInviteCodeForUpdate(request.inviteCode().toUpperCase())
                .orElseThrow(() -> BusinessException.notFound("유효하지 않은 초대 코드입니다"));

        User user = userRepository.findById(userId)
                .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));

        HouseholdMember member = HouseholdMember.builder()
                .household(household)
                .user(user)
                .role(Role.MEMBER)
                .build();
        householdMemberRepository.save(member);
        household.getMembers().add(member);

        // 기존에 가지고 있던 강아지들을 가구에 연결
        dogRepository.findAllByUserId(userId).forEach(dog -> dog.assignHousehold(household));

        return HouseholdResponse.from(household);
    }

    @Transactional
    public String refreshInviteCode(Long userId) {
        Household household = findHouseholdForUpdate(userId);

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
    public HouseholdResponse transferOwner(Long userId, Long targetUserId) {
        Household household = findHouseholdForUpdate(userId);
        HouseholdMember owner = householdMemberRepository
                .findByHouseholdIdAndUserId(household.getId(), userId)
                .orElseThrow(() -> BusinessException.forbidden("가족 관리자만 위임할 수 있습니다"));
        if (owner.getRole() != Role.OWNER) {
            throw BusinessException.forbidden("가족 관리자만 위임할 수 있습니다");
        }
        if (userId.equals(targetUserId)) {
            throw BusinessException.badRequest("다른 가족 구성원을 선택해 주세요");
        }
        HouseholdMember target = householdMemberRepository
                .findByHouseholdIdAndUserId(household.getId(), targetUserId)
                .orElseThrow(() -> BusinessException.notFound("같은 가족의 구성원을 선택해 주세요"));
        if (target.getRole() != Role.MEMBER) {
            throw BusinessException.badRequest("일반 구성원에게만 위임할 수 있습니다");
        }
        owner.changeRole(Role.MEMBER);
        target.changeRole(Role.OWNER);
        return HouseholdResponse.from(household);
    }

    private Household findHouseholdForUpdate(Long userId) {
        Long householdId = householdRepository.findByUserId(userId)
                .orElseThrow(() -> BusinessException.notFound("가구를 찾을 수 없습니다")).getId();
        return lockHousehold(householdId);
    }

    private Household lockHousehold(Long householdId) {
        return householdRepository.findByIdForUpdate(householdId)
                .orElseThrow(() -> BusinessException.notFound("가구를 찾을 수 없습니다"));
    }

    @Transactional
    public void leave(Long userId) {
        Household household = findHouseholdForUpdate(userId);

        HouseholdMember member = householdMemberRepository
                .findByHouseholdIdAndUserId(household.getId(), userId)
                .orElseThrow(() -> BusinessException.notFound("가구 멤버를 찾을 수 없습니다"));

        if (member.getRole() == Role.OWNER && household.getMembers().size() > 1) {
            throw BusinessException.badRequest("다른 멤버가 있을 때 오너는 탈퇴할 수 없습니다. 가족 관리에서 관리자 권한을 위임해 주세요");
        }

        householdMemberRepository.deleteByHouseholdIdAndUserId(household.getId(), userId);

        // 탈퇴한 유저의 강아지에서 가구 연결 해제
        dogRepository.findAllByUserId(userId).forEach(dog -> dog.assignHousehold(null));

        // 멤버가 아무도 없으면 가구 삭제 (delete 후 DB 기준으로 카운트)
        long remaining = householdMemberRepository.countByHouseholdId(household.getId());
        if (remaining == 0) {
            householdRepository.delete(household);
        }
    }
}
