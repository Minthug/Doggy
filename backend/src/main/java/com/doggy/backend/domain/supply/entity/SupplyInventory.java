package com.doggy.backend.domain.supply.entity;

import com.doggy.backend.domain.household.entity.Household;
import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = "supply_inventory")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SupplyInventory extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "household_id")
    private Household household;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(nullable = false, length = 50)
    private String name;

    @Column(nullable = false, length = 10)
    private String emoji;

    @Column(nullable = false)
    private int currentGrams;

    @Column(nullable = false)
    private int totalGrams;

    @Column(nullable = false)
    private int dailyGrams;

    @Column(nullable = false)
    private double kcalPerKg;

    private LocalDate lastUpdatedDate;

    public static SupplyInventory forHousehold(Household household, String name, String emoji) {
        SupplyInventory item = new SupplyInventory();
        item.household = household;
        item.name = name;
        item.emoji = emoji;
        return item;
    }

    public static SupplyInventory forUser(User user, String name, String emoji) {
        SupplyInventory item = new SupplyInventory();
        item.user = user;
        item.name = name;
        item.emoji = emoji;
        return item;
    }

    public void update(int currentGrams, int totalGrams, int dailyGrams, double kcalPerKg) {
        this.currentGrams = Math.max(0, Math.min(currentGrams, totalGrams));
        this.totalGrams = totalGrams;
        this.dailyGrams = dailyGrams;
        this.kcalPerKg = kcalPerKg;
        this.lastUpdatedDate = LocalDate.now();
    }
}
