package com.doggy.backend.domain.user.repository;

import com.doggy.backend.domain.user.entity.PushSetting;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PushSettingRepository extends JpaRepository<PushSetting, Long> {

    Optional<PushSetting> findByUserId(Long userId);

    List<PushSetting> findByHealthCheckupAlertEnabledTrue();
}
