package com.doggy.backend.global.common;

import com.doggy.backend.global.exception.BusinessException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RequestLimitsTest {

    @Test
    void clampPageAndSize() {
        assertThat(RequestLimits.clampPage(-10)).isZero();
        assertThat(RequestLimits.clampPage(2)).isEqualTo(2);
        assertThat(RequestLimits.clampPage(Integer.MAX_VALUE)).isEqualTo(RequestLimits.MAX_PAGE);
        assertThat(RequestLimits.clampPageSize(-10)).isEqualTo(1);
        assertThat(RequestLimits.clampPageSize(20)).isEqualTo(20);
        assertThat(RequestLimits.clampPageSize(10_000)).isEqualTo(RequestLimits.MAX_PAGE_SIZE);
    }

    @Test
    void clampRadius() {
        assertThat(RequestLimits.clampRadiusMeters(null)).isEqualTo(RequestLimits.DEFAULT_RADIUS_METERS);
        assertThat(RequestLimits.clampRadiusMeters(10.0)).isEqualTo(RequestLimits.MIN_RADIUS_METERS);
        assertThat(RequestLimits.clampRadiusMeters(2_000.0)).isEqualTo(2_000.0);
        assertThat(RequestLimits.clampRadiusMeters(999_999.0)).isEqualTo(RequestLimits.MAX_RADIUS_METERS);
    }

    @Test
    void rejectInvalidRadius() {
        assertThatThrownBy(() -> RequestLimits.clampRadiusMeters(Double.NaN))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("반경");
    }

    @Test
    void validateLatLng() {
        RequestLimits.validateLatLng(37.5, 127.0);

        assertThatThrownBy(() -> RequestLimits.validateLatLng(91.0, 127.0))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("좌표");
        assertThatThrownBy(() -> RequestLimits.validateLatLng(37.5, Double.POSITIVE_INFINITY))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("좌표");
    }
}
