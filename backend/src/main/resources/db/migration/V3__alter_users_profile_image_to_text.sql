-- profile_image 컬럼을 TEXT로 변경 (base64 이미지 저장 지원)
ALTER TABLE users ALTER COLUMN profile_image TYPE TEXT;
