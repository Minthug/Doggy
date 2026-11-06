-- Existing eight-character invite codes remain guessable until rotated.
UPDATE households
SET invite_code = upper(substr(md5(gen_random_uuid()::text || gen_random_uuid()::text), 1, 20))
WHERE length(invite_code) < 20;
