package com.doggy.backend.domain.community.repository;

import com.doggy.backend.domain.community.entity.CommunityPost;
import com.doggy.backend.domain.community.entity.CommunityPost.PostType;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface CommunityPostRepository extends JpaRepository<CommunityPost, Long> {

    @Query("SELECT p FROM CommunityPost p JOIN FETCH p.user ORDER BY p.createdAt DESC")
    List<CommunityPost> findAllWithUser(Pageable pageable);

    @Query("SELECT p FROM CommunityPost p JOIN FETCH p.user WHERE p.type = :type ORDER BY p.createdAt DESC")
    List<CommunityPost> findByTypeWithUser(@Param("type") PostType type, Pageable pageable);

    // 특정 실종 게시글에 연결된 목격 제보 목록
    @Query("SELECT p FROM CommunityPost p JOIN FETCH p.user WHERE p.relatedPostId = :postId ORDER BY p.createdAt DESC")
    List<CommunityPost> findSightingsByRelatedPostId(@Param("postId") Long postId);
}
