ALTER TABLE community_posts
    DROP CONSTRAINT IF EXISTS community_posts_type_check;

ALTER TABLE community_posts
    ADD CONSTRAINT community_posts_type_check
        CHECK (type IN ('LOST', 'FOUND', 'ADOPTION', 'FOOD_REVIEW', 'SUPPLY_REVIEW'));
