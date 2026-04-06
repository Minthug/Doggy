package com.doggy.backend.domain.user.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "push_settings")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PushSetting {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(nullable = false)
    private boolean walkReminderEnabled = true;

    @Column(nullable = false)
    private int reminderIntervalHours = 8;

    @Column(nullable = false)
    private boolean weatherAlertEnabled = true;

    @Column(nullable = false)
    private int weatherAlertHour = 7; // 날씨 알림 수신 시각 (0~23)

    @Column(nullable = false)
    private boolean birthdayAlertEnabled = true;

    @Column(nullable = false)
    private boolean healthCheckupAlertEnabled = true;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    @PreUpdate
    private void setUpdatedAt() {
        this.updatedAt = LocalDateTime.now();
    }

    @Builder
    public PushSetting(User user) {
        this.user = user;
    }

    public void update(boolean walkReminderEnabled, int reminderIntervalHours,
                       boolean weatherAlertEnabled, int weatherAlertHour,
                       boolean birthdayAlertEnabled, boolean healthCheckupAlertEnabled) {
        this.walkReminderEnabled = walkReminderEnabled;
        this.reminderIntervalHours = reminderIntervalHours;
        this.weatherAlertEnabled = weatherAlertEnabled;
        this.weatherAlertHour = Math.max(0, Math.min(23, weatherAlertHour));
        this.birthdayAlertEnabled = birthdayAlertEnabled;
        this.healthCheckupAlertEnabled = healthCheckupAlertEnabled;
    }
}
