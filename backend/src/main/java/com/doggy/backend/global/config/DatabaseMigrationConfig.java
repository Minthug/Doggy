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
        createWalkSessionDogsTable();
    }

    private void createWalkSessionDogsTable() {
        try {
            Boolean exists = jdbcTemplate.queryForObject(
                    "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'walk_session_dogs')",
                    Boolean.class
            );
            if (Boolean.TRUE.equals(exists)) {
                log.debug("[Migration] walk_session_dogs 테이블 이미 존재, 스킵");
                return;
            }
            jdbcTemplate.execute("""
                    CREATE TABLE walk_session_dogs (
                        session_id BIGINT NOT NULL REFERENCES walk_sessions(id) ON DELETE CASCADE,
                        dog_id     BIGINT NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
                        PRIMARY KEY (session_id, dog_id)
                    )
                    """);
            log.info("[Migration] walk_session_dogs 테이블 생성 완료");
        } catch (Exception e) {
            log.warn("[Migration] walk_session_dogs 테이블 생성 실패: {}", e.getMessage());
        }
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
