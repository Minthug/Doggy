package com.doggy.backend.domain.walk.repository;

import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.List;

public interface WalkSessionRepositoryCustom {

    List<Long> findHistoryIdsByUserId(Long userId, Long householdId, Pageable pageable);

    List<Long> findUserIdsNotWalkedSince(LocalDateTime since);
}
