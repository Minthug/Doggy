-- 1. community_posts 중복 인덱스 제거
--    idx_community_posts_created 와 idx_community_posts_created_at 이 동일한 (created_at DESC) 인덱스
DROP INDEX IF EXISTS idx_community_posts_created;

-- 2. community_posts 불필요한 단일 인덱스 제거
--    idx_community_posts_type_created_at(type, created_at DESC) 복합 인덱스가 이미 커버
DROP INDEX IF EXISTS idx_community_posts_type;

-- 3. dogs.household_id 인덱스 추가
--    DogRepository: WHERE d.user.id = :userId OR d.household.id = :householdId
--    user_id 는 이미 인덱스 있음; household_id 는 없어서 OR 조건에서 풀스캔 발생
CREATE INDEX IF NOT EXISTS idx_dogs_household_id ON dogs (household_id);
