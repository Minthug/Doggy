UPDATE users SET fcm_token = NULL WHERE BTRIM(fcm_token) = '';

UPDATE users
SET fcm_token = NULL
WHERE fcm_token IN (
    SELECT fcm_token FROM users
    WHERE fcm_token IS NOT NULL
    GROUP BY fcm_token HAVING COUNT(*) > 1
);

CREATE UNIQUE INDEX ux_users_fcm_token ON users (fcm_token) WHERE fcm_token IS NOT NULL;
