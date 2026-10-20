package com.doggy.backend.domain.household.dto;

import java.time.LocalDateTime;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
public class HouseholdIdCache {

    private Long id;
    private LocalDateTime joinedAt;

    public HouseholdIdCache(Long id) {
        this.id = id;
    }

    public HouseholdIdCache(Long id, LocalDateTime joinedAt) {
        this.id = id;
        this.joinedAt = joinedAt;
    }
}
