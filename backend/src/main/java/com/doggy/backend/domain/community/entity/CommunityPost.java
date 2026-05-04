package com.doggy.backend.domain.community.entity;

import com.doggy.backend.domain.user.entity.User;
import com.doggy.backend.global.common.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "community_posts")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CommunityPost extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PostType type;

    @Column(nullable = false, length = 100)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(length = 50)
    private String dogName;

    @Column(length = 100)
    private String breed;

    @Column(length = 200)
    private String lastSeenArea;

    private Double lat;
    private Double lng;

    @Column(length = 100)
    private String contactInfo;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PostStatus status = PostStatus.OPEN;

    @Builder
    public CommunityPost(User user, PostType type, String title, String content,
                         String dogName, String breed, String lastSeenArea,
                         Double lat, Double lng, String contactInfo) {
        this.user = user;
        this.type = type;
        this.title = title;
        this.content = content;
        this.dogName = dogName;
        this.breed = breed;
        this.lastSeenArea = lastSeenArea;
        this.lat = lat;
        this.lng = lng;
        this.contactInfo = contactInfo;
    }

    public void resolve() {
        this.status = PostStatus.RESOLVED;
    }

    public enum PostType {
        LOST, FOUND, GENERAL
    }

    public enum PostStatus {
        OPEN, RESOLVED
    }
}
