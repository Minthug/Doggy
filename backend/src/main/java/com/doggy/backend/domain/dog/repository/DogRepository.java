package com.doggy.backend.domain.dog.repository;

import com.doggy.backend.domain.dog.entity.Dog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface DogRepository extends JpaRepository<Dog, Long> {

    List<Dog> findAllByUserId(Long userId);

    @Query("SELECT d FROM Dog d WHERE d.user.id IN :userIds")
    List<Dog> findAllByUserIdIn(@Param("userIds") Collection<Long> userIds);

    Optional<Dog> findByIdAndUserId(Long id, Long userId);

    List<Dog> findAllByHouseholdId(Long householdId);

    @Query("SELECT d FROM Dog d WHERE d.user.id = :userId OR d.household.id = :householdId")
    List<Dog> findAllAccessibleDogs(@Param("userId") Long userId, @Param("householdId") Long householdId);

    @Query(value = "SELECT * FROM dogs WHERE birth_date IS NOT NULL AND EXTRACT(MONTH FROM birth_date) = :month AND EXTRACT(DAY FROM birth_date) = :day", nativeQuery = true)
    List<Dog> findByBirthMonthAndDay(@Param("month") int month, @Param("day") int day);
}
