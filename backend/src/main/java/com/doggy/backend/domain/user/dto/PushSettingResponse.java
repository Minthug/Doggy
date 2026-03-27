package com.doggy.backend.domain.user.dto;

import com.doggy.backend.domain.user.entity.PushSetting;

public record PushSettingResponse(
        boolean walkReminderEnabled,
        int reminderIntervalHours,
        boolean weatherAlertEnabled
) {
    public static PushSettingResponse from(PushSetting setting) {
        return new PushSettingResponse(
                setting.isWalkReminderEnabled(),
                setting.getReminderIntervalHours(),
                setting.isWeatherAlertEnabled()
        );
    }
}
