package com.doggy.backend.domain.supply.repository;

import com.doggy.backend.domain.supply.entity.SupplyInventory;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SupplyInventoryRepository extends JpaRepository<SupplyInventory, Long> {

    List<SupplyInventory> findByHouseholdId(Long householdId);

    List<SupplyInventory> findByUserIdAndHouseholdIdIsNull(Long userId);

    Optional<SupplyInventory> findByHouseholdIdAndName(Long householdId, String name);

    Optional<SupplyInventory> findByUserIdAndHouseholdIdIsNullAndName(Long userId, String name);
}
