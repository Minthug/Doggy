package com.doggy.backend.domain.household.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
public class HouseholdIdCache {

    private Long id;

    public HouseholdIdCache(Long id) {
        this.id = id;
    }
}
