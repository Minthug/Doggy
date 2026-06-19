CREATE TABLE IF NOT EXISTS supply_inventory (
    id                BIGSERIAL PRIMARY KEY,
    household_id      BIGINT           REFERENCES households (id) ON DELETE CASCADE,
    user_id           BIGINT           REFERENCES users (id) ON DELETE CASCADE,
    name              VARCHAR(50)      NOT NULL,
    emoji             VARCHAR(10)      NOT NULL,
    current_grams     INT              NOT NULL DEFAULT 0,
    total_grams       INT              NOT NULL DEFAULT 0,
    daily_grams       INT              NOT NULL DEFAULT 0,
    kcal_per_kg       DOUBLE PRECISION NOT NULL DEFAULT 0,
    last_updated_date DATE,
    created_at        TIMESTAMPTZ      NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ      NOT NULL DEFAULT now(),
    UNIQUE (household_id, name),
    UNIQUE (user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_supply_household_id ON supply_inventory (household_id);
CREATE INDEX IF NOT EXISTS idx_supply_user_id ON supply_inventory (user_id);
