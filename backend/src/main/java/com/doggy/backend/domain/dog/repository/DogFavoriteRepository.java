package com.doggy.backend.domain.dog.repository;

import com.doggy.backend.domain.dog.entity.DogFavorite;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Set;

public interface DogFavoriteRepository extends JpaRepository<DogFavorite, Long> {

    boolean existsByUserIdAndDogId(Long userId, Long dogId);

    void deleteByUserIdAndDogId(Long userId, Long dogId);

    @Query("SELECT f.dog.id FROM DogFavorite f WHERE f.user.id = :userId")
    Set<Long> findFavoritedDogIdsByUserId(@Param("userId") Long userId);

    // WalkPingService용: 특정 유저들이 즐겨찾기한 강아지 중 내 강아지가 있는지 배치 조회
    @Query("SELECT f FROM DogFavorite f JOIN FETCH f.dog WHERE f.user.id IN :userIds AND f.dog.id IN :dogIds")
    List<DogFavorite> findByUserIdInAndDogIdIn(
            @Param("userIds") Collection<Long> userIds,
            @Param("dogIds") Collection<Long> dogIds
    );
}
