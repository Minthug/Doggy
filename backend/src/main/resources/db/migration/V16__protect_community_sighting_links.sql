UPDATE community_posts child
SET related_post_id = NULL
WHERE child.related_post_id IS NOT NULL
  AND (
    child.type <> 'FOUND'
    OR NOT EXISTS (
      SELECT 1
      FROM community_posts parent
      WHERE parent.id = child.related_post_id
        AND parent.type = 'LOST'
    )
  );

ALTER TABLE community_posts
    DROP CONSTRAINT IF EXISTS fk_community_posts_related_post;

ALTER TABLE community_posts
    ADD CONSTRAINT fk_community_posts_related_post
        FOREIGN KEY (related_post_id)
        REFERENCES community_posts(id)
        ON DELETE SET NULL;
