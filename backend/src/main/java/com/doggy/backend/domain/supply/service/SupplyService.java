package com.doggy.backend.domain.supply.service;

import com.doggy.backend.domain.household.entity.Household;
import com.doggy.backend.domain.household.repository.HouseholdRepository;
import com.doggy.backend.domain.supply.dto.SupplyItemResponse;
import com.doggy.backend.domain.supply.dto.UpdateSupplyRequest;
import com.doggy.backend.domain.supply.entity.SupplyInventory;
import com.doggy.backend.domain.supply.repository.SupplyInventoryRepository;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.domain.user.repository.UserRepository;
import com.doggy.backend.global.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class SupplyService {

    private static final List<String[]> DEFAULT_ITEMS = List.of(
            new String[]{"사료", "🍖"},
            new String[]{"간식", "🦴"}
    );

    private final SupplyInventoryRepository supplyRepository;
    private final HouseholdRepository householdRepository;
    private final UserRepository userRepository;

    @Transactional
    public List<SupplyItemResponse> getInventory(Long userId) {
        Household household = householdRepository.findByUserId(userId).orElse(null);

        if (household != null) {
            return getOrInitHousehold(household);
        } else {
            return getOrInitUser(userId);
        }
    }

    @Transactional
    public SupplyItemResponse update(Long userId, String name, UpdateSupplyRequest request) {
        Household household = householdRepository.findByUserId(userId).orElse(null);

        SupplyInventory item;
        if (household != null) {
            item = supplyRepository.findByHouseholdIdAndName(household.getId(), name)
                    .orElseThrow(() -> BusinessException.notFound("재고 항목을 찾을 수 없습니다"));
        } else {
            item = supplyRepository.findByUserIdAndHouseholdIdIsNullAndName(userId, name)
                    .orElseThrow(() -> BusinessException.notFound("재고 항목을 찾을 수 없습니다"));
        }

        item.update(request.currentGrams(), request.totalGrams(), request.dailyGrams(), request.kcalPerKg());
        return SupplyItemResponse.from(item);
    }

    private List<SupplyItemResponse> getOrInitHousehold(Household household) {
        List<SupplyInventory> items = supplyRepository.findByHouseholdId(household.getId());
        if (items.isEmpty()) {
            items = DEFAULT_ITEMS.stream()
                    .map(d -> supplyRepository.save(SupplyInventory.forHousehold(household, d[0], d[1])))
                    .toList();
        }
        return items.stream().map(SupplyItemResponse::from).toList();
    }

    private List<SupplyItemResponse> getOrInitUser(Long userId) {
        List<SupplyInventory> items = supplyRepository.findByUserIdAndHouseholdIdIsNull(userId);
        if (items.isEmpty()) {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> BusinessException.notFound("유저를 찾을 수 없습니다"));
            items = DEFAULT_ITEMS.stream()
                    .map(d -> supplyRepository.save(SupplyInventory.forUser(user, d[0], d[1])))
                    .toList();
        }
        return items.stream().map(SupplyItemResponse::from).toList();
    }
}
