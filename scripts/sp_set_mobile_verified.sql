-- Creates / replaces the stored procedure used by the first-login
-- mobile OTP verification flow to mark a user's mobile as verified.
--
-- Run via mysql client:
--   mysql -u <user> -p <database> < scripts/sp_set_mobile_verified.sql

USE legal_pdf;

DROP PROCEDURE IF EXISTS sp_set_mobile_verified;

DELIMITER $$
CREATE PROCEDURE sp_set_mobile_verified(
    IN p_user_id  INT,
    IN p_verified TINYINT(1)
)
BEGIN
    UPDATE users
    SET    mobile_verified = p_verified,
           updated_at      = NOW()
    WHERE  id = p_user_id;
END$$
DELIMITER ;
