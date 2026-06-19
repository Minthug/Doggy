package com.doggy.backend.domain.supply.dto;

import com.doggy.backend.domain.supply.entity.SupplyInventory;

import java.time.LocalDate;

public record SupplyItemResponse(
        String name,
        String emoji,
        int currentGrams,
        int totalGrams,
        int dailyGrams,
        double kcalPerKg,
        LocalDate lastUpdatedDate
) {
    public static SupplyItemResponse from(SupplyInventory item) {
        return new SupplyItemResponse(
                item.getName(),
                item.getEmoji(),
                item.getCurrentGrams(),
                item.getTotalGrams(),
                item.getDailyGrams(),
                item.getKcalPerKg(),
                item.getLastUpdatedDate()
        );
    }
}
