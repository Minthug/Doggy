package com.doggy.backend.domain.walk.entity;

import java.io.Serializable;
import java.util.Objects;

public class WalkRouteTagId implements Serializable {

    private Long session;
    private String tag;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof WalkRouteTagId that)) return false;
        return Objects.equals(session, that.session) && Objects.equals(tag, that.tag);
    }

    @Override
    public int hashCode() {
        return Objects.hash(session, tag);
    }
}
