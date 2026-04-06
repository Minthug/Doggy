package com.doggy.backend.domain.user.dto;

public record UpdatePushSettingRequest(
        boolean walkReminderEnabled,
        int reminderIntervalHours,
        boolean weatherAlertEnabled,
        int weatherAlertHour,
        boolean birthdayAlertEnabled,
        boolean healthCheckupAlertEnabled
) {}
