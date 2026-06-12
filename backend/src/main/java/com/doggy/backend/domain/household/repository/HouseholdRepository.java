package com.doggy.backend.domain.household.repository;

import com.doggy.backend.domain.household.entity.Household;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface HouseholdRepository extends JpaRepository<Household, Long> {

    Optional<Household> findByInviteCode(String inviteCode);

    @Query("SELECT h FROM Household h JOIN h.members m WHERE m.user.id = :userId")
    Optional<Household> findByUserId(@Param("userId") Long userId);
}
