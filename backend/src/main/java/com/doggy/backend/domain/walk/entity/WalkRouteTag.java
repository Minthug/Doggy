package com.doggy.backend.domain.walk.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "walk_route_tags")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@IdClass(WalkRouteTagId.class)
public class WalkRouteTag {

    @Id
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "session_id", nullable = false)
    private WalkSession session;

    @Id
    @Column(length = 30, nullable = false)
    private String tag;

    @Builder
    public WalkRouteTag(WalkSession session, String tag) {
        this.session = session;
        this.tag = tag;
    }
}
