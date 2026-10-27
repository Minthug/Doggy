CREATE TABLE community_post_images (
    post_id BIGINT NOT NULL,
    display_order INTEGER NOT NULL,
    image_url TEXT NOT NULL,
    PRIMARY KEY (post_id, display_order),
    CONSTRAINT fk_community_post_images_post
        FOREIGN KEY (post_id)
        REFERENCES community_posts(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_community_post_images_post_id
    ON community_post_images(post_id);
