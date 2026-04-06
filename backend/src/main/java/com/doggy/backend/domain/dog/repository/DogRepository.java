package com.doggy.backend.domain.dog.repository;

import com.doggy.backend.domain.dog.entity.Dog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface DogRepository extends JpaRepository<Dog, Long> {

    List<Dog> findAllByUserId(Long userId);

    Optional<Dog> findByIdAndUserId(Long id, Long userId);

    @Query("SELECT d FROM Dog d WHERE d.birthDate IS NOT NULL AND FUNCTION('MONTH', d.birthDate) = :month AND FUNCTION('DAY', d.birthDate) = :day")
    List<Dog> findByBirthMonthAndDay(@Param("month") int month, @Param("day") int day);
}
