package com.doggy.backend.domain.household.service;

import com.doggy.backend.domain.household.dto.CreateHouseholdRequest;
import com.doggy.backend.domain.household.dto.HouseholdResponse;
import com.doggy.backend.domain.household.dto.JoinHouseholdRequest;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.config.QueryDslConfig;
import com.doggy.backend.global.exception.BusinessException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.TestPropertySource;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import({HouseholdService.class, QueryDslConfig.class})
@TestPropertySource(properties = "spring.jpa.hibernate.ddl-auto=validate")
@Transactional(propagation = Propagation.NOT_SUPPORTED)
@EnabledIfEnvironmentVariable(named = "DOGGY_MARKING_TEST_DB_URL",
        matches = "jdbc:postgresql://(localhost|127\\.0\\.0\\.1):[0-9]+/doggy_marking_feedback_test")
class HouseholdTransferDatabaseTest {
    @Autowired HouseholdService service;
    @Autowired UserRepository users;

    @DynamicPropertySource
    static void database(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> System.getenv("DOGGY_MARKING_TEST_DB_URL"));
        registry.add("spring.datasource.username", () -> "doggy");
        registry.add("spring.datasource.password", () -> "doggy");
    }

    private record Family(Long owner, Long member, String inviteCode) {}

    private Family family() {
        Long owner = users.save(User.builder().nickname("transfer-owner").build()).getId();
        Long member = users.save(User.builder().nickname("transfer-member").build()).getId();
        var household = service.create(owner, new CreateHouseholdRequest("transfer-test"));
        service.join(member, new JoinHouseholdRequest(household.inviteCode()));
        return new Family(owner, member, household.inviteCode());
    }

    @Test
    void transfersRoleAndAllowsPreviousOwnerToLeave() {
        var family = family();
        var response = service.transferOwner(family.owner(), family.member());
        assertOwner(response, family.member());
        assertThatThrownBy(() -> service.refreshInviteCode(family.owner())).isInstanceOf(BusinessException.class);
        assertThat(service.refreshInviteCode(family.member())).isNotEqualTo(family.inviteCode());
        service.leave(family.owner());
        var remaining = service.getMyHousehold(family.member());
        assertThat(remaining.members()).hasSize(1);
        assertOwner(remaining, family.member());
        assertThatThrownBy(() -> service.getMyHousehold(family.owner())).isInstanceOf(BusinessException.class);
    }

    @Test
    void rejectsNonOwnerSelfAndUnrelatedRecipientWithoutChangingRoles() {
        var family = family();
        var otherFamily = family();
        assertThatThrownBy(() -> service.transferOwner(family.member(), family.owner()))
                .hasMessageContaining("관리자만");
        assertThatThrownBy(() -> service.transferOwner(family.owner(), family.owner()))
                .hasMessageContaining("다른 가족 구성원");
        assertThatThrownBy(() -> service.transferOwner(family.owner(), otherFamily.member()))
                .hasMessageContaining("같은 가족");
        assertThatThrownBy(() -> service.transferOwner(otherFamily.owner(), family.member()))
                .hasMessageContaining("같은 가족");
        assertOwner(service.getMyHousehold(family.owner()), family.owner());
    }

    @Test
    void concurrentTransfersHaveExactlyOneWinnerAndOneOwner() throws Exception {
        var family = family();
        Long third = users.save(User.builder().nickname("transfer-third").build()).getId();
        service.join(third, new JoinHouseholdRequest(family.inviteCode()));
        var outcomes = concurrently(
                () -> service.transferOwner(family.owner(), family.member()),
                () -> service.transferOwner(family.owner(), third));
        assertThat(outcomes).containsExactlyInAnyOrder(true, false);
        var response = service.getMyHousehold(family.owner());
        assertThat(response.members().stream().filter(m -> m.role().equals("OWNER"))).hasSize(1);
        assertThat(response.members().stream().filter(m -> m.role().equals("OWNER")).findFirst().orElseThrow().userId())
                .isIn(family.member(), third);
    }

    @Test
    void recipientLeavingDuringTransferCannotLeaveFamilyWithoutAnOwner() throws Exception {
        var family = family();
        var outcomes = concurrently(
                () -> service.transferOwner(family.owner(), family.member()),
                () -> service.leave(family.member()));
        assertThat(outcomes).containsExactlyInAnyOrder(true, false);
        var response = service.getMyHousehold(family.owner());
        assertThat(response.members().stream().filter(m -> m.role().equals("OWNER"))).hasSize(1);
    }

    private void assertOwner(HouseholdResponse response, Long userId) {
        assertThat(response.members().stream().filter(m -> m.role().equals("OWNER")))
                .extracting(HouseholdResponse.MemberInfo::userId).containsExactly(userId);
    }

    private List<Boolean> concurrently(Runnable first, Runnable second) throws Exception {
        var ready = new CountDownLatch(2);
        var start = new CountDownLatch(1);
        var executor = Executors.newFixedThreadPool(2);
        try {
            var a = executor.submit(atStart(first, ready, start));
            var b = executor.submit(atStart(second, ready, start));
            assertThat(ready.await(5, TimeUnit.SECONDS)).isTrue();
            start.countDown();
            return List.of(a.get(10, TimeUnit.SECONDS), b.get(10, TimeUnit.SECONDS));
        } finally {
            start.countDown();
            executor.shutdownNow();
        }
    }

    private Callable<Boolean> atStart(Runnable action, CountDownLatch ready, CountDownLatch start) {
        return () -> {
            ready.countDown();
            if (!start.await(5, TimeUnit.SECONDS)) throw new IllegalStateException("start timed out");
            try {
                action.run();
                return true;
            } catch (BusinessException exception) {
                return false;
            }
        };
    }
}
