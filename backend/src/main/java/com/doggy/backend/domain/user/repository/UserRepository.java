package com.doggy.backend.domain.user.repository;

import com.doggy.backend.domain.user.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserRepository extends JpaRepository<User, Long> {

    @Modifying
    @Query("UPDATE User u SET u.fcmToken = null WHERE u.fcmToken = :token AND u.id <> :userId")
    int clearFcmTokenFromOtherUsers(@Param("token") String token, @Param("userId") Long userId);

    @Modifying
    @Query("UPDATE User u SET u.fcmToken = null WHERE u.id = :userId AND u.fcmToken = :token")
    int clearFcmTokenIfOwned(@Param("userId") Long userId, @Param("token") String token);
}
