package com.doggy.backend.domain.household.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

// non-final class: Jackson DefaultTyping.NON_FINAL에서 타입 정보(@class)가 포함되어
// Redis 역직렬화 시 Long/Integer 타입 불일치 없이 안전하게 처리됨
@Getter
@Setter
@NoArgsConstructor
public class HouseholdIdCache {

    private Long id;

    public HouseholdIdCache(Long id) {
        this.id = id;
    }
}
