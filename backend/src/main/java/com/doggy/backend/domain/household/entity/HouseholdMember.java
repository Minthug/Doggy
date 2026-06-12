package com.doggy.backend.domain.household.entity;

import com.doggy.backend.domain.user.entity.User;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(
    name = "household_members",
    uniqueConstraints = @UniqueConstraint(columnNames = {"household_id", "user_id"})
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class HouseholdMember {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "household_id", nullable = false)
    private Household household;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Role role;

    @Column(nullable = false, updatable = false)
    private LocalDateTime joinedAt;

    @Builder
    public HouseholdMember(Household household, User user, Role role) {
        this.household = household;
        this.user = user;
        this.role = role;
        this.joinedAt = LocalDateTime.now();
    }

    public enum Role {
        OWNER, MEMBER
    }
}
