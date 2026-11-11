
CREATE DATABASE IF NOT EXISTS ekubertu_telegram
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE ekubertu_telegram;

CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    phone_number VARCHAR(32) NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    user_name VARCHAR(255) DEFAULT NULL,

    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) DEFAULT NULL,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY unique_phone (phone_number),
    UNIQUE KEY unique_telegram_user_id (user_id),
    UNIQUE KEY unique_telegram_username (user_name)
) ENGINE=InnoDB;

CREATE TABLE processed_updates (
    update_id BIGINT UNSIGNED PRIMARY KEY,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
