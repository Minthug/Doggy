package com.doggy.backend.global.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class DatabaseMigrationConfig implements ApplicationRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(ApplicationArguments args) {
        alterDogProfileImageToText();
    }

    /**
     * dogs.profile_image 컬럼을 VARCHAR(500) → TEXT로 변경
     * 이미 TEXT인 경우 character_maximum_length가 null이므로 안전하게 스킵
     */
    private void alterDogProfileImageToText() {
        try {
            Integer maxLength = jdbcTemplate.queryForObject(
                    """
                    SELECT character_maximum_length
                    FROM information_schema.columns
                    WHERE table_name = 'dogs' AND column_name = 'profile_image'
                    """,
                    Integer.class
            );

            if (maxLength != null) {
                jdbcTemplate.execute("ALTER TABLE dogs ALTER COLUMN profile_image TYPE TEXT");
                log.info("[Migration] dogs.profile_image VARCHAR({}) → TEXT 변경 완료", maxLength);
            } else {
                log.debug("[Migration] dogs.profile_image 이미 TEXT, 스킵");
            }
        } catch (Exception e) {
            log.warn("[Migration] dogs.profile_image 타입 변경 실패: {}", e.getMessage());
        }
    }
}
