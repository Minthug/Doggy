package com.doggy.backend.domain.walk.repository;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.core.io.ClassPathResource;
import org.springframework.data.jpa.repository.Query;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.DataSourceUtils;
import org.springframework.jdbc.datasource.init.ScriptUtils;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class WalkSessionRepositoryPrivacyTest {

    @Test
    @EnabledIfEnvironmentVariable(named = "DOGGY_TEST_DB_URL", matches = ".+")
    void nearbyPublicRoutesUseOnlyVisibleRoundedRoutePoint() throws NoSuchMethodException {
        var dataSource = new DriverManagerDataSource(
                System.getenv("DOGGY_TEST_DB_URL"),
                System.getenv().getOrDefault("DOGGY_TEST_DB_USER", "doggy"),
                System.getenv().getOrDefault("DOGGY_TEST_DB_PASSWORD", "doggy"));
        var jdbc = new JdbcTemplate(dataSource);
        var named = new NamedParameterJdbcTemplate(dataSource);
        var transaction = new TransactionTemplate(new DataSourceTransactionManager(dataSource));
        String sql = WalkSessionRepository.class
                .getMethod("findPublicRoutesNearby", double.class, double.class, double.class, int.class, int.class)
                .getAnnotation(Query.class).value();

        transaction.executeWithoutResult(status -> {
            jdbc.execute("CREATE TEMP TABLE walk_sessions (id bigint PRIMARY KEY, is_public boolean, status text, started_at timestamp, route_geo_json text) ON COMMIT DROP");
            jdbc.execute("CREATE TEMP TABLE walk_points (id bigint PRIMARY KEY, session_id bigint, recorded_at timestamp, lat double precision, lng double precision) ON COMMIT DROP");
            jdbc.execute("CREATE TEMP TABLE walk_route_likes (session_id bigint) ON COMMIT DROP");
            jdbc.execute("INSERT INTO walk_sessions VALUES "
                    + "(1, true, 'COMPLETED', now(), '{\"type\":\"LineString\",\"coordinates\":[[0,0],[0.001,0],[0.002,0],[0.003,0],[0.004,0],[0.005,0],[0.006,0]]}'), "
                    + "(2, true, 'COMPLETED', now(), '{\"type\":\"LineString\",\"coordinates\":[[0,0],[0.001,0],[0.002,0],[0.003,0]]}'), "
                    + "(3, true, 'COMPLETED', now(), NULL)");
            jdbc.execute("INSERT INTO walk_points SELECT step + 1, 1, now() + step * interval '1 second', 0, step * 0.001 FROM generate_series(0, 6) step");
            jdbc.execute("INSERT INTO walk_points SELECT step + 101, 2, now() + step * interval '1 second', 0, step * 0.001 FROM generate_series(0, 3) step");
            jdbc.execute("INSERT INTO walk_points SELECT step + 201, 3, now() + step * interval '1 second', 1 + (step % 2) * 0.001, step * 0.001 FROM generate_series(0, 6) step");

            ScriptUtils.executeSqlScript(DataSourceUtils.getConnection(dataSource),
                    new ClassPathResource("db/migration/V25__add_public_route_search_point.sql"));
            assertThat(jdbc.queryForObject("SELECT public_search_lng FROM walk_sessions WHERE id = 1", Double.class))
                    .isEqualTo(0.002);
            assertThat(jdbc.queryForObject("SELECT public_search_lng FROM walk_sessions WHERE id = 2", Double.class))
                    .isNull();
            assertThat(jdbc.queryForObject("SELECT public_search_lng FROM walk_sessions WHERE id = 3", Double.class))
                    .isNotNull();

            assertThat(findIds(named, sql, 0.0)).isEmpty();
            assertThat(findIds(named, sql, 0.002)).containsExactly(1L);
            assertThat(findIds(named, sql, 0.006)).isEmpty();
        });
    }

    private java.util.List<Long> findIds(NamedParameterJdbcTemplate jdbc, String sql, double lng) {
        return jdbc.query(sql,
                Map.of("lat", 0.0, "lng", lng, "radiusMeters", 50.0, "size", 20, "offset", 0),
                (rs, row) -> rs.getLong("id"));
    }
}
