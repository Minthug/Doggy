CREATE TABLE weather_rain_observations (
    nx INTEGER NOT NULL,
    ny INTEGER NOT NULL,
    observed_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    PRIMARY KEY (nx, ny)
);
