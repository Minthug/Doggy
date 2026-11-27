package com.doggy.backend.domain.household.repository;

import com.doggy.backend.domain.household.entity.Household;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;

import java.util.Optional;

public interface HouseholdRepository extends JpaRepository<Household, Long> {

    Optional<Household> findByInviteCode(String inviteCode);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT h FROM Household h WHERE h.inviteCode = :inviteCode")
    Optional<Household> findByInviteCodeForUpdate(@Param("inviteCode") String inviteCode);

    @Query("SELECT h FROM Household h JOIN h.members m WHERE m.user.id = :userId")
    Optional<Household> findByUserId(@Param("userId") Long userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT h FROM Household h WHERE h.id = :id")
    Optional<Household> findByIdForUpdate(@Param("id") Long id);
}
