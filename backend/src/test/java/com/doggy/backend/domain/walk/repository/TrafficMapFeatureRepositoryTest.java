package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.repository.TrafficMapFeatureRepository.TrafficContext;
import com.doggy.backend.domain.walk.repository.TrafficMapFeatureRepository.TrafficCoordinate;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class TrafficMapFeatureRepositoryTest {

    @Test
    @EnabledIfEnvironmentVariable(named = "DOGGY_TEST_DB_URL", matches = ".+")
    void readsTrafficContextFromPostgis() {
        var dataSource = new DriverManagerDataSource(
                System.getenv("DOGGY_TEST_DB_URL"),
                System.getenv().getOrDefault("DOGGY_TEST_DB_USER", "doggy"),
                System.getenv().getOrDefault("DOGGY_TEST_DB_PASSWORD", "doggy"));
        var jdbc = new JdbcTemplate(dataSource);
        var transaction = new TransactionTemplate(new DataSourceTransactionManager(dataSource));

        transaction.executeWithoutResult(status -> {
            jdbc.execute("CREATE TEMP TABLE traffic_map_features (feature_type text, geom geometry(Geometry, 4326)) ON COMMIT DROP");
            jdbc.execute("INSERT INTO traffic_map_features (feature_type, geom) VALUES "
                    + "('TRAFFIC_SIGNAL', ST_SetSRID(ST_MakePoint(126.944, 37.218), 4326)), "
                    + "('CROSSWALK', ST_SetSRID(ST_MakePoint(126.944, 37.218), 4326)), "
                    + "('INTERSECTION', ST_SetSRID(ST_MakePoint(126.944, 37.218), 4326)), "
                    + "('ROAD', ST_SetSRID(ST_MakePoint(126.944, 37.218), 4326)), "
                    + "('FOOTWAY', ST_SetSRID(ST_MakePoint(126.944, 37.218), 4326))");

            var contexts = new TrafficMapFeatureRepository(jdbc).findContexts(List.of(
                    new TrafficCoordinate(37.218, 126.944),
                    new TrafficCoordinate(37.220, 126.944)));

            assertThat(contexts).containsExactly(
                    new TrafficContext(true, true, true, true, true),
                    TrafficContext.neutral());
        });
    }
}
