-- ============================================================
-- Admin login via mobile OTP  (MySQL)
--
-- Creates admin_login_otps table and supporting stored procedures.
-- Only users with role admin / super Admin may use this flow.
--
-- Run: mysql -u root -p Legal_PDF < scripts/add_admin_login_otp.sql
-- ============================================================

-- ─────────────────────────────────────────────
-- 1. Table
-- ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS admin_login_otps (
    id          INT UNSIGNED    NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id     INT UNSIGNED    NOT NULL,
    otp_hash    VARCHAR(64)     NOT NULL,
    expires_at  DATETIME        NOT NULL,
    is_used     TINYINT(1)      NOT NULL DEFAULT 0,
    created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_alo_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────
-- 2. sp_create_admin_login_otp
--    Invalidates any existing pending OTP for
--    the user before inserting the new one.
-- ─────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_create_admin_login_otp;
DELIMITER ;;
CREATE PROCEDURE sp_create_admin_login_otp(
    IN p_user_id    INT UNSIGNED,
    IN p_otp_hash   VARCHAR(64),
    IN p_expires_at DATETIME
)
BEGIN
    UPDATE admin_login_otps
    SET    is_used = 1
    WHERE  user_id = p_user_id AND is_used = 0;

    INSERT INTO admin_login_otps (user_id, otp_hash, expires_at)
    VALUES (p_user_id, p_otp_hash, p_expires_at);

    SELECT 'ok' AS result;
END ;;
DELIMITER ;

-- ─────────────────────────────────────────────
-- 3. sp_get_valid_admin_login_otp
-- ─────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_get_valid_admin_login_otp;
DELIMITER ;;
CREATE PROCEDURE sp_get_valid_admin_login_otp(
    IN p_user_id INT UNSIGNED
)
BEGIN
    SELECT id, otp_hash, expires_at
    FROM   admin_login_otps
    WHERE  user_id   = p_user_id
      AND  is_used   = 0
      AND  expires_at > UTC_TIMESTAMP()
    ORDER  BY created_at DESC
    LIMIT  1;
END ;;
DELIMITER ;

-- ─────────────────────────────────────────────
-- 4. sp_mark_admin_login_otp_used
-- ─────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_mark_admin_login_otp_used;
DELIMITER ;;
CREATE PROCEDURE sp_mark_admin_login_otp_used(
    IN p_otp_id INT UNSIGNED
)
BEGIN
    UPDATE admin_login_otps
    SET    is_used = 1
    WHERE  id = p_otp_id;

    SELECT 'ok' AS result;
END ;;
DELIMITER ;

-- ─────────────────────────────────────────────
-- Verification
-- ─────────────────────────────────────────────
SELECT 'admin_login_otps table and stored procedures created successfully.' AS status;
