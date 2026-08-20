ALTER TABLE community_posts
    ADD COLUMN IF NOT EXISTS product_name VARCHAR(100),
    ADD COLUMN IF NOT EXISTS rating_percent INTEGER,
    ADD COLUMN IF NOT EXISTS review_summary VARCHAR(120),
    ADD COLUMN IF NOT EXISTS pros VARCHAR(300),
    ADD COLUMN IF NOT EXISTS cons VARCHAR(300);

ALTER TABLE community_posts
    ADD CONSTRAINT chk_community_posts_rating_percent
        CHECK (rating_percent IS NULL OR (rating_percent >= 0 AND rating_percent <= 100));
