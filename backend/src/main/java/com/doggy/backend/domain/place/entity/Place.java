package com.doggy.backend.domain.place.entity;

import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.locationtech.jts.geom.Point;

@Entity
@Table(name = "places")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Place extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 200)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 50)
    private Category category;

    @Column(length = 500)
    private String address;

    @Column(nullable = false)
    private double lat;

    @Column(nullable = false)
    private double lng;

    @Column(columnDefinition = "GEOMETRY(POINT, 4326)", nullable = false)
    private Point location;

    @Column(length = 20)
    private String phone;

    @Column(nullable = false)
    private boolean isOpen24h = false;

    @Column(nullable = false)
    private boolean isEmergency = false;

    @Column(nullable = false)
    private boolean allowsDogs = true;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Source source;

    @Column(nullable = false)
    private boolean isVerified = false;

    @Builder
    public Place(String name, Category category, String address, double lat, double lng,
                 Point location, String phone, boolean isOpen24h, boolean isEmergency,
                 boolean allowsDogs, Source source) {
        this.name = name;
        this.category = category;
        this.address = address;
        this.lat = lat;
        this.lng = lng;
        this.location = location;
        this.phone = phone;
        this.isOpen24h = isOpen24h;
        this.isEmergency = isEmergency;
        this.allowsDogs = allowsDogs;
        this.source = source;
    }

    public void verify() {
        this.isVerified = true;
    }

    public enum Category {
        HOSPITAL, PARK, CAFE, PET_SHOP, PET_HOTEL
    }

    public enum Source {
        PUBLIC_DATA, KAKAO, USER
    }
}
