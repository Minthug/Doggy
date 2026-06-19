package com.doggy.backend.domain.household.service;

import com.doggy.backend.domain.dog.repository.DogRepository;
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
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class HouseholdServiceTest {

    @Mock HouseholdRepository householdRepository;
    @Mock HouseholdMemberRepository householdMemberRepository;
    @Mock UserRepository userRepository;
    @Mock DogRepository dogRepository;

    @InjectMocks HouseholdService householdService;

    private User makeUser(Long id) {
        User user = User.builder().nickname("user" + id).build();
        ReflectionTestUtils.setField(user, "id", id);
        return user;
    }

    private Household makeHousehold(Long id, String name) {
        Household h = Household.builder().name(name).build();
        ReflectionTestUtils.setField(h, "id", id);
        return h;
    }

    @Nested
    @DisplayName("create")
    class Create {

        @Test
        @DisplayName("이미 가구에 속한 유저는 생성 불가")
        void fail_alreadyInHousehold() {
            given(householdRepository.findByUserId(1L)).willReturn(Optional.of(makeHousehold(10L, "기존가구")));

            assertThatThrownBy(() -> householdService.create(1L, new CreateHouseholdRequest("새가구")))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("이미 가구에 속해 있습니다");
        }

        @Test
        @DisplayName("정상 생성 시 OWNER 멤버 추가 및 강아지 연결")
        void success_createHousehold() {
            User user = makeUser(1L);
            given(householdRepository.findByUserId(1L)).willReturn(Optional.empty());
            given(userRepository.findById(1L)).willReturn(Optional.of(user));
            given(householdRepository.save(any())).willAnswer(inv -> inv.getArgument(0));
            given(householdMemberRepository.save(any())).willAnswer(inv -> inv.getArgument(0));
            given(dogRepository.findAllByUserId(1L)).willReturn(List.of());

            HouseholdResponse response = householdService.create(1L, new CreateHouseholdRequest("우리집"));

            assertThat(response.name()).isEqualTo("우리집");
            verify(householdMemberRepository).save(argThat(m -> m.getRole() == Role.OWNER));
        }
    }

    @Nested
    @DisplayName("join")
    class Join {

        @Test
        @DisplayName("이미 가구에 속한 유저는 참가 불가")
        void fail_alreadyInHousehold() {
            given(householdRepository.findByUserId(2L)).willReturn(Optional.of(makeHousehold(10L, "기존가구")));

            assertThatThrownBy(() -> householdService.join(2L, new JoinHouseholdRequest("ABCD1234")))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("이미 가구에 속해 있습니다");
        }

        @Test
        @DisplayName("유효하지 않은 초대 코드로 참가 불가")
        void fail_invalidInviteCode() {
            given(householdRepository.findByUserId(2L)).willReturn(Optional.empty());
            given(householdRepository.findByInviteCode("INVALID1")).willReturn(Optional.empty());

            assertThatThrownBy(() -> householdService.join(2L, new JoinHouseholdRequest("INVALID1")))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("유효하지 않은 초대 코드입니다");
        }

        @Test
        @DisplayName("정상 참가 시 MEMBER 역할로 추가")
        void success_joinHousehold() {
            User user = makeUser(2L);
            Household household = makeHousehold(10L, "우리집");
            given(householdRepository.findByUserId(2L)).willReturn(Optional.empty());
            given(householdRepository.findByInviteCode(household.getInviteCode())).willReturn(Optional.of(household));
            given(userRepository.findById(2L)).willReturn(Optional.of(user));
            given(householdMemberRepository.save(any())).willAnswer(inv -> inv.getArgument(0));
            given(dogRepository.findAllByUserId(2L)).willReturn(List.of());

            householdService.join(2L, new JoinHouseholdRequest(household.getInviteCode()));

            verify(householdMemberRepository).save(argThat(m -> m.getRole() == Role.MEMBER));
        }
    }

    @Nested
    @DisplayName("refreshInviteCode")
    class RefreshInviteCode {

        @Test
        @DisplayName("MEMBER는 초대 코드 재발급 불가")
        void fail_memberCannotRefresh() {
            User user = makeUser(1L);
            Household household = makeHousehold(10L, "우리집");
            HouseholdMember member = HouseholdMember.builder()
                    .household(household).user(user).role(Role.MEMBER).build();

            given(householdRepository.findByUserId(1L)).willReturn(Optional.of(household));
            given(householdMemberRepository.findByHouseholdIdAndUserId(10L, 1L)).willReturn(Optional.of(member));

            assertThatThrownBy(() -> householdService.refreshInviteCode(1L))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("오너만 초대 코드를 재발급할 수 있습니다");
        }

        @Test
        @DisplayName("OWNER는 초대 코드 재발급 성공")
        void success_ownerRefresh() {
            User user = makeUser(1L);
            Household household = makeHousehold(10L, "우리집");
            String oldCode = household.getInviteCode();
            HouseholdMember owner = HouseholdMember.builder()
                    .household(household).user(user).role(Role.OWNER).build();

            given(householdRepository.findByUserId(1L)).willReturn(Optional.of(household));
            given(householdMemberRepository.findByHouseholdIdAndUserId(10L, 1L)).willReturn(Optional.of(owner));

            String newCode = householdService.refreshInviteCode(1L);

            assertThat(newCode).isNotEqualTo(oldCode);
        }
    }

    @Nested
    @DisplayName("leave")
    class Leave {

        @Test
        @DisplayName("다른 멤버가 있을 때 OWNER는 탈퇴 불가")
        void fail_ownerCannotLeaveWithMembers() {
            User owner = makeUser(1L);
            User member = makeUser(2L);
            Household household = makeHousehold(10L, "우리집");

            HouseholdMember ownerMember = HouseholdMember.builder()
                    .household(household).user(owner).role(Role.OWNER).build();
            HouseholdMember normalMember = HouseholdMember.builder()
                    .household(household).user(member).role(Role.MEMBER).build();
            household.getMembers().addAll(List.of(ownerMember, normalMember));

            given(householdRepository.findByUserId(1L)).willReturn(Optional.of(household));
            given(householdMemberRepository.findByHouseholdIdAndUserId(10L, 1L)).willReturn(Optional.of(ownerMember));

            assertThatThrownBy(() -> householdService.leave(1L))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("오너는 탈퇴할 수 없습니다");
        }

        @Test
        @DisplayName("마지막 멤버 탈퇴 시 가구 삭제")
        void success_lastMemberLeaveDeletesHousehold() {
            User user = makeUser(1L);
            Household household = makeHousehold(10L, "우리집");
            HouseholdMember ownerMember = HouseholdMember.builder()
                    .household(household).user(user).role(Role.OWNER).build();
            household.getMembers().add(ownerMember);

            given(householdRepository.findByUserId(1L)).willReturn(Optional.of(household));
            given(householdMemberRepository.findByHouseholdIdAndUserId(10L, 1L)).willReturn(Optional.of(ownerMember));
            given(dogRepository.findAllByUserId(1L)).willReturn(List.of());
            given(householdMemberRepository.countByHouseholdId(10L)).willReturn(0L);

            householdService.leave(1L);

            verify(householdRepository).delete(household);
        }

        @Test
        @DisplayName("MEMBER 탈퇴 후 가구 존재하면 삭제 안 함")
        void success_memberLeaveKeepsHousehold() {
            User user = makeUser(2L);
            Household household = makeHousehold(10L, "우리집");
            HouseholdMember normalMember = HouseholdMember.builder()
                    .household(household).user(user).role(Role.MEMBER).build();
            household.getMembers().add(normalMember);

            given(householdRepository.findByUserId(2L)).willReturn(Optional.of(household));
            given(householdMemberRepository.findByHouseholdIdAndUserId(10L, 2L)).willReturn(Optional.of(normalMember));
            given(dogRepository.findAllByUserId(2L)).willReturn(List.of());
            given(householdMemberRepository.countByHouseholdId(10L)).willReturn(1L);

            householdService.leave(2L);

            verify(householdRepository, never()).delete(any());
        }
    }
}
