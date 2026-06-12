package com.doggy.backend.domain.household.repository;

import com.doggy.backend.domain.household.entity.HouseholdMember;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface HouseholdMemberRepository extends JpaRepository<HouseholdMember, Long> {

    boolean existsByHouseholdIdAndUserId(Long householdId, Long userId);

    Optional<HouseholdMember> findByHouseholdIdAndUserId(Long householdId, Long userId);

    void deleteByHouseholdIdAndUserId(Long householdId, Long userId);
}
