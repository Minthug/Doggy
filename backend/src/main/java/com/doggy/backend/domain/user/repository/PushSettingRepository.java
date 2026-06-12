package com.doggy.backend.domain.user.repository;

import com.doggy.backend.domain.user.entity.PushSetting;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PushSettingRepository extends JpaRepository<PushSetting, Long> {

    Optional<PushSetting> findByUserId(Long userId);

    @Query("SELECT s FROM PushSetting s JOIN FETCH s.user")
    List<PushSetting> findAllWithUser();

    @Query("SELECT s FROM PushSetting s JOIN FETCH s.user WHERE s.healthCheckupAlertEnabled = true")
    List<PushSetting> findByHealthCheckupAlertEnabledTrue();

    @Query("SELECT s FROM PushSetting s JOIN FETCH s.user WHERE s.weatherAlertEnabled = true AND s.weatherAlertHour = :hour")
    List<PushSetting> findWeatherAlertTargets(@Param("hour") int hour);

    @Query("SELECT s FROM PushSetting s JOIN FETCH s.user WHERE s.walkReminderEnabled = true")
    List<PushSetting> findWalkReminderTargets();
}
